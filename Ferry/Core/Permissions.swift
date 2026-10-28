import AppKit
import ApplicationServices
import Observation

/// Accessibility (required) and Screen Recording (optional, for pictures).
///
/// macOS announces Accessibility changes with a distributed notification, so
/// that status stays current for free. Screen Recording has no such signal; it
/// is re-read when Ferry comes forward, and once a second only while the
/// welcome window is open.
@MainActor
@Observable
final class Permissions {
    static let shared = Permissions()

    private(set) var accessibility = AXIsProcessTrusted()
    private(set) var screenRecording = CGPreflightScreenCaptureAccess()
    /// Called when Accessibility turns on, so the hotkey and window tracking can start.
    @ObservationIgnored var onAccessibilityGranted: (() -> Void)?
    @ObservationIgnored private var tokens: [NSObjectProtocol] = []
    @ObservationIgnored private var watchTimer: Timer?

    func start() {
        guard tokens.isEmpty else { return }
        tokens.append(DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"), object: nil, queue: .main
        ) { [weak self] _ in
            // The trust value lags the notification slightly.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                MainActor.assumeIsolated { self?.refresh() }
            }
        })
        tokens.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
    }

    func refresh() {
        let wasTrusted = accessibility
        let trusted = AXIsProcessTrusted()
        let recording = CGPreflightScreenCaptureAccess()
        // Assign only on change: every assignment re-renders whatever observes it.
        if trusted != accessibility { accessibility = trusted }
        if recording != screenRecording { screenRecording = recording }
        if accessibility && !wasTrusted { onAccessibilityGranted?() }
        if accessibility && screenRecording { watch(false) }
    }

    /// Re-reads both permissions every second while `active` (the welcome window is open).
    func watch(_ active: Bool) {
        watchTimer?.invalidate()
        watchTimer = nil
        guard active, !(accessibility && screenRecording) else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer.tolerance = 0.3
        RunLoop.main.add(timer, forMode: .common)
        watchTimer = timer
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            open("Privacy_Accessibility")
        }
    }

    func requestScreenRecording() {
        // The first call shows the system prompt; later calls do nothing, so
        // also open the right pane in System Settings.
        if !CGRequestScreenCaptureAccess() {
            open("Privacy_ScreenCapture")
        }
    }

    private func open(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    #if DEBUG
    func override(accessibility: Bool, screenRecording: Bool) {
        self.accessibility = accessibility
        self.screenRecording = screenRecording
    }
    #endif
}
