import UIKit
import RealityKit

// MARK: - EntityActionMenu
//
// Context menu that appears when the user long-presses an entity.
//
// Three menu modes:
//   .standard  → Add Movement | [Light Settings] | [Material tools] | Lock | Delete
//   .camera    → Add Shot | Lock | Delete

class EntityActionMenu: UIView {

    // ── Public callback ──────────────────────────────────────────────────────
    var onAction: ((ActionType) -> Void)?

    enum ActionType {
        case move           // standard: add move animation
        case rotate         // standard: add rotate animation
        case addMovement    // standard: unified animation picker (Move / Rotate / Light)
        case changeColour   // standard: open color picker (walls/ground only)
        case editMaterial   // standard: open material editor (walls/ground only)
        case lightSettings  // standard: open light control panel (lights only)
        case setRatio       // standard: open ratio lock input (walls/ground only)
        case addShot        // camera:   open shot/movement picker
        case aspectRatio    // camera:   open aspect ratio picker
        case rename         // rename entity
        case notes          // add/edit notes
        case lock
        case delete
        case duplicate      // duplicate the selected entity
    }

    enum MenuMode {
        case standard   // any non-camera entity  →  Add Movement/Animations | Lock | Delete (+ contextual actions)
        case camera     // SceneCamera entity     →  Add Shot | Lock | Delete
    }

    // ── Private state ────────────────────────────────────────────────────────
    private var mode: MenuMode = .standard
    private var isCurrentlyLocked: Bool = false
    private var showColorOption: Bool = false
    private var showLightOption: Bool = false
    private var isBackground: Bool = false

    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 20
        sv.alignment = .center
        sv.isLayoutMarginsRelativeArrangement = true
        sv.layoutMargins = UIEdgeInsets(top: 8, left: 24, bottom: 8, right: 24)
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // ── Init ─────────────────────────────────────────────────────────────────
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        layer.cornerRadius = 28
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 12

        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    // ── Configuration — MUST be called before addSubview ─────────────────────
    func configure(mode: MenuMode, isLocked: Bool, showColorOption: Bool = false, showLightOption: Bool = false, isBackground: Bool = false) {
        self.mode = mode
        self.isCurrentlyLocked = isLocked
        self.showColorOption = showColorOption
        self.showLightOption = showLightOption
        self.isBackground = isBackground
        buildButtons()
    }

    // Legacy helper kept for any call sites that still use it
    func setLockTitle(isLocked: Bool) {
        self.isCurrentlyLocked = isLocked
        stackView.arrangedSubviews.compactMap { $0 as? UIButton }.forEach { btn in
            if btn.currentTitle == "Lock" || btn.currentTitle == "Unlock" {
                btn.setTitle(isLocked ? "Unlock" : "Lock", for: .normal)
            }
        }
    }

    // ── Button builder ────────────────────────────────────────────────────────
    private func buildButtons() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // When locked, show only Unlock + Duplicate (no other interaction allowed)
        if isCurrentlyLocked {
            addMenuButton(title: "Unlock", action: .lock)
            if !isBackground {
                addSeparator()
                addMenuButton(title: "Duplicate", action: .duplicate)
            }
            return
        }

        switch mode {

        case .standard:
            // Add Movement / Add Animations | [Edit Material] | [Change Colour] | Lock | Delete
            addMenuButton(title: showLightOption ? "Add Animations" : "Add Movement", action: .addMovement)
            addSeparator()
            if showLightOption {
                addMenuButton(title: "Light Settings", action: .lightSettings)
                addSeparator()
            }
            if showColorOption {
                addMenuButton(title: "Edit Material", action: .editMaterial)
                addSeparator()
                addMenuButton(title: "Change Colour", action: .changeColour)
                addSeparator()
                addMenuButton(title: "Set Ratio", action: .setRatio)
                addSeparator()
            }
            addMenuButton(title: "Rename", action: .rename)
            addSeparator()
            addMenuButton(title: "Notes", action: .notes)
            addSeparator()
            addMenuButton(title: "Lock", action: .lock)
            if !isBackground {
                addSeparator()
                addMenuButton(title: "Duplicate", action: .duplicate)
            }
            addSeparator()
            addMenuButton(title: "Delete", action: .delete, isDestructive: true)

        case .camera:
            // Camera: Add Shot | Aspect Ratio | Lock | Duplicate | Delete
            addMenuButton(title: "Add Shot", action: .addShot)
            addSeparator()
            addMenuButton(title: "Aspect Ratio", action: .aspectRatio)
            addSeparator()
            addMenuButton(title: "Rename", action: .rename)
            addSeparator()
            addMenuButton(title: "Notes", action: .notes)
            addSeparator()
            addMenuButton(title: "Lock", action: .lock)
            addSeparator()
            addMenuButton(title: "Duplicate", action: .duplicate)
            addSeparator()
            addMenuButton(title: "Delete", action: .delete, isDestructive: true)
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    private func addMenuButton(title: String, action: ActionType, isDestructive: Bool = false) {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        btn.tintColor = isDestructive
            ? UIColor(red: 169/255, green: 32/255, blue: 57/255, alpha: 1)
            : .label
        btn.addAction(UIAction { [weak self] _ in self?.onAction?(action) }, for: .touchUpInside)
        stackView.addArrangedSubview(btn)
    }

    private func addSeparator() {
        let line = UIView()
        line.backgroundColor = .separator
        line.widthAnchor.constraint(equalToConstant: 1).isActive = true
        line.heightAnchor.constraint(equalToConstant: 24).isActive = true
        stackView.addArrangedSubview(line)
    }
}
