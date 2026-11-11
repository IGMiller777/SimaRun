import AppKit
import QuartzCore

/// Draws the runner and the percentage inside the status item using plain Core Animation layers.
///
/// Setting `NSStatusBarButton.image` many times a second makes AppKit redo button layout on
/// every frame (several % of a core). Swapping a layer's contents costs almost nothing.
final class RunnerView: NSView {
    private var frames: [CGImage] = []
    private var iconSize = NSSize(width: 28, height: 18)
    private var font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    private var frameIndex = 0
    private var tinted = true

    // Tinted runners: iconLayer is a solid block of menu-bar text colour, cut to shape by maskLayer.
    // Full-colour custom runners: iconLayer shows the frame itself and has no mask.
    private let tintLayer = CALayer()
    private let maskLayer = CALayer()
    private let textLayer = CATextLayer()

    private static let sideInset: CGFloat = 5
    private static let gap: CGFloat = 4

    var text: String = "" {
        didSet {
            guard text != oldValue else { return }
            withoutAnimation { textLayer.string = text }
        }
    }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        autoresizingMask = [.width, .height]

        textLayer.alignmentMode = .left
        maskLayer.contentsGravity = .resize
        tintLayer.contentsGravity = .resize
        layer?.addSublayer(tintLayer)
        layer?.addSublayer(textLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    /// Switches character and/or size.
    func configure(frames: [CGImage], tinted: Bool, iconSize: NSSize, fontSize: CGFloat) {
        self.frames = frames
        self.tinted = tinted
        self.iconSize = iconSize
        font = .monospacedDigitSystemFont(ofSize: fontSize, weight: .regular)
        frameIndex = 0
        withoutAnimation {
            tintLayer.mask = tinted ? maskLayer : nil
            tintLayer.contents = nil
            maskLayer.contents = nil
            showFrame()
            textLayer.font = font
            textLayer.fontSize = fontSize
        }
        needsLayout = true
        needsDisplay = true // refresh colours for the new mode
    }

    private func showFrame() {
        guard frames.indices.contains(frameIndex) else { return }
        if tinted {
            maskLayer.contents = frames[frameIndex]
        } else {
            tintLayer.contents = frames[frameIndex]
        }
    }

    /// Width the status item needs for the current configuration.
    func requiredWidth(showingText: Bool) -> CGFloat {
        var width = Self.sideInset * 2 + iconSize.width
        if showingText {
            let widest = NSAttributedString(string: "100%", attributes: [.font: font]).size().width
            width += Self.gap + widest.rounded(.up)
        }
        return width
    }

    func advanceFrame() {
        guard !frames.isEmpty else { return }
        frameIndex = (frameIndex + 1) % frames.count
        withoutAnimation { showFrame() }
    }

    // Clicks must fall through to the status bar button underneath so the menu opens.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    // MARK: - Layout and colours

    override func layout() {
        super.layout()
        let textHeight = (font.ascender - font.descender + font.leading).rounded(.up) + 1
        withoutAnimation {
            tintLayer.frame = CGRect(x: Self.sideInset, y: ((bounds.height - iconSize.height) / 2).rounded(),
                                     width: iconSize.width, height: iconSize.height)
            maskLayer.frame = tintLayer.bounds
            let textX = tintLayer.frame.maxX + Self.gap
            textLayer.frame = CGRect(x: textX, y: ((bounds.height - textHeight) / 2).rounded(),
                                     width: max(0, bounds.width - textX), height: textHeight)
        }
    }

    override var wantsUpdateLayer: Bool { true }

    /// Called by AppKit whenever the view needs redisplay, including light/dark menu bar changes.
    override func updateLayer() {
        let color = NSColor.labelColor.cgColor // resolved for the menu bar's current appearance
        withoutAnimation {
            tintLayer.backgroundColor = tinted ? color : nil
            textLayer.foregroundColor = color
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        textLayer.contentsScale = window?.backingScaleFactor ?? 2
    }

    private func withoutAnimation(_ change: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        change()
        CATransaction.commit()
    }
}
