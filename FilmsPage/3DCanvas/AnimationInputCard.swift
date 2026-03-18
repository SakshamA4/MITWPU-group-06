//
//  AnimationCardMode.swift
//  FilmsPage
//
//  Created by SDC-USER on 18/03/26.
//


import UIKit
import RealityKit

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - AnimationInputCard
//
// A polished, purpose-built modal sheet that replaces the plain UIAlertController
// for all three animation-input flows:
//
//   .addMove    — Start Time · Duration
//   .addRotate  — Start Time · Duration · Degrees · Axis (X / Y / Z)
//   .editRotate — Degrees · Axis (X / Y / Z)
//
// Presented as a sheet that slides up from the bottom, with a blurred
// dimming view behind it.  Dismisses on tap-outside or Cancel.
// ─────────────────────────────────────────────────────────────────────────────

enum AnimationCardMode {
    case addMove
    case addRotate
    case editRotate(currentDegrees: Float, currentAxis: RotationAxis)
}

final class AnimationInputCard: UIViewController {

    // ── Callbacks ─────────────────────────────────────────────────────────────

    /// Called when the user confirms.
    /// - addMove/addRotate:  (startTime, duration, degrees, axis)
    /// - editRotate:         (0, 0, degrees, axis) — caller ignores startTime/duration
    var onConfirm: ((Float, Float, Float, RotationAxis) -> Void)?

    // ── State ─────────────────────────────────────────────────────────────────

    private let mode: AnimationCardMode
    private var selectedAxis: RotationAxis = .y

    // ── UI ────────────────────────────────────────────────────────────────────

    private let dimView     = UIView()
    private let card        = UIView()
    private var cardBottom: NSLayoutConstraint!

    private var startField:    LabelledField?
    private var durationField: LabelledField?
    private var degreesField:  LabelledField?
    private var axisPicker:    AxisSegmentedControl?

    // ── Init ──────────────────────────────────────────────────────────────────

    init(mode: AnimationCardMode) {
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle   = .crossDissolve
        if case .editRotate(_, let axis) = mode { selectedAxis = axis }
    }
    required init?(coder: NSCoder) { fatalError() }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    override func viewDidLoad() {
        super.viewDidLoad()
        buildDimView()
        buildCard()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
        // Activate the first relevant text field
        (startField ?? degreesField)?.textField.becomeFirstResponder()
    }

    // ── Dim view ──────────────────────────────────────────────────────────────

