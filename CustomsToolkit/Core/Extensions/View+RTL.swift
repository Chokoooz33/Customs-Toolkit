import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public extension View {
    
    /// Ensures technical numbers, HS codes, and currency strings always display in Left-To-Right direction.
    func preserveTechnicalLTR() -> some View {
        self
            .environment(\.layoutDirection, .leftToRight)
            .flipsForRightToLeftLayoutDirection(false)
    }
}

public extension String {
    /// Wraps string in Unicode Left-To-Right Isolate marks (\u{2066}...\u{2069}) to prevent RTL bidi reordering.
    var isolatedLTR: String {
        return "\u{2066}\(self)\u{2069}"
    }
}


// MARK: - Keyboard dismissal

public extension View {
    /// Installs a non-blocking window tap recognizer while this screen is visible.
    /// Tapping outside a text input dismisses the keyboard, while taps inside
    /// UITextField / UITextView continue to focus and edit normally.
    @ViewBuilder
    func dismissKeyboardOnBackgroundTap() -> some View {
        #if canImport(UIKit)
        self.background(KeyboardDismissInstaller())
        #else
        self
        #endif
    }
}

#if canImport(UIKit)
private struct KeyboardDismissInstaller: UIViewRepresentable {
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var installedWindow: UIWindow?
        var recognizer: UITapGestureRecognizer?

        @objc func handleTap() {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }

        func installIfNeeded(from view: UIView) {
            guard let window = view.window else { return }
            guard installedWindow !== window else { return }

            uninstall()

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            window.addGestureRecognizer(tap)

            recognizer = tap
            installedWindow = window
        }

        func uninstall() {
            if let recognizer, let installedWindow {
                installedWindow.removeGestureRecognizer(recognizer)
            }
            recognizer = nil
            installedWindow = nil
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var candidate = touch.view
            while let view = candidate {
                // Do not immediately dismiss when the user is tapping into/editing an input.
                if view is UITextField || view is UITextView {
                    return false
                }
                candidate = view.superview
            }
            return true
        }

    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            context.coordinator.installIfNeeded(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.installIfNeeded(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.uninstall()
    }
}
#endif
