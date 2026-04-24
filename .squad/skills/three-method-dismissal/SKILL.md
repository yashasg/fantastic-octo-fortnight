# Skill: Three-Method Dismissal for Full-Screen Overlays

**Type:** UX Interaction Pattern  
**Domain:** Modal Overlays, Full-Screen Interruptions  
**Created:** 2026-04-24 (Reuben)  
**Last Updated:** 2026-04-24

---

## When to Use This Pattern

Apply this pattern for **full-screen overlays** that:
- Interrupt the user's current task (e.g., reminders, break timers, notifications)
- Are **time-limited** (user should see them for a specific duration, but can dismiss early)
- Are **non-critical** (user should be able to skip without penalty)

**Do NOT use this pattern when:**
- The overlay is **critical** and requires user input (e.g., "Accept Terms of Service") — use modal dialog with explicit button instead
- The content is **informational only** with no action required — use a banner or toast instead
- The overlay contains **form fields** or complex interactions — use a modal sheet with explicit "Cancel" and "Done" buttons

---

## Core Principles

1. **Respect user autonomy.** Any interruption should be immediately dismissible by the user.
2. **Support different interaction preferences.** Some users prefer tapping buttons; others prefer gestures.
3. **Auto-dismiss is the happy path.** The overlay should automatically disappear when its purpose is complete (e.g., timer elapses).

---

## The Three Methods

### Method 1: Tap Dismiss Button (×)

**Interaction:**
- User taps a visible dismiss button (typically `×` icon in top-right corner)
- Overlay slides down (or fades out) with animation
- User returns to previous context

**When users prefer this:**
- Precise, intentional dismissal
- Users with motor control preferences (tap is easier than swipe)
- VoiceOver users (button is easily discoverable)

**Implementation notes:**
- Button must meet **44pt × 44pt tap target minimum** (iOS accessibility guideline)
- Use SF Symbol `xmark.circle.fill` or `xmark` for consistency
- Accessible label: "Dismiss [overlay name]" (e.g., "Dismiss reminder")

---

### Method 2: Swipe Gesture (Down)

**Interaction:**
- User swipes down from anywhere on the overlay (pan gesture)
- Overlay follows finger during drag (interactive dismissal)
- If drag exceeds threshold (e.g., 100pt), overlay dismisses on release
- If drag is too small, overlay snaps back to original position

**When users prefer this:**
- Natural iOS gesture (matches modal sheet dismissal)
- Faster than targeting a small button
- Works one-handed while holding device

**Implementation notes:**
- Use `UIPanGestureRecognizer` or SwiftUI `.gesture(DragGesture())`
- Interactive dismissal: overlay's `y` position follows finger (`gesture.translation.height`)
- Threshold: if `translation.height > 100pt`, commit dismissal; else, spring back
- Animation: `UIView.animate` or SwiftUI `.animation(.spring())`

---

### Method 3: Auto-Dismiss (Timer Elapses)

**Interaction:**
- Overlay displays a countdown (e.g., "20 seconds remaining")
- When countdown reaches 0, overlay automatically fades out
- User does nothing — the overlay disappears on its own

**When users prefer this:**
- Users who are following the intended action (e.g., taking a break)
- Hands-free scenarios (user is looking away from device)
- Expected behaviour for time-based reminders

**Implementation notes:**
- Use `DispatchQueue.main.asyncAfter(deadline: .now() + duration)` or `Timer`
- Countdown label updates every second (1s intervals)
- Auto-dismiss animation should differ from manual dismiss (fade vs. slide) to signal "completion" vs. "cancellation"

---

## Animation Guidelines

### Appear Animation
- **Slide up from bottom:** 0.3s ease-out (`curveEaseOut`)
- Starts off-screen (`y = screen height`) → animates to `y = 0`
- Optional: subtle haptic feedback (`.notificationOccurred(.warning)`) on appear

### Manual Dismiss Animation (Tap or Swipe)
- **Slide down to bottom:** 0.2s ease-in (`curveEaseIn`)
- Animates from `y = 0` → `y = screen height`
- No haptic feedback (dismissal is user-initiated)

### Auto-Dismiss Animation (Timer Elapses)
- **Fade out:** 0.3s linear (`curveLinear`)
- `alpha` animates from `1.0` → `0.0`
- Optional: success haptic (`.notificationOccurred(.success)`) on completion

**Rationale for different animations:**
- Slide = user action (manual dismissal)
- Fade = automatic completion (timer finished)
- Differentiating these helps users build mental model of what happened

---

## Implementation Checklist

### Phase 1: Core Dismissal Logic

- [ ] **Dismiss button** (×) in top-right corner, 44pt × 44pt tap target
- [ ] **Tap handler** → triggers dismiss animation
- [ ] **Swipe-down gesture recognizer** → tracks finger, dismisses if threshold exceeded
- [ ] **Auto-dismiss timer** → `DispatchQueue.asyncAfter` or `Timer`, dismisses when elapsed
- [ ] **Animations** → slide up (appear), slide down (manual), fade out (auto)
- [ ] **Window lifecycle** → UIWindow created on demand, removed after dismissal

### Phase 2: Polish

