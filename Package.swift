// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EyePostureReminder",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .executable(name: "EyePostureReminder", targets: ["EyePostureReminder"])
    ],
    dependencies: [
        // Pinned to exact 1.25.5 per #662 / #664 — do not bump without explicit
        // authorisation from the migration owner. Subsequent TCA migration issues
        // (#665+) consume `ComposableArchitecture` from this dependency.
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            exact: "1.25.5"
        )
    ],
    targets: [
        .target(
            name: "ScreenTimeExtensionShared",
            path: "Extensions/Shared",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "EyePostureReminder",
            dependencies: [
                "ScreenTimeExtensionShared",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ],
            path: "EyePostureReminder",
            resources: [
                // Includes bundled app defaults, color assets, localization, and Fonts/*.ttf.
                .process("Resources"),
                .copy("PrivacyInfo.xcprivacy")
            ]
        ),
        .testTarget(
            name: "EyePostureReminderTests",
            dependencies: [
                "EyePostureReminder",
                "ScreenTimeExtensionShared",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ],
            path: "Tests/EyePostureReminderTests",
            resources: [
                .process("Fixtures")
            ],
            linkerSettings: [
                .linkedFramework("AppIntents", .when(platforms: [.iOS]))
            ]
        )
    ]
)
