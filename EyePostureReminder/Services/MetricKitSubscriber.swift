import MetricKit
import os

/// Subscribes to `MXMetricManager` to receive daily metric and diagnostic payloads.
///
/// Registered once in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`.
/// Key health signals (crashes, hangs, memory pressure, CPU usage) are logged
/// via `Logger.lifecycle` so they appear in Console.app and Xcode Instruments.
///
/// **Crash reporting for TestFlight builds:**
/// iOS automatically captures crash logs for TestFlight testers. These are visible in:
/// - **Xcode Organizer** (Window → Organizer → Crashes) — aggregated from all testers
/// - **Console.app** — real-time `Logger.lifecycle` output when device is connected
///
/// MetricKit delivers `MXCrashDiagnostic` payloads 24h after a crash. The signal
/// number and exception type are logged at `.error` level so they appear prominently
/// in the Xcode Organizer log stream. No third-party crash SDK is needed for the beta.
final class MetricKitSubscriber: NSObject, MXMetricManagerSubscriber {

    static let shared = MetricKitSubscriber()

    private override init() { super.init() }

    /// Add this subscriber to `MXMetricManager`. Call once on app launch.
    func register() {
        MXMetricManager.shared.add(self)
        Logger.lifecycle.info("MetricKit subscriber registered")
    }

    // MARK: - MXMetricManagerSubscriber

    /// Receives daily metric payloads covering memory, CPU, launch times, and responsiveness.
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            logMetricPayload(payload)
        }
    }

    /// Receives diagnostic payloads: crashes, hangs, CPU exceptions, disk write exceptions.
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            logDiagnosticPayload(payload)
        }
    }

    // MARK: - Private

    private func logMetricPayload(_ payload: MXMetricPayload) {
        let start = payload.timeStampBegin
        let end   = payload.timeStampEnd
        Logger.lifecycle.info("MetricKit payload: \(start) – \(end)")

        if let memory = payload.memoryMetrics {
            let peakMB = memory.peakMemoryUsage.converted(to: .megabytes).value
            Logger.lifecycle.info("MetricKit peak_memory_mb=\(peakMB, format: .fixed(precision: 1))")
        }

        if let cpu = payload.cpuMetrics {
            let cpuS = cpu.cumulativeCPUTime.converted(to: .seconds).value
            Logger.lifecycle.info("MetricKit cpu_time_s=\(cpuS, format: .fixed(precision: 1))")
        }

        if let launch = payload.applicationLaunchMetrics {
            let firstDraw = launch.histogrammedTimeToFirstDraw
            Logger.lifecycle.info("MetricKit time_to_first_draw_histogram: \(firstDraw)")
        }

        if let responsiveness = payload.applicationResponsivenessMetrics {
            let hangTime = responsiveness.histogrammedApplicationHangTime
            Logger.lifecycle.info("MetricKit hang_time_histogram: \(hangTime)")
        }
    }

    private func logDiagnosticPayload(_ payload: MXDiagnosticPayload) {
        let start = payload.timeStampBegin
        let end   = payload.timeStampEnd
        Logger.lifecycle.info("MetricKit diagnostic payload: \(start) – \(end)")

        if let crashes = payload.crashDiagnostics, !crashes.isEmpty {
            Logger.lifecycle.error(
                "MetricKit crashes=\(crashes.count) in window \(start)–\(end)"
            )
            for crash in crashes {
                let signal = crash.signal?.intValue ?? -1
                let exceptionType = crash.exceptionType?.intValue ?? -1
                Logger.lifecycle.error(
                    "MetricKit crash signal=\(signal) exception_type=\(exceptionType)"
                )
            }
        }

        if let hangs = payload.hangDiagnostics, !hangs.isEmpty {
            Logger.lifecycle.warning(
                "MetricKit hangs=\(hangs.count) in window \(start)–\(end)"
            )
            for hang in hangs {
                let durationS = hang.hangDuration.converted(to: .seconds).value
                Logger.lifecycle.warning("MetricKit hang duration_s=\(durationS, format: .fixed(precision: 2))")
            }
        }

        if let cpuExceptions = payload.cpuExceptionDiagnostics, !cpuExceptions.isEmpty {
            Logger.lifecycle.warning(
                "MetricKit cpu_exceptions=\(cpuExceptions.count)"
            )
        }

        if let diskExceptions = payload.diskWriteExceptionDiagnostics, !diskExceptions.isEmpty {
            Logger.lifecycle.warning(
                "MetricKit disk_write_exceptions=\(diskExceptions.count)"
            )
        }
    }
}
