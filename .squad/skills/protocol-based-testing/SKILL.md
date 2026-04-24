# Skill: Protocol-Based Testing for iOS

**Pattern:** Abstract system frameworks behind protocols to enable fast, reliable unit testing without mocking Apple APIs.

---

## When to Use

Use this pattern when:
- You need to test logic that depends on Apple system frameworks (`UNUserNotificationCenter`, `UserDefaults`, `CoreLocation`, `URLSession`, etc.)
- You want unit tests to run without file I/O, network calls, or system permissions
- You need compile-time guarantees that your services depend on interfaces, not concrete types

**Don't use if:**
- You're testing SwiftUI views (use UI tests instead)
- The system API is already protocol-based (e.g., `URLSessionProtocol` — though it's not called that)
- You have zero tests and no plan to write them (just use concrete types)

---

## Pattern Structure

### 1. Define Protocol

Create a protocol matching the subset of the system API you actually use:

```swift
// Protocols/NotificationScheduling.swift
import UserNotifications

protocol NotificationScheduling {
    func requestAuthorization(
        options: UNAuthorizationOptions
    ) async throws -> Bool
    
    func add(_ request: UNNotificationRequest) async throws
    
    func removePendingNotificationRequests(
        withIdentifiers: [String]
    )
    
    func getPendingNotificationRequests() async -> [UNNotificationRequest]
}
```

**Key principle:** Only include methods you need. Don't mirror the entire 50-method API surface of `UNUserNotificationCenter`.

---

### 2. Conform System Type

Extend the real system type to conform to your protocol:

```swift
// Protocols/NotificationScheduling.swift (continued)
extension UNUserNotificationCenter: NotificationScheduling { }
```

**Why this works:** If the system type already has methods with matching signatures, the conformance is automatic (no implementation needed). Swift's type system does the rest.

---

### 3. Inject Protocol in Service

Your service depends on the *protocol*, not the concrete type:

```swift
// Services/ReminderScheduler.swift
final class ReminderScheduler {
    private let notificationCenter: NotificationScheduling
    
    init(notificationCenter: NotificationScheduling = UNUserNotificationCenter.current()) {
        self.notificationCenter = notificationCenter
    }
    
    func scheduleReminder(interval: TimeInterval) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Reminder"
        content.body = "Time to take a break"
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: interval,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
    }
}
```

**Default parameter pattern:** Production code gets real implementation without passing arguments. Tests pass mocks.

---

### 4. Create Mock for Testing

```swift
// Tests/Mocks/MockNotificationScheduler.swift
final class MockNotificationScheduler: NotificationScheduling {
    var authorizationRequested = false
    var authorizedResult = true
    var addedRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []
    
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationRequested = true
        return authorizedResult
    }
    
    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }
    
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
    }
    
    func getPendingNotificationRequests() async -> [UNNotificationRequest] {
        return addedRequests
    }
}
```

---

### 5. Write Fast Unit Tests

```swift
// Tests/Services/ReminderSchedulerTests.swift
import XCTest
@testable import EyePostureReminder

final class ReminderSchedulerTests: XCTestCase {
    func testScheduleReminder_addsNotificationRequest() async throws {
        // Given
        let mock = MockNotificationScheduler()
        let scheduler = ReminderScheduler(notificationCenter: mock)
        
        // When
        try await scheduler.scheduleReminder(interval: 1200)
        
        // Then
        XCTAssertEqual(mock.addedRequests.count, 1)
        let request = try XCTUnwrap(mock.addedRequests.first)
        XCTAssertEqual(request.content.title, "Reminder")
        
        let trigger = try XCTUnwrap(request.trigger as? UNTimeIntervalNotificationTrigger)
        XCTAssertEqual(trigger.timeInterval, 1200)
    }
}
```

**No system permissions, no file I/O, no 5-second waits.** Tests run in milliseconds.

---

## Common Protocol Abstractions

### UserDefaults

```swift
protocol SettingsPersisting {
    func integer(forKey key: String) -> Int
    func set(_ value: Int, forKey key: String)
    func bool(forKey key: String) -> Bool
    func set(_ value: Bool, forKey key: String)
    func double(forKey key: String) -> Double
    func set(_ value: Double, forKey key: String)
}

extension UserDefaults: SettingsPersisting { }
```

**Test mock:** Dictionary-backed implementation.

---

### URLSession

```swift
protocol NetworkFetching {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: NetworkFetching { }
```

**Test mock:** Returns pre-canned JSON from fixture files.

---

### CoreLocation

```swift
protocol LocationProviding {
    func requestWhenInUseAuthorization()
    var authorizationStatus: CLAuthorizationStatus { get }
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

extension CLLocationManager: LocationProviding { }
```

**Test mock:** Returns fake coordinates, avoids permission dialogs.

---

## Naming Conventions

Use **capability suffix** (Swift API Design Guidelines):
- `NotificationScheduling` (not `NotificationScheduler` — that's the concrete service)
- `SettingsPersisting` (not `SettingsStorage`)
- `OverlayPresenting` (not `OverlayPresenter`)

**Why:** Makes it clear the protocol describes a *capability*, matching Apple's conventions (`Equatable`, `Codable`, `Identifiable`).

---

## Trade-Offs

### ✅ Benefits
- **Fast tests:** No system dependencies, no permissions, no I/O
- **Decoupling:** Services depend on interfaces, not concrete types
- **Compile-time safety:** Protocol changes break call sites (vs runtime crashes with swizzling)
- **Clear intent:** Protocol shows exactly which methods you use

### ⚠️ Costs
- **Boilerplate:** ~10 lines of protocol definition + conformance per system API
- **Team discipline:** Developers must remember to inject protocols, not use singletons directly
- **Mock maintenance:** If Apple changes API signatures, mocks must update (rare, but happens on major iOS releases)

---

## Anti-Patterns to Avoid

### ❌ Don't Mirror Entire System API

```swift
// BAD: 50 methods from UNUserNotificationCenter
protocol NotificationScheduling {
    func requestAuthorization(...) async throws -> Bool
    func add(...) async throws
    func removePendingNotificationRequests(...)
    func removeAllPendingNotificationRequests()
    func getPendingNotificationRequests() async -> [UNNotificationRequest]
    func getNotificationSettings() async -> UNNotificationSettings
    func setBadgeCount(...) async throws
    func getDeliveredNotifications() async -> [UNNotification]
    func removeDeliveredNotifications(...)
    func removeAllDeliveredNotifications()
    // ... 40 more methods you don't use
}
```

**Instead:** Only include methods your service actually calls. You can add more later if needed.

---

### ❌ Don't Use Protocols as Namespaces

```swift
// BAD: Static methods in a protocol
protocol NotificationScheduling {
    static func scheduleReminder() async throws
}
```

**Instead:** Protocols abstract *instances*, not static factories. Use a proper service class with dependency injection.

---

### ❌ Don't Test the Protocol Itself

```swift
// BAD: This tests Apple's code, not yours
func testUNUserNotificationCenter_addsRequest() async throws {
    let center = UNUserNotificationCenter.current()
    let request = UNNotificationRequest(...)
    try await center.add(request)
    // Assert... what? That Apple's framework works?
}
```

**Instead:** Test your *service* that uses the protocol. The conformance to the protocol is a zero-line implementation — nothing to test.

---

## Checklist

When adding a new protocol-based abstraction:

- [ ] Protocol name uses capability suffix (`-ing`)
- [ ] Protocol only includes methods you actually use
- [ ] System type conforms via `extension` (no implementation needed if signatures match)
- [ ] Service has `init` parameter with default value: `= RealType.shared()` or `.current()`
- [ ] Mock records method calls in arrays/flags for test assertions
- [ ] Unit tests inject mock, verify interactions (not system behavior)

---

## Real-World Example: Notification Permission Flow

This pattern shines when testing permission flows.

**Without protocols:**
```swift
// Untestable: Calls system singleton directly
func requestPermissionAndSchedule() async throws {
    let granted = try await UNUserNotificationCenter.current()
        .requestAuthorization(options: [.alert, .sound])
    
    if granted {
        // schedule...
    } else {
        // show fallback UI...
    }
}

// Test would need to:
// 1. Swizzle UNUserNotificationCenter (fragile)
// 2. Or run on real device and manually grant/deny (slow)
```

**With protocols:**
```swift
// Testable: Depends on protocol
func requestPermissionAndSchedule(
    notificationCenter: NotificationScheduling = UNUserNotificationCenter.current()
) async throws {
    let granted = try await notificationCenter
        .requestAuthorization(options: [.alert, .sound])
    
    if granted {
        // schedule...
    } else {
        // show fallback UI...
    }
}

// Test:
func testDeniedPermission_showsFallbackUI() async throws {
    let mock = MockNotificationScheduler()
    mock.authorizedResult = false  // Simulate denial
    
    try await requestPermissionAndSchedule(notificationCenter: mock)
    
    // Assert fallback UI shown (via captured flag/published property)
}
```

---

## References

- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [Protocol-Oriented Programming (WWDC 2015)](https://developer.apple.com/videos/play/wwdc2015/408/)
- [Testing Tips & Tricks (WWDC 2018)](https://developer.apple.com/videos/play/wwdc2018/417/)

---

## Version

- **Created:** 2026-04-24
- **Last Updated:** 2026-04-24
- **Verified With:** Xcode 15, Swift 5.9, iOS 16+