- [ ] **Haptic feedback** (optional) → notification haptic on appear, success haptic on auto-dismiss
- [ ] **Reduce Motion support** → skip animations if user has `UIAccessibility.isReduceMotionEnabled`
- [ ] **VoiceOver support** → `accessibilityViewIsModal = true`, button has accessible label
- [ ] **Countdown announcements** → VoiceOver announces remaining time every 5 seconds

---

## Code Example (UIKit)

```swift
class OverlayManager {
    private var overlayWindow: UIWindow?
    private var dismissTimer: DispatchWorkItem?
    
    func show(duration: TimeInterval) {
        // Create window at alert level
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.windowLevel = .alert + 1
        
        // Create overlay view controller
        let overlayVC = OverlayViewController(duration: duration)
        overlayVC.onDismiss = { [weak self] in
            self?.dismiss(animated: true)
        }
        
        window.rootViewController = overlayVC
        window.makeKeyAndVisible()
        self.overlayWindow = window
        
        // Slide up animation
        window.frame.origin.y = UIScreen.main.bounds.height
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            window.frame.origin.y = 0
        }
        
        // Schedule auto-dismiss
        let workItem = DispatchWorkItem { [weak self] in
            self?.dismiss(animated: true, isAuto: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
        dismissTimer = workItem
    }
    
    func dismiss(animated: Bool, isAuto: Bool = false) {
        dismissTimer?.cancel()
        
        guard let window = overlayWindow else { return }
        
        if animated {
            if isAuto {
                // Fade out (auto-dismiss)
                UIView.animate(withDuration: 0.3, animations: {
                    window.alpha = 0
                }) { _ in
                    window.isHidden = true
                    self.overlayWindow = nil
                }
            } else {
                // Slide down (manual dismiss)
                UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
                    window.frame.origin.y = UIScreen.main.bounds.height
                }) { _ in
                    window.isHidden = true
                    self.overlayWindow = nil
                }
            }
        } else {
            window.isHidden = true
            overlayWindow = nil
        }
    }
}

class OverlayViewController: UIViewController {
    var onDismiss: (() -> Void)?
    let duration: TimeInterval
    
    init(duration: TimeInterval) {
        self.duration = duration
        super.init(nibName: nil, bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add dismiss button
        let dismissButton = UIButton(type: .system)
        dismissButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        dismissButton.addTarget(self, action: #selector(didTapDismiss), for: .touchUpInside)
        dismissButton.accessibilityLabel = "Dismiss reminder"
        // ... position in top-right corner
        
        // Add swipe-down gesture
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        view.addGestureRecognizer(panGesture)
    }
    
    @objc func didTapDismiss() {
        onDismiss?()
    }
    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        
        switch gesture.state {
        case .changed:
            if translation.y > 0 { // Only allow downward swipes
                view.frame.origin.y = translation.y
            }
        case .ended:
            if translation.y > 100 {
                // Threshold exceeded, dismiss
                onDismiss?()
            } else {
                // Snap back
                UIView.animate(withDuration: 0.2) {
                    self.view.frame.origin.y = 0
                }
            }
        default:
            break
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
```

---

## Testing This Pattern

**Success criteria:**
- 100% of users successfully dismiss overlay using at least one method
- No users report "couldn't close the overlay" in usability testing
- VoiceOver users can discover and use dismiss button

**Failure modes to watch for:**
- Users repeatedly tap overlay background expecting it to dismiss → **Add tap-to-dismiss to background view**
- Users expect swipe-up to dismiss (instead of swipe-down) → **iOS convention is swipe-down; educate with subtle animation hint on first show**
- Users don't realize they can dismiss early → **Ensure dismiss button (×) is visually prominent**

---

## Variants

### Variant A: Add Tap-Anywhere-to-Dismiss

**Use when:** The overlay has minimal interactive content (e.g., just text and countdown).

**Implementation:**
```swift
let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapDismiss))
view.addGestureRecognizer(tapGesture)
```

**Trade-off:** If overlay contains buttons or interactive elements, tap-to-dismiss can cause accidental dismissals.

---

### Variant B: Require Long-Press to Dismiss

**Use when:** You want to prevent accidental dismissals (e.g., safety-critical warnings).

**Implementation:**
```swift
let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress))
longPressGesture.minimumPressDuration = 1.0
dismissButton.addGestureRecognizer(longPressGesture)
```

**Trade-off:** Less convenient for users; only use if accidental dismissal has serious consequences.

---

## Related Patterns

- **Modal Sheet Dismissal:** iOS standard (swipe down to dismiss) — this pattern extends that to full-screen overlays
- **Toast Notifications:** Auto-dismiss only, no manual dismissal — use for brief, non-critical messages
- **Persistent Overlays:** No auto-dismiss, user must explicitly dismiss — use for critical confirmations

---

## References

- Apple Human Interface Guidelines: Modality ([link](https://developer.apple.com/design/human-interface-guidelines/modality))
- iOS gesture conventions ([Apple Developer](https://developer.apple.com/design/human-interface-guidelines/gestures))
- Accessibility tap target sizes ([WCAG 2.1 guidelines](https://www.w3.org/WAI/WCAG21/Understanding/target-size.html))

---

**Pattern Status:** ✅ Validated (Eye & Posture Reminder project)  
**Next Review:** After user testing / beta feedback
