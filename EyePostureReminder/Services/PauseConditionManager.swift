import AVFoundation
import Combine
import CoreMotion
import Foundation
import Intents
import os

// MARK: - PauseConditionSource

/// Identifies the source of a pause condition.
enum PauseConditionSource: Hashable {
    case focusMode
    case carPlay
    case driving
}

// MARK: - Detector Protocols

protocol FocusStatusDetecting: AnyObject {
    var isFocused: Bool { get }
    var onFocusChanged: ((Bool) -> Void)? { get set }
    func startMonitoring()
    func stopMonitoring()
}

protocol CarPlayDetecting: AnyObject {
    var isCarPlayActive: Bool { get }
    var onCarPlayChanged: ((Bool) -> Void)? { get set }
    func startMonitoring()
    func stopMonitoring()
}

protocol DrivingActivityDetecting: AnyObject {
    var isDriving: Bool { get }
    var onDrivingChanged: ((Bool) -> Void)? { get set }
    func startMonitoring()
    func stopMonitoring()
}

protocol PauseConditionProviding: AnyObject {
    var isPaused: Bool { get }
    var onPauseStateChanged: ((Bool) -> Void)? { get set }
    func startMonitoring()
    func stopMonitoring()
}

// MARK: - LiveFocusStatusDetector

/// Observes `INFocusStatusCenter` for Focus mode changes.
/// Requires `NSFocusStatusUsageDescription` in Info.plist.
/// If authorization is denied, `isFocused` stays `false` (fail open — no pause).
final class LiveFocusStatusDetector: NSObject, FocusStatusDetecting {

    private(set) var isFocused: Bool = false
    var onFocusChanged: ((Bool) -> Void)?

    private var focusObservation: NSKeyValueObservation?

    func startMonitoring() {
        // Request authorization first. KVO is deferred until after auth completes
        // to avoid accessing focusStatus before the usage description is acknowledged —
        // an early access crashes the app even when Info.plist has the key.
        INFocusStatusCenter.default.requestAuthorization { [weak self] status in
            guard let self else { return }
            guard status == .authorized else { return }

            let focused = INFocusStatusCenter.default.focusStatus.isFocused ?? false
            DispatchQueue.main.async {
                self.isFocused = focused
                self.onFocusChanged?(focused)

                // KVO on `focusStatus` — fires whenever Focus mode activates or deactivates.
                self.focusObservation = INFocusStatusCenter.default.observe(
                    \.focusStatus,
                    options: [.new]
                ) { [weak self] _, _ in
                    guard let self else { return }
                    let focused = INFocusStatusCenter.default.focusStatus.isFocused ?? false
                    DispatchQueue.main.async {
                        self.isFocused = focused
                        self.onFocusChanged?(focused)
                    }
                }
            }
        }
    }

    func stopMonitoring() {
        focusObservation?.invalidate()
        focusObservation = nil
    }
}

// MARK: - LiveCarPlayDetector

/// Observes `AVAudioSession.routeChangeNotification` for CarPlay connection/disconnection.
/// No permission required.
final class LiveCarPlayDetector: CarPlayDetecting {

    private(set) var isCarPlayActive: Bool = false
    var onCarPlayChanged: ((Bool) -> Void)?

    private var observer: NSObjectProtocol?

    func startMonitoring() {
        isCarPlayActive = checkCarPlay()

        observer = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            let active = self.checkCarPlay()
            DispatchQueue.main.async {
                guard active != self.isCarPlayActive else { return }
                self.isCarPlayActive = active
                self.onCarPlayChanged?(active)
            }
        }
    }

    func stopMonitoring() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }

    private func checkCarPlay() -> Bool {
        // .carPlay port may not be exposed in all SDK configurations; match via raw value.
        let carPlayPort = AVAudioSession.Port(rawValue: "CarPlay")
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        for output in outputs where output.portType == carPlayPort { return true }
        return false
    }
}

// MARK: - LiveDrivingActivityDetector

/// Uses `CMMotionActivityManager` to detect automotive activity with high confidence.
/// Requires `NSMotionUsageDescription` in Info.plist.
/// Falls back to inactive state on simulator or when motion hardware is unavailable.
final class LiveDrivingActivityDetector: DrivingActivityDetecting {

    private(set) var isDriving: Bool = false
    var onDrivingChanged: ((Bool) -> Void)?

    private let manager = CMMotionActivityManager()

    func startMonitoring() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            Logger.scheduling.debug("LiveDrivingActivityDetector: motion activity unavailable — skipping (simulator?)")
            return
        }

        manager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity else { return }
            let driving = activity.automotive && activity.confidence == .high
            guard driving != self.isDriving else { return }
            self.isDriving = driving
            self.onDrivingChanged?(driving)
        }
    }

    func stopMonitoring() {
        manager.stopActivityUpdates()
    }
}

