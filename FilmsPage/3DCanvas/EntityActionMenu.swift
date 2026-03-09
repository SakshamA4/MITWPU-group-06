import UIKit
import RealityKit

// MARK: - EntityActionMenu
//
// Context menu that appears when the user taps an entity.
//
// ⚠️  CRITICAL FIX — init-order bug from previous version:
//     The old code set `showAddMovement` AFTER calling init(), but setupUI()
//     ran inside init(frame:) — so the conditional button was ALWAYS built
//     with showAddMovement == false (never shown).
//
//     Fix: setupUI() is now called from configure(mode:isLocked:), which the
//     caller must invoke BEFORE addSubview. This guarantees the mode is set
//     when the button list is built.
//
// Three menu modes:
//   .standard  → Move | Rotate | Add Movement | Lock | Delete
//   .camera    → Add Shot | Lock | Delete

class EntityActionMenu: UIView {

    // ── Public callback ──────────────────────────────────────────────────────
    var onAction: ((ActionType) -> Void)?

    enum ActionType {
        case move           // standard: add move animation
        case rotate         // standard: add rotate animation
        case addMovement    // standard: open animation-type picker (Move / Rotate)
        case addShot        // camera:   open shot/movement picker
        case lock
        case delete
    }

    enum MenuMode {
        case standard   // any non-camera entity  →  Move | Rotate | Add Movement | Lock | Delete
        case camera     // SceneCamera entity     →  Add Shot | Lock | Delete
    }

    // ── Private state ────────────────────────────────────────────────────────
    private var mode: MenuMode = .standard
    private var isCurrentlyLocked: Bool = false

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
    // Sets up the container shell only. Buttons are built in configure().
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
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    // ── Configuration — MUST be called before addSubview ─────────────────────
    func configure(mode: MenuMode, isLocked: Bool) {
        self.mode = mode
        self.isCurrentlyLocked = isLocked
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

        switch mode {

        case .standard:
            // Move | Rotate | Add Movement | Lock | Delete
            addMenuButton(title: "Move",         action: .move)
            addSeparator()
            addMenuButton(title: "Rotate",       action: .rotate)
            addSeparator()
            addMenuButton(title: "Add Movement", action: .addMovement)
            addSeparator()
            addMenuButton(title: isCurrentlyLocked ? "Unlock" : "Lock", action: .lock)
            addSeparator()
            addMenuButton(title: "Delete",       action: .delete, isDestructive: true)

        case .camera:
            // Add Shot | Lock | Delete
            addMenuButton(title: "Add Shot",     action: .addShot)
            addSeparator()
            addMenuButton(title: isCurrentlyLocked ? "Unlock" : "Lock", action: .lock)
            addSeparator()
            addMenuButton(title: "Delete",       action: .delete, isDestructive: true)
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
