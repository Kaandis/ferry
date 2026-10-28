import AppKit
import SwiftUI

/// The welcome window: what Ferry does, and the two permissions it asks for.
@MainActor
enum Onboarding {
    private static var window: NSWindow?

    static func show() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 560),
                                  styleMask: [.titled, .closable, .fullSizeContentView],
                                  backing: .buffered, defer: false)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.backgroundColor = NSColor(Theme.background)
            window.title = String(localized: "Welcome to Ferry")
            window.contentView = NSHostingView(rootView: OnboardingView { close() })
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    static func close() {
        UserDefaults.standard.set(true, forKey: Prefs.hasCompletedOnboarding)
        window?.close()
    }
}

struct OnboardingView: View {
    var onDone: () -> Void
    private var permissions = Permissions.shared
    @AppStorage(Prefs.switcherModifier) private var modifier = "option"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(onDone: @escaping () -> Void) {
        self.onDone = onDone
    }

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 88, height: 88)
                .padding(.top, 36)

            Text("Welcome to Ferry")
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .padding(.top, 14)

            Text("Every window, one Tab away. Ferry needs one permission to work, and one more to show window pictures.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 400)
                .padding(.top, 8)

            VStack(spacing: 10) {
                PermissionRow(symbol: "accessibility",
                              title: "Accessibility",
                              tag: "Required",
                              detail: "Lets Ferry list your windows, catch the shortcut and bring a window forward.",
                              granted: permissions.accessibility,
                              prominent: true) { permissions.requestAccessibility() }
                PermissionRow(symbol: "rectangle.inset.filled.on.rectangle",
                              title: "Screen Recording",
                              tag: "Optional",
                              detail: "Shows a picture of each window. Without it you see app icons. Pictures stay in memory and are never saved or sent.",
                              granted: permissions.screenRecording,
                              prominent: permissions.accessibility) { permissions.requestScreenRecording() }
            }
            .padding(.top, 26)
            .padding(.horizontal, 32)
            .animation(reduceMotion ? nil : .harborPresent, value: permissions.accessibility)
            .animation(reduceMotion ? nil : .harborPresent, value: permissions.screenRecording)

            Spacer(minLength: 20)

            HStack(spacing: 8) {
                Text("Try it:")
                    .foregroundStyle(Theme.ink2)
                Keycap(key: modifierSymbol)
                Text("+").foregroundStyle(Theme.ink3)
                Keycap(key: "Tab")
                Spacer()
                Button(permissions.accessibility ? "Done" : "Later", action: onDone)
                    .buttonStyle(HarborButtonStyle(prominent: permissions.accessibility))
                    .keyboardShortcut(.defaultAction)
            }
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 32)
            .padding(.bottom, 28)
        }
        .frame(width: 560, height: 560)
        .background(Theme.background)
        .onAppear { permissions.watch(true) }
        .onDisappear { permissions.watch(false) }
    }

    private var modifierSymbol: String {
        switch modifier {
        case "command": "⌘"
        case "control": "⌃"
        default: "⌥"
        }
    }
}

private struct PermissionRow: View {
    let symbol: String
    let title: LocalizedStringKey
    let tag: LocalizedStringKey
    let detail: LocalizedStringKey
    let granted: Bool
    let prominent: Bool
    let request: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.raised))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(tag)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                        .padding(.horizontal, 7)
                        .frame(height: 18)
                        .background(Capsule().fill(Theme.raised))
                }
                Text(detail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(1.5)
            }

            Spacer(minLength: 8)

            Group {
                if granted {
                    Label("Allowed", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                        .frame(height: 30)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else {
                    Button("Allow…", action: request)
                        .buttonStyle(HarborButtonStyle(prominent: prominent))
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(.top, 3)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.hairline))
    }
}
