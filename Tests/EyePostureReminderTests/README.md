# EyePostureReminderTests — Conventions

This document captures conventions for the unit-test suite that complement
the Google Swift Style guide (`docs/google_swift_coding_style.md`).

## Test fixture lifecycle and Implicitly Unwrapped Optionals (IUOs)

Test cases routinely declare fixtures as IUOs:

```swift
final class AppCoordinatorTests: XCTestCase {
    var settings: SettingsStore!
    var sut: AppCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        settings = SettingsStore(store: MockSettingsPersisting())
        sut = AppCoordinator(settings: settings, …)
    }
}
```

This is **intentional and conformant** with the project style. Per
Google Swift Style §Implicitly Unwrapped Optionals:

> Implicitly unwrapped optionals are also allowed in unit tests. This is for
> reasons similar to the UI object scenario above — the lifetime of test
> fixtures often begins not in the test's initializer but in the `setUp()`
> method of a test so that they can be reset before the execution of each
> test.

Production code in `EyePostureReminder/` and `Extensions/` must **not** use
IUOs (audited in #648). When introducing new test fixtures, prefer the IUO
pattern over `Optional<T>` + force-unwrap to keep test bodies focused on
behaviour rather than fixture nil-checking.

## Naming convention

Test methods follow `test_subject_action_expectedResult`, matching the UI
test suite (`Tests/EyePostureReminderUITests/README.md`). Group related
tests with `// MARK: -` sections.

## Mocks and fakes

Place protocol-conforming mocks in `Tests/EyePostureReminderTests/Mocks/`
and prefix the type with `Mock` (e.g. `MockOverlayPresenting`,
`MockNotificationCenter`). Mocks should be deterministic and capture the
inputs needed for assertions; avoid recording state the test does not read.

## Async / `@MainActor`

Annotate `XCTestCase` subclasses with `@MainActor` when they exercise
`@MainActor`-isolated production types. Use `async throws` setup/tear-down
variants (`setUp() async throws`, `tearDown() async throws`) to compose
cleanly with the rest of the suite.
