import AppKit
import QuartzCore

/// Presents and dismisses a panel's content with Core Animation springs.
///
/// The SwiftUI content is drawn once; the render server scales and fades the
/// layer. Animating the same thing in SwiftUI re-rasterizes every glyph and
/// shadow at each intermediate scale, which costs far more CPU.
@MainActor
enum PanelMotion {
    /// Animates to shown or hidden, starting from wherever the layer is on
    /// screen right now, so a reopen halfway through a close just turns around.
    ///
    /// - Parameters:
    ///   - anchor: the point (in the view's bounds, y up) the panel grows from.
    ///   - offset: where the hidden state sits relative to the shown one.
    static func animate(_ view: NSView, presented: Bool, anchor: CGPoint, hiddenScale: CGFloat = 0.94,
                        offset: CGSize = .zero, completion: (() -> Void)? = nil) {
        view.wantsLayer = true
        guard let layer = view.layer else { completion?(); return }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let hidden = transform(for: layer, anchor: anchor, scale: reduceMotion ? 1 : hiddenScale,
                               offset: reduceMotion ? .zero : offset)
        let toTransform = presented ? CATransform3DIdentity : hidden
        let toOpacity: Float = presented ? 1 : 0
        let fromTransform = layer.presentation()?.transform ?? layer.transform
        let fromOpacity = layer.presentation()?.opacity ?? layer.opacity

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock(completion)
        layer.transform = toTransform
        layer.opacity = toOpacity
        layer.add(animation("transform", from: NSValue(caTransform3D: fromTransform),
                            to: NSValue(caTransform3D: toTransform), reduceMotion: reduceMotion), forKey: "ferry.transform")
        layer.add(animation("opacity", from: fromOpacity, to: toOpacity, reduceMotion: reduceMotion), forKey: "ferry.opacity")
        CATransaction.commit()
    }

    /// Puts the content in its hidden state without animating, before a first show.
    static func setHidden(_ view: NSView, anchor: CGPoint, hiddenScale: CGFloat = 0.94, offset: CGSize = .zero) {
        view.wantsLayer = true
        guard let layer = view.layer else { return }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.removeAllAnimations()
        layer.transform = transform(for: layer, anchor: anchor, scale: reduceMotion ? 1 : hiddenScale,
                                    offset: reduceMotion ? .zero : offset)
        layer.opacity = 0
        CATransaction.commit()
    }

    /// Scale about `anchor` (bounds coordinates), whatever the layer's own anchor point is.
    private static func transform(for layer: CALayer, anchor: CGPoint, scale: CGFloat, offset: CGSize) -> CATransform3D {
        let origin = CGPoint(x: anchor.x - layer.anchorPoint.x * layer.bounds.width,
                             y: anchor.y - layer.anchorPoint.y * layer.bounds.height)
        var t = CATransform3DMakeTranslation(origin.x + offset.width, origin.y + offset.height, 0)
        t = CATransform3DScale(t, scale, scale, 1)
        return CATransform3DTranslate(t, -origin.x, -origin.y, 0)
    }

    private static func animation(_ keyPath: String, from: Any, to: Any, reduceMotion: Bool) -> CAAnimation {
        if reduceMotion {
            let fade = CABasicAnimation(keyPath: keyPath)
            fade.fromValue = from
            fade.toValue = to
            fade.duration = 0.15
            fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
            return fade
        }
        // Critically damped: no bounce, nothing here was flung.
        let spring = CASpringAnimation(perceptualDuration: 0.28, bounce: 0)
        spring.keyPath = keyPath
        spring.fromValue = from
        spring.toValue = to
        spring.duration = spring.settlingDuration
        return spring
    }
}