// MARK: - PauseConditionManager

/// Aggregates pause signals from Focus mode, CarPlay, and driving activity into a
/// single `isPaused` state. Fires `onPauseStateChanged` whenever the combined
/// state flips. Reads `SettingsStore` at callback time so per-condition user
/// toggles are always respected without requiring re-registration.
///
/// Each condition maps to a `SettingsStore` flag:
/// - `.focusMode` → `settings.pauseDuringFocus`
/// - `.carPlay`   → `settings.pauseWhileDriving` (CarPlay implies a driving context)
/// - `.driving`   → `settings.pauseWhileDriving`
final class PauseConditionManager: PauseConditionProviding {

    var onPauseStateChanged: ((Bool) -> Void)?

    private(set) var isPaused: Bool = false {
        didSet {
            guard isPaused != oldValue else { return }
            if isPaused {
                let conditionType = activeConditions.map { "\($0)" }.joined(separator: ",")
                AnalyticsLogger.log(.pauseActivated(conditionType: conditionType))
            } else {
                AnalyticsLogger.log(.pauseDeactivated(conditionType: "all_cleared"))
            }
            onPauseStateChanged?(isPaused)
        }
    }

    private let focusDetector: FocusStatusDetecting
    private let carPlayDetector: CarPlayDetecting
    private let drivingDetector: DrivingActivityDetecting
    private let settings: SettingsStore

    private var activeConditions: Set<PauseConditionSource> = []

    private var cancellables: Set<AnyCancellable> = []

    init(
        settings: SettingsStore,
        focusDetector: FocusStatusDetecting = LiveFocusStatusDetector(),
        carPlayDetector: CarPlayDetecting = LiveCarPlayDetector(),
        drivingDetector: DrivingActivityDetecting = LiveDrivingActivityDetector()
    ) {
        self.settings = settings
        self.focusDetector = focusDetector
        self.carPlayDetector = carPlayDetector
        self.drivingDetector = drivingDetector
    }

    func startMonitoring() {
        focusDetector.onFocusChanged = { [weak self] focused in
            guard let self else { return }
            self.update(.focusMode, isActive: focused && self.settings.pauseDuringFocus)
        }
        carPlayDetector.onCarPlayChanged = { [weak self] active in
            guard let self else { return }
            self.update(.carPlay, isActive: active && self.settings.pauseWhileDriving)
        }
        drivingDetector.onDrivingChanged = { [weak self] driving in
            guard let self else { return }
            self.update(.driving, isActive: driving && self.settings.pauseWhileDriving)
        }

        // Re-evaluate all conditions whenever a pause setting is toggled.
        // Note: @Published fires in willSet, so we use the value passed by the publisher
        // rather than re-reading from settings (which still holds the old value at that point).
        settings.$pauseDuringFocus
            .dropFirst()
            .sink { [weak self] newValue in
                guard let self else { return }
                self.update(.focusMode, isActive: self.focusDetector.isFocused && newValue)
            }
            .store(in: &cancellables)

        settings.$pauseWhileDriving
            .dropFirst()
            .sink { [weak self] newValue in
                guard let self else { return }
                self.update(.carPlay, isActive: self.carPlayDetector.isCarPlayActive && newValue)
                self.update(.driving, isActive: self.drivingDetector.isDriving && newValue)
            }
            .store(in: &cancellables)

        focusDetector.startMonitoring()
        carPlayDetector.startMonitoring()
        drivingDetector.startMonitoring()
        Logger.scheduling.info("PauseConditionManager: monitoring started")
    }

    func stopMonitoring() {
        cancellables.removeAll()
        focusDetector.stopMonitoring()
        carPlayDetector.stopMonitoring()
        drivingDetector.stopMonitoring()
        Logger.scheduling.debug("PauseConditionManager: monitoring stopped")
    }

    /// Re-evaluates all three conditions against current detector state and settings.
    /// Called when a pause-related setting changes so the paused state stays consistent.
    private func reevaluate() {
        update(.focusMode, isActive: focusDetector.isFocused && settings.pauseDuringFocus)
        update(.carPlay, isActive: carPlayDetector.isCarPlayActive && settings.pauseWhileDriving)
        update(.driving, isActive: drivingDetector.isDriving && settings.pauseWhileDriving)
    }

    private func update(_ source: PauseConditionSource, isActive: Bool) {
        if isActive { activeConditions.insert(source) } else { activeConditions.remove(source) }
        isPaused = !activeConditions.isEmpty
    }
}
