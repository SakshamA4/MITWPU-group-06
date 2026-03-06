import UIKit
import RealityKit

class EntityActionMenu: UIView {
    var onAction: ((ActionType) -> Void)?

    enum ActionType {
        case move, rotate, lock, delete
    }

    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 20
        sv.alignment = .center
        sv.isLayoutMarginsRelativeArrangement = true
        sv.layoutMargins = UIEdgeInsets(top: 8, left: 24, bottom: 8, right: 24)
        return sv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Helper to Update Lock Title
    func setLockTitle(isLocked: Bool) {
        // This finds the button labeled "Lock" or "Unlock" and updates it
        stackView.arrangedSubviews.compactMap { $0 as? UIButton }.forEach {
            btn in
            if btn.currentTitle == "Lock" || btn.currentTitle == "Unlock" {
                btn.setTitle(isLocked ? "Unlock" : "Lock", for: .normal)
            }
        }
    }

    // MARK: - New Top Bar UI Elements

    private let topBarView: UIView = {
        let view = UIView()
        view.backgroundColor = .black  // Or .systemBackground / custom dark color
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(
            UIImage(systemName: "chevron.left", withConfiguration: config),
            for: .normal
        )
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let sceneNameLabel: UILabel = {
        let label = UILabel()
        label.text = "Living Room"  // Default text
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // ... existing properties ...

    private func setupUI() {
        backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        layer.cornerRadius = 28
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 12

        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        addMenuButton(title: "Move", action: .move)
        addSeparator()
        addMenuButton(title: "Rotate", action: .rotate)
        addSeparator()
        addMenuButton(title: "Lock", action: .lock)
        addSeparator()
        addMenuButton(title: "Delete", action: .delete, isDestructive: true)
    }

    private func addMenuButton(
        title: String,
        action: ActionType,
        isDestructive: Bool = false
    ) {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        btn.tintColor =
            isDestructive
            ? UIColor(red: 169 / 255, green: 32 / 255, blue: 57 / 255, alpha: 1)
            : .label
        btn.addAction(
            UIAction { [weak self] _ in self?.onAction?(action) },
            for: .touchUpInside
        )
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

