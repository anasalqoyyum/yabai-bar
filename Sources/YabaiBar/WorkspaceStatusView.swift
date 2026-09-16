import AppKit
import YabaiBarCore

@MainActor
protocol WorkspaceStatusViewDelegate: AnyObject {
    func workspaceStatusViewDidRequestMenu(_ view: WorkspaceStatusView, event: NSEvent)
    func workspaceStatusView(_ view: WorkspaceStatusView, didSelectSpace index: Int)
}

final class WorkspaceStatusView: NSView {
    weak var delegate: WorkspaceStatusViewDelegate?
    private var buttons: [WorkspaceButton] = []
    private var unavailableLabel: NSTextField?
    private var preferredWidth: CGFloat = 28

    override var intrinsicContentSize: NSSize {
        NSSize(width: preferredWidth, height: NSStatusBar.system.thickness)
    }

    func update(
        spaces: [YabaiSpace],
        configuration: AppConfiguration,
        available: Bool,
        workspaceInteractionEnabled: Bool
    ) {
        subviews.forEach { $0.removeFromSuperview() }
        buttons.removeAll()
        unavailableLabel = nil

        var x: CGFloat = 4
        for space in spaces {
            let button = WorkspaceButton(
                space: space,
                configuration: configuration,
                showsDisabledAppearance: !available
            )
            button.isEnabled = available && workspaceInteractionEnabled
            button.target = self
            button.action = #selector(selectSpace(_:))
            button.rightMouseHandler = { [weak self] event in
                guard let self else { return }
                self.delegate?.workspaceStatusViewDidRequestMenu(self, event: event)
            }
            let size = button.intrinsicContentSize
            button.frame = NSRect(x: x, y: 0, width: size.width, height: NSStatusBar.system.thickness)
            addSubview(button)
            buttons.append(button)
            x += size.width
        }

        if available, let lastButton = buttons.last {
            x -= lastButton.trimTrailingEdge(by: 4)
        }

        if !available {
            let label = NSTextField(labelWithString: spaces.isEmpty ? "yabai  !" : "!")
            label.font = .systemFont(ofSize: 11, weight: .semibold)
            label.textColor = .secondaryLabelColor
            label.alignment = .center
            let width = spaces.isEmpty ? CGFloat(48) : CGFloat(18)
            label.frame = NSRect(x: x, y: 2, width: width, height: NSStatusBar.system.thickness - 4)
            addSubview(label)
            unavailableLabel = label
            x += width
        }

        preferredWidth = max(x, 28)
        frame.size = NSSize(width: preferredWidth, height: NSStatusBar.system.thickness)
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    override func rightMouseDown(with event: NSEvent) {
        delegate?.workspaceStatusViewDidRequestMenu(self, event: event)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        for button in buttons where button.frame.contains(point) {
            return button
        }
        return bounds.contains(point) ? self : nil
    }

    @objc private func selectSpace(_ sender: WorkspaceButton) {
        delegate?.workspaceStatusView(self, didSelectSpace: sender.space.index)
    }
}

private final class WorkspaceButton: NSButton {
    let space: YabaiSpace
    var rightMouseHandler: ((NSEvent) -> Void)?
    private let configuration: AppConfiguration
    private let showsDisabledAppearance: Bool
    private var contentOffsetX: CGFloat = 0

    init(space: YabaiSpace, configuration: AppConfiguration, showsDisabledAppearance: Bool) {
        self.space = space
        self.configuration = configuration
        self.showsDisabledAppearance = showsDisabledAppearance
        super.init(frame: .zero)
        title = configuration.title(for: space)
        isBordered = false
        setButtonType(.momentaryChange)
        focusRingType = .default
        toolTip = space.label.isEmpty ? "Space \(space.index)" : "Space \(space.index): \(space.label)"
        setAccessibilityLabel(toolTip)
        setAccessibilityValue(space.hasFocus ? "Focused" : space.isVisible ? "Visible on another display" : "Not visible")
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize {
        let font = displayFont
        let width = min((title as NSString).size(withAttributes: [.font: font]).width, 96)
        return NSSize(width: ceil(width) + CGFloat(configuration.spacing.points * 2) + 8, height: NSStatusBar.system.thickness)
    }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds
        if space.hasFocus && configuration.activeStyle == .pill {
            NSColor.selectedContentBackgroundColor.withAlphaComponent(0.9).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 3), xRadius: 6, yRadius: 6).fill()
        }
        if isHighlighted {
            NSColor.labelColor.withAlphaComponent(0.16).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 6, yRadius: 6).fill()
        }

        let color: NSColor
        if showsDisabledAppearance {
            color = .disabledControlTextColor
        } else if space.hasFocus && configuration.activeStyle == .pill {
            color = .selectedMenuItemTextColor
        } else {
            color = .labelColor
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        let textRect = NSRect(x: contentOffsetX, y: 3, width: bounds.width, height: bounds.height - 4)
        (title as NSString).draw(in: textRect, withAttributes: [
            .font: displayFont,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ])

        if space.hasFocus && configuration.activeStyle == .underline {
            NSColor.controlAccentColor.setFill()
            NSBezierPath(roundedRect: NSRect(x: 7 + contentOffsetX, y: 2, width: max(4, bounds.width - 14), height: 2), xRadius: 1, yRadius: 1).fill()
        } else if configuration.showVisibleSpaces && space.isVisible && !space.hasFocus {
            NSColor.secondaryLabelColor.setFill()
            NSBezierPath(ovalIn: NSRect(x: bounds.midX + contentOffsetX - 1.5, y: 2, width: 3, height: 3)).fill()
        }
    }

    func trimTrailingEdge(by amount: CGFloat) -> CGFloat {
        let trim = min(amount, frame.width)
        frame.size.width -= trim
        contentOffsetX = trim / 2
        return trim
    }

    override func rightMouseDown(with event: NSEvent) {
        rightMouseHandler?(event)
    }

    override func highlight(_ flag: Bool) {
        super.highlight(flag)
        needsDisplay = true
    }

    private var displayFont: NSFont {
        let weight: NSFont.Weight = space.hasFocus && configuration.activeStyle == .bold ? .bold : .medium
        switch configuration.font {
        case .system: return .systemFont(ofSize: 12, weight: weight)
        case .monospaced: return .monospacedSystemFont(ofSize: 12, weight: weight)
        }
    }
}
