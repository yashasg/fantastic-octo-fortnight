import ComposableArchitecture
import XCTest

@testable import EyePostureReminder

/// Phase 3 (`p0-tca-16` / #679) coverage for `SettingsFeature.snoozeTapped`.
/// Asserts the full effect chain — `SettingsClient.setSnoozedUntil` /
/// `setSnoozeCount` persistence, the calendar-aware snooze expiry maths, the
/// `.snoozeActivated` analytics event, and the 2 s saved-banner expiry —
/// for every `SnoozeOption`. The smaller "banner-only" smoke test stays in
/// `SettingsFeatureTests` for back-compat.
@MainActor
final class SettingsFeatureSnoozeTests: XCTestCase {

    func test_snoozeTapped_fiveMinutes_persistsExpiryAndZeroesCountAndLogsAnalytics() async {
        let clock = TestClock()
        let reference = Date(timeIntervalSince1970: 1_000_000)
        let snoozedUntilCalls = LockIsolated<[Date?]>([])
        let snoozeCountCalls = LockIsolated<[Int]>([])
        let analyticsEvents = LockIsolated<[AnalyticsEvent]>([])

        var settings = TCATestDependencies.silentSettingsClient()
        settings.setSnoozedUntil = { value in
            snoozedUntilCalls.withValue { $0.append(value) }
        }
        settings.setSnoozeCount = { value in
            snoozeCountCalls.withValue { $0.append(value) }
        }

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.settingsClient = settings
            $0.analyticsClient = AnalyticsClient(log: { event in
                analyticsEvents.withValue { $0.append(event) }
            })
            $0.continuousClock = clock
            $0.date = .constant(reference)
            $0.calendar = Calendar(identifier: .gregorian)
        }

        await store.send(.snoozeTapped(.fiveMinutes)) {
            $0.showSavedBanner = true
        }
        await clock.advance(by: .seconds(4))
        await store.receive(\.savedBannerExpired) {
            $0.showSavedBanner = false
        }

        snoozedUntilCalls.withValue { calls in
            XCTAssertEqual(calls.count, 1, "Expected exactly one setSnoozedUntil call")
            let elapsed = calls.first.flatMap { $0 }?.timeIntervalSince(reference) ?? .nan
            XCTAssertEqual(
                elapsed,
                5 * 60,
                accuracy: 0.001,
                "fiveMinutes must persist now + 300 s"
            )
        }
        snoozeCountCalls.withValue { calls in
            XCTAssertEqual(calls, [0],
                           "Activating a snooze must reset the consecutive snooze counter")
        }
        analyticsEvents.withValue { events in
            XCTAssertEqual(events.count, 1)
            guard case let .snoozeActivated(durationOption) = events.first else {
                XCTFail("Expected .snoozeActivated; got \(String(describing: events.first))")
                return
            }
            XCTAssertEqual(durationOption, "5m")
        }
    }

    func test_snoozeTapped_oneHour_persistsHourExpiryAndLogsAnalyticsCode() async {
        let clock = TestClock()
        let reference = Date(timeIntervalSince1970: 1_000_000)
        let snoozedUntilCalls = LockIsolated<[Date?]>([])
        let analyticsEvents = LockIsolated<[AnalyticsEvent]>([])

        var settings = TCATestDependencies.silentSettingsClient()
        settings.setSnoozedUntil = { value in
            snoozedUntilCalls.withValue { $0.append(value) }
        }

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.settingsClient = settings
            $0.analyticsClient = AnalyticsClient(log: { event in
                analyticsEvents.withValue { $0.append(event) }
            })
            $0.continuousClock = clock
            $0.date = .constant(reference)
            $0.calendar = Calendar(identifier: .gregorian)
        }

        await store.send(.snoozeTapped(.oneHour)) {
            $0.showSavedBanner = true
        }
        await clock.advance(by: .seconds(4))
        await store.receive(\.savedBannerExpired) {
            $0.showSavedBanner = false
        }

        snoozedUntilCalls.withValue { calls in
            let elapsed = calls.first.flatMap { $0 }?.timeIntervalSince(reference) ?? .nan
            XCTAssertEqual(
                elapsed,
                60 * 60,
                accuracy: 0.001
            )
        }
        analyticsEvents.withValue { events in
            guard case let .snoozeActivated(code) = events.first else {
                XCTFail("Expected .snoozeActivated event")
                return
            }
            XCTAssertEqual(code, "1h")
        }
    }

    func test_snoozeTapped_restOfDay_persistsCalendarAwareEndOfDay() async throws {
        let clock = TestClock()
        var calendar = Calendar(identifier: .gregorian)
        let utc = try XCTUnwrap(TimeZone(identifier: "UTC"))
        calendar.timeZone = utc
        let reference = try XCTUnwrap(calendar.date(from: DateComponents(
            timeZone: utc, year: 2026, month: 1, day: 1, hour: 12
        )))
        let expectedExpiry = try XCTUnwrap(calendar.date(from: DateComponents(
            timeZone: utc, year: 2026, month: 1, day: 2, hour: 0
        )))
        let snoozedUntilCalls = LockIsolated<[Date?]>([])
        let analyticsEvents = LockIsolated<[AnalyticsEvent]>([])

        var settings = TCATestDependencies.silentSettingsClient()
        settings.setSnoozedUntil = { value in
            snoozedUntilCalls.withValue { $0.append(value) }
        }

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.settingsClient = settings
            $0.analyticsClient = AnalyticsClient(log: { event in
                analyticsEvents.withValue { $0.append(event) }
            })
            $0.continuousClock = clock
            $0.date = .constant(reference)
            $0.calendar = calendar
        }

        await store.send(.snoozeTapped(.restOfDay)) {
            $0.showSavedBanner = true
        }
        await clock.advance(by: .seconds(4))
        await store.receive(\.savedBannerExpired) {
            $0.showSavedBanner = false
        }

        snoozedUntilCalls.withValue { calls in
            XCTAssertEqual(
                calls.first.flatMap { $0 },
                expectedExpiry,
                "restOfDay must persist next-day midnight in the injected calendar"
            )
        }
        analyticsEvents.withValue { events in
            guard case let .snoozeActivated(code) = events.first else {
                XCTFail("Expected .snoozeActivated event")
                return
            }
            XCTAssertEqual(code, "rest_of_day")
        }
    }
}
