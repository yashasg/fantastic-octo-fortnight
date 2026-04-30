import Foundation
import os

public struct AppGroupDefaultsUnavailableDiagnostic: Equatable {
    public let suiteName: String
    public let consumer: String

    public init(suiteName: String, consumer: String) {
        self.suiteName = suiteName
        self.consumer = consumer
    }

    public var message: String {
        """
        App Group UserDefaults suite '\(suiteName)' is unavailable for \(consumer); \
        extension-critical state was not written.
        """
    }
}

public enum AppGroupDefaults {
    public typealias SuiteFactory = (String) -> UserDefaults?
    public typealias DiagnosticHandler = (AppGroupDefaultsUnavailableDiagnostic) -> Void

    private static let log = OSLog(subsystem: "com.yashasgujjar.kshana", category: "AppGroupIPC")

    public static func resolve(
        suiteName: String = AppGroupIPCKeys.appGroupID,
        consumer: String,
        suiteFactory: SuiteFactory = { UserDefaults(suiteName: $0) },
        diagnosticHandler: DiagnosticHandler = AppGroupDefaults.logUnavailable,
        assertOnFailure: Bool = true
    ) -> UserDefaults? {
        guard let defaults = suiteFactory(suiteName) else {
            let diagnostic = AppGroupDefaultsUnavailableDiagnostic(
                suiteName: suiteName,
                consumer: consumer
            )
            diagnosticHandler(diagnostic)
            if assertOnFailure {
                debugAssert(diagnostic)
            }
            return nil
        }
        return defaults
    }

    public static func logUnavailable(_ diagnostic: AppGroupDefaultsUnavailableDiagnostic) {
        os_log("%{public}@", log: log, type: .fault, diagnostic.message)
    }

    private static func debugAssert(_ diagnostic: AppGroupDefaultsUnavailableDiagnostic) {
        #if DEBUG
        assertionFailure(diagnostic.message)
        #endif
    }
}