    private func buildDimView() {
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0)
        dimView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismiss_)))
    }

    // ── Card ──────────────────────────────────────────────────────────────────

    private func buildCard() {
        card.backgroundColor    = UIColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1)
        card.layer.cornerRadius = 24
        card.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        card.layer.shadowColor   = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.4
        card.layer.shadowRadius  = 20
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)

        cardBottom = card.bottomAnchor.constraint(equalTo: view.bottomAnchor,
                                                   constant: 600) // starts off-screen
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cardBottom,
        ])

        // ── Handle bar ───────────────────────────────────────────────────────
        let handle = UIView()
        handle.backgroundColor    = UIColor.white.withAlphaComponent(0.2)
        handle.layer.cornerRadius = 2.5
        handle.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(handle)
        NSLayoutConstraint.activate([
            handle.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            handle.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            handle.widthAnchor.constraint(equalToConstant: 40),
            handle.heightAnchor.constraint(equalToConstant: 5),
        ])

        // ── Title + icon ─────────────────────────────────────────────────────
        let (titleStr, iconName, tintCol) = cardMeta()

        let icon = UIImageView(image: UIImage(systemName: iconName)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)))
        icon.tintColor = tintCol
        icon.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text      = titleStr
        titleLabel.font      = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let titleRow = UIStackView(arrangedSubviews: [icon, titleLabel])
        titleRow.axis    = .horizontal
        titleRow.spacing = 10
        titleRow.alignment = .center
        titleRow.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleRow)
        NSLayoutConstraint.activate([
            titleRow.topAnchor.constraint(equalTo: handle.bottomAnchor, constant: 20),
            titleRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
        ])

        // ── Content stack ────────────────────────────────────────────────────
        let stack = UIStackView()
        stack.axis    = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: titleRow.bottomAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: card.safeAreaLayoutGuide.bottomAnchor, constant: -24),
        ])

        // ── Fields by mode ───────────────────────────────────────────────────
        switch mode {

        case .addMove:
            let sf = LabelledField(
                label: "Start Time",
                hint:  "seconds — when this move begins",
                icon:  "clock",
                value: "0.0",
                keyboard: .decimalPad)
            let df = LabelledField(
                label: "Duration",
                hint:  "seconds — how long the move lasts",
                icon:  "timer",
                value: "1.0",
                keyboard: .decimalPad)
            startField    = sf
            durationField = df
            stack.addArrangedSubview(sf)
            stack.addArrangedSubview(df)

        case .addRotate:
            let sf = LabelledField(
                label: "Start Time",
                hint:  "seconds — when this rotation begins",
                icon:  "clock",
                value: "0.0",
                keyboard: .decimalPad)
            let df = LabelledField(
                label: "Duration",
                hint:  "seconds — how long the rotation lasts",
                icon:  "timer",
                value: "1.0",
                keyboard: .decimalPad)
            let rf = LabelledField(
                label: "Degrees",
                hint:  "total rotation · positive = CCW · supports >360°",
                icon:  "arrow.clockwise.circle",
                value: "90",
                keyboard: .numbersAndPunctuation)
            startField    = sf
            durationField = df
            degreesField  = rf
            stack.addArrangedSubview(sf)
            stack.addArrangedSubview(df)
            stack.addArrangedSubview(rf)
            let ap = AxisSegmentedControl(selected: selectedAxis) { [weak self] ax in
                self?.selectedAxis = ax
            }
            axisPicker = ap
            stack.addArrangedSubview(ap)

        case .editRotate(let deg, let axis):
            let rf = LabelledField(
                label: "Degrees",
                hint:  "total rotation · positive = CCW · supports >360°",
                icon:  "arrow.clockwise.circle",
                value: String(format: "%.0f", deg),
                keyboard: .numbersAndPunctuation)
            degreesField  = rf
            selectedAxis  = axis
            stack.addArrangedSubview(rf)
            let ap = AxisSegmentedControl(selected: axis) { [weak self] ax in
                self?.selectedAxis = ax
            }
            axisPicker = ap
            stack.addArrangedSubview(ap)
        }

        // ── Confirm button ───────────────────────────────────────────────────
        let confirmBtn = buildConfirmButton()
        stack.addArrangedSubview(confirmBtn)

        // ── Keyboard avoidance ───────────────────────────────────────────────
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    private func cardMeta() -> (title: String, icon: String, tint: UIColor) {
        switch mode {
        case .addMove:
            return ("Add Move", "arrow.up.right.circle.fill",
                    UIColor(red: 0.2, green: 0.7, blue: 1.0, alpha: 1))
        case .addRotate:
            return ("Add Rotation", "rotate.3d.fill",
                    UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 1))
        case .editRotate:
            return ("Edit Rotation", "rotate.3d",
                    UIColor(red: 0.6, green: 0.4, blue: 1.0, alpha: 1))
        }
    }

    private func buildConfirmButton() -> UIButton {
        let btn = UIButton(type: .system)
        let label: String
        switch mode {
        case .addMove:    label = "Add Move to Timeline"
        case .addRotate:  label = "Add Rotation to Timeline"
        case .editRotate: label = "Apply"
        }
        btn.setTitle(label, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = UIColor(red: 0.25, green: 0.25, blue: 0.55, alpha: 1)
        btn.layer.cornerRadius = 14
        btn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        btn.addAction(UIAction { [weak self] _ in self?.confirm() }, for: .touchUpInside)
        return btn
    }

    // ── Confirm ───────────────────────────────────────────────────────────────

    private func confirm() {
        view.endEditing(true)

        let startTime = Float(startField?.textField.text ?? "0") ?? 0
        let duration  = Float(durationField?.textField.text ?? "1") ?? 1
        let degrees   = Float(degreesField?.textField.text ?? "90") ?? 90
        let axis      = selectedAxis

        guard duration > 0 else {
            shake(durationField?.textField)
            return
        }

        animateOut {
            self.dismiss(animated: false) {
                self.onConfirm?(startTime, duration, degrees, axis)
            }
        }
    }

    // ── Dismiss ───────────────────────────────────────────────────────────────

    @objc private func dismiss_() {
        animateOut { self.dismiss(animated: false) }
    }

    // ── Animations ────────────────────────────────────────────────────────────

    private func animateIn() {
        view.layoutIfNeeded()
        cardBottom.constant = 0
        UIView.animate(withDuration: 0.38, delay: 0,
                       usingSpringWithDamping: 0.82,
                       initialSpringVelocity: 0.5) {
            self.dimView.backgroundColor = UIColor.black.withAlphaComponent(0.55)
            self.view.layoutIfNeeded()
        }
    }

    private func animateOut(_ completion: @escaping () -> Void) {
        cardBottom.constant = 600
        UIView.animate(withDuration: 0.28, animations: {
            self.dimView.backgroundColor = .clear
            self.view.layoutIfNeeded()
        }, completion: { _ in completion() })
    }

    // ── Keyboard avoidance ────────────────────────────────────────────────────

    @objc private func keyboardWillShow(_ n: Notification) {
        guard let info = n.userInfo,
              let frame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let dur   = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue
        else { return }
        cardBottom.constant = -frame.height + view.safeAreaInsets.bottom
        UIView.animate(withDuration: dur) { self.view.layoutIfNeeded() }
    }

    @objc private func keyboardWillHide(_ n: Notification) {
        guard let dur = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue
        else { return }
        cardBottom.constant = 0
        UIView.animate(withDuration: dur) { self.view.layoutIfNeeded() }
    }

    // ── Shake feedback ────────────────────────────────────────────────────────

    private func shake(_ v: UIView?) {
        guard let v else { return }
        let anim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        anim.values   = [-8, 8, -6, 6, -3, 3, 0]
        anim.duration = 0.35
        v.layer.add(anim, forKey: "shake")
        v.layer.borderColor = UIColor.systemRed.cgColor
        v.layer.borderWidth = 1.5
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            v.layer.borderWidth = 0
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - LabelledField  (icon + label + hint + text field in one block)
// ─────────────────────────────────────────────────────────────────────────────

final class LabelledField: UIView {

    let textField = UITextField()

    init(label: String, hint: String, icon: String, value: String, keyboard: UIKeyboardType) {
        super.init(frame: .zero)

        // Icon
        let iconView = UIImageView(image: UIImage(systemName: icon)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)))
        iconView.tintColor = UIColor.white.withAlphaComponent(0.5)
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // Label
        let lbl = UILabel()
        lbl.text      = label.uppercased()
        lbl.font      = .systemFont(ofSize: 11, weight: .semibold)
        lbl.textColor = UIColor.white.withAlphaComponent(0.5)
        lbl.translatesAutoresizingMaskIntoConstraints = false

        // Header row
        let header = UIStackView(arrangedSubviews: [iconView, lbl])
        header.axis    = .horizontal
        header.spacing = 6
        header.alignment = .center
        header.translatesAutoresizingMaskIntoConstraints = false

        // Text field
        textField.text            = value
        textField.keyboardType    = keyboard
        textField.font            = .systemFont(ofSize: 22, weight: .semibold)
        textField.textColor       = .white
        textField.tintColor       = UIColor(red: 0.4, green: 0.6, blue: 1, alpha: 1)
        textField.backgroundColor = .clear
        textField.borderStyle     = .none
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.returnKeyType   = .done

        // Hint label
        let hintLbl = UILabel()
        hintLbl.text      = hint
        hintLbl.font      = .systemFont(ofSize: 11, weight: .regular)
        hintLbl.textColor = UIColor.white.withAlphaComponent(0.3)
        hintLbl.numberOfLines = 0
        hintLbl.translatesAutoresizingMaskIntoConstraints = false

        // Separator
        let sep = UIView()
        sep.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.heightAnchor.constraint(equalToConstant: 1).isActive = true

        // Main stack
        let stack = UIStackView(arrangedSubviews: [header, textField, hintLbl, sep])
        stack.axis    = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { fatalError() }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - AxisSegmentedControl
// ─────────────────────────────────────────────────────────────────────────────

final class AxisSegmentedControl: UIView {

    private let onChange: (RotationAxis) -> Void
    private var buttons: [UIButton] = []
    private var selected: RotationAxis

    private let axisColors: [RotationAxis: UIColor] = [
        .x: UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1),   // red
        .y: UIColor(red: 0.3, green: 0.9, blue: 0.3, alpha: 1),   // green
        .z: UIColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1),   // blue
    ]

    init(selected: RotationAxis, onChange: @escaping (RotationAxis) -> Void) {
        self.selected = selected
        self.onChange = onChange
        super.init(frame: .zero)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        // Section label
        let lbl = UILabel()
        lbl.text      = "ROTATION AXIS"
        lbl.font      = .systemFont(ofSize: 11, weight: .semibold)
        lbl.textColor = UIColor.white.withAlphaComponent(0.5)
        lbl.translatesAutoresizingMaskIntoConstraints = false

        // Button row
        let buttonRow = UIStackView()
        buttonRow.axis         = .horizontal
        buttonRow.spacing      = 10
        buttonRow.distribution = .fillEqually
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        let axisLabels: [(RotationAxis, String)] = [
            (.x, "X  Pitch"),
            (.y, "Y  Yaw"),
            (.z, "Z  Roll"),
        ]

        for (axis, label) in axisLabels {
            let btn = UIButton(type: .system)
            btn.setTitle(label, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
            btn.layer.cornerRadius = 10
            btn.heightAnchor.constraint(equalToConstant: 44).isActive = true
            btn.tag = axisTag(axis)
            btn.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                self.selected = axis
                self.updateAppearance()
                self.onChange(axis)
            }, for: .touchUpInside)
            buttonRow.addArrangedSubview(btn)
            buttons.append(btn)
        }

        let stack = UIStackView(arrangedSubviews: [lbl, buttonRow])
        stack.axis    = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        translatesAutoresizingMaskIntoConstraints = false
        updateAppearance()
    }

    private func axisTag(_ axis: RotationAxis) -> Int {
        switch axis { case .x: return 0; case .y: return 1; case .z: return 2 }
    }

    private func axisForTag(_ tag: Int) -> RotationAxis {
        switch tag { case 0: return .x; case 1: return .y; default: return .z }
    }

    private func updateAppearance() {
        let axes: [RotationAxis] = [.x, .y, .z]
        for (i, btn) in buttons.enumerated() {
            let axis  = axes[i]
            let color = axisColors[axis] ?? .white
            let isSelected = axis == selected
            if isSelected {
                btn.backgroundColor = color.withAlphaComponent(0.25)
                btn.setTitleColor(color, for: .normal)
                btn.layer.borderColor = color.cgColor
                btn.layer.borderWidth = 1.5
            } else {
                btn.backgroundColor = UIColor.white.withAlphaComponent(0.06)
                btn.setTitleColor(UIColor.white.withAlphaComponent(0.45), for: .normal)
                btn.layer.borderColor = UIColor.clear.cgColor
                btn.layer.borderWidth = 0
            }
        }
    }
}