import ComposableArchitecture
import Foundation

/// TCA dependency client wrapping `ReminderScheduler` for reducer consumption.
///
/// Phase 0 of the TCA migration (#665). The `liveValue` adapter routes
/// scheduling calls through the existing `@MainActor` `ReminderScheduler`,
/// which itself reads the live `SettingsStore` snapshot. The `ReminderSettings`
/// argument carried by the closures is part of the normative Phase 1 contract
/// — Phase 1 will refactor `ReminderScheduler` to honour it directly.
@DependencyClient
struct ReminderSchedulerClient: Sendable {
    /// Schedules every enabled reminder type using the supplied baseline
    /// settings. The Phase 0 adapter delegates to the live `ReminderScheduler`,
    /// which reads the shared `SettingsStore`.
    var scheduleReminders: @Sendable (ReminderSettings) async -> Void

    /// Reschedules a single reminder type after settings have changed.
    var rescheduleReminder: @Sendable (ReminderType, ReminderSettings) async -> Void

    /// Cancels all pending reminders for the given type.
    var cancelReminder: @Sendable (ReminderType) async -> Void

    /// Cancels every pending reminder unconditionally.
    var cancelAllReminders: @Sendable () async -> Void
}

extension ReminderSchedulerClient: DependencyKey {
    static let liveValue: ReminderSchedulerClient = {
        Task { @MainActor in _ = LiveReminderSchedulerBridge.shared }
        return ReminderSchedulerClient(
            scheduleReminders: { _ in
                await LiveReminderSchedulerBridge.shared.scheduleAll()
            },
            rescheduleReminder: { type, _ in
                await LiveReminderSchedulerBridge.shared.reschedule(type)
            },
            cancelReminder: { type in
                await LiveReminderSchedulerBridge.shared.cancel(type)
            },
            cancelAllReminders: {
                await LiveReminderSchedulerBridge.shared.cancelAll()
            }
        )
    }()
}

extension DependencyValues {
    /// TCA accessor for the shared `ReminderSchedulerClient`.
    var reminderSchedulerClient: ReminderSchedulerClient {
        get { self[ReminderSchedulerClient.self] }
        set { self[ReminderSchedulerClient.self] = newValue }
    }
}

/// Main-actor-isolated owner of the live `ReminderScheduler` and the
/// `SettingsStore` it reads from. Lazily instantiated on first reducer call.
@MainActor
private final class LiveReminderSchedulerBridge {
    static let shared = LiveReminderSchedulerBridge()

    let settings = SettingsStore()
    let scheduler: ReminderScheduling = ReminderScheduler()

    private init() {}

    func scheduleAll() async {
        await scheduler.scheduleReminders(using: settings)
    }

    func reschedule(_ type: ReminderType) async {
        await scheduler.rescheduleReminder(for: type, using: settings)
    }

    func cancel(_ type: ReminderType) {
        scheduler.cancelReminder(for: type)
    }

    func cancelAll() {
        scheduler.cancelAllReminders()
    }
}
