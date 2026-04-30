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
                "ScreenTimeExtensionShared"
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
                "ScreenTimeExtensionShared"
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
