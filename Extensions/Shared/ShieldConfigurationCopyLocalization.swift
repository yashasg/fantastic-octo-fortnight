import Foundation

public enum ShieldConfigurationCopyLocalizationKey: String, CaseIterable, Sendable {
    case eyesTitle = "shield.eyes.title"
    case eyesSubtitle = "shield.eyes.subtitle"
    case postureTitle = "shield.posture.title"
    case postureSubtitle = "shield.posture.subtitle"
    case genericTitle = "shield.generic.title"
    case genericSubtitle = "shield.generic.subtitle"
    case countdownSubtitle = "shield.countdown.subtitle"
}

public enum ShieldConfigurationCopyLocalization {
    public static let tableName = "ShieldConfiguration"

    public static func localizedString(
        for key: ShieldConfigurationCopyLocalizationKey,
        bundle: Bundle? = nil
    ) -> String {
        localizedString(for: key, fallback: key.fallback, bundle: bundle)
    }

    public static func hasLocalizedResource(
        for key: ShieldConfigurationCopyLocalizationKey,
        bundle: Bundle? = nil
    ) -> Bool {
        let bundle = bundle ?? defaultBundle
        return bundle.localizedString(
            forKey: key.rawValue,
            value: nil,
            table: tableName
        ) != key.rawValue
    }

    static func countdownSubtitle(
        remainingSeconds: Int,
        actionSubtitle: String,
        bundle: Bundle? = nil
    ) -> String {
        let format = localizedString(for: .countdownSubtitle, bundle: bundle)
        return String(format: format, locale: Locale.current, remainingSeconds, actionSubtitle)
    }

    static func localizedString(
        for key: ShieldConfigurationCopyLocalizationKey,
        fallback: String,
        bundle: Bundle?
    ) -> String {
        let bundle = bundle ?? defaultBundle
        return bundle.localizedString(
            forKey: key.rawValue,
            value: fallback,
            table: tableName
        )
    }

    private static var defaultBundle: Bundle {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle.main
        #endif
    }
}

private extension ShieldConfigurationCopyLocalizationKey {
    var fallback: String {
        switch self {
        case .eyesTitle:
            return "Time for an eye break"
        case .eyesSubtitle:
            return "Look 20 feet away and soften your focus."
        case .postureTitle:
            return "Time for a posture break"
        case .postureSubtitle:
            return "Stand up, roll your shoulders, and reset."
        case .genericTitle:
            return "Time for a break"
        case .genericSubtitle:
            return "Take a moment away from the screen."
        case .countdownSubtitle:
            return "%d seconds remaining. %@"
        }
    }
}
