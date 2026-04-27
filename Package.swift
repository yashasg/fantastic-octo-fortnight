// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EyePostureReminder",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .executable(name: "EyePostureReminder", targets: ["EyePostureReminder"])
    ],
    targets: [
        .executableTarget(
            name: "EyePostureReminder",
            path: "EyePostureReminder",
            resources: [
                // Includes bundled app defaults, color assets, localization, and Fonts/*.ttf.
                .process("Resources"),
                .copy("PrivacyInfo.xcprivacy")
            ]
        ),
        .testTarget(
            name: "EyePostureReminderTests",
            dependencies: ["EyePostureReminder"],
            path: "Tests/EyePostureReminderTests",
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
