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
// dimming view behind it.  Dismisses on tap-outside, Cancel, or drag-down.
//
// FIXES (v2):
//   1. Drag-to-dismiss  — UIPanGestureRecognizer on the handle + card with
//      rubber-banding and a 120 pt velocity/distance threshold (Apple-native feel).
//   2. Glitch-free dismiss — endEditing() fires before animateOut so the
//      keyboard-hide notification doesn't fight the slide-out animation.
//      animateOut now measures card height dynamically instead of a hardcoded 600.
//   3. Single keyboard  — only the FIRST visible text field becomes first responder.
//      All numeric fields use .decimalPad with a "Done" input-accessory toolbar so
//      the user can close the keyboard without tapping outside. Switching between
//      fields does not trigger a keyboard hide-then-show bounce.
// ─────────────────────────────────────────────────────────────────────────────

enum AnimationCardMode {
    case addMove
    case addRotate
    /// Degrees + axis only — no timing fields
    case editRotate(currentDegrees: Float, currentAxis: RotationAxis)
    /// Full rotation clip editor: timing + degrees + axis in one card
    case editRotateFull(currentStart: Float, currentDuration: Float,
                        currentDegrees: Float, currentAxis: RotationAxis)
    /// Edit timing for a move path clip
    case editMoveTiming(currentStart: Float, currentDuration: Float)
    /// Add a camera shot (movement or static) — shows shot name, start time, duration
    case addShot(shotName: String, defaultStart: Float, isZoom: Bool)
    /// Edit a camera shot (timing only) — same layout as addShot
    case editShot(title: String, currentStart: Float, currentDuration: Float)
}

final class AnimationInputCard: UIViewController {

    // ── Callbacks ─────────────────────────────────────────────────────────────

    /// Called when the user confirms.
    /// - addMove/addRotate:  (startTime, duration, degrees, axis)
    /// - editRotate:         (0, 0, degrees, axis) — caller ignores startTime/duration
    /// - addShot:            (startTime, duration, zoomAmount, .y)
    var onConfirm: ((Float, Float, Float, RotationAxis) -> Void)?

    // ── State ─────────────────────────────────────────────────────────────────

    private let mode: AnimationCardMode
    private var selectedAxis: RotationAxis = .y

    // ── UI ────────────────────────────────────────────────────────────────────

    private let dimView  = UIView()
    private let card     = UIView()
    private var cardBottom: NSLayoutConstraint!

    private var startField:    LabelledField?
    private var durationField: LabelledField?
    private var degreesField:  LabelledField?
    private var zoomField:     LabelledField?
    private var axisPicker:    AxisSegmentedControl?

    // ── Drag-to-dismiss state ─────────────────────────────────────────────────

    private var dragStartCardOriginY: CGFloat = 0
    private var isDismissing = false

    // ── Init ──────────────────────────────────────────────────────────────────

    init(mode: AnimationCardMode) {
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle   = .crossDissolve
        if case .editRotate(_, let axis)           = mode { selectedAxis = axis }
        if case .editRotateFull(_, _, _, let axis) = mode { selectedAxis = axis }
    }
    required init?(coder: NSCoder) { fatalError() }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    override func viewDidLoad() {
        super.viewDidLoad()
        buildDimView()
        buildCard()
        attachDragToDismiss()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
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
        dimView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(dismiss_))
        )
    }

    // ── Card ──────────────────────────────────────────────────────────────────

    private func buildCard() {
        card.backgroundColor    = UIColor(red: 18/255, green: 18/255, blue: 34/255, alpha: 1)
        card.layer.cornerRadius = 28
        card.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        card.layer.shadowColor   = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.6
        card.layer.shadowRadius  = 24
        card.layer.borderColor   = UIColor.white.withAlphaComponent(0.07).cgColor
        card.layer.borderWidth   = 1
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)

        // Start fully off-screen — use a safe large value; animateOut uses
        // the real measured height so no glitch on dismiss.
        cardBottom = card.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 800)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cardBottom,
        ])

        // ── Handle bar ───────────────────────────────────────────────────────
        let handle = UIView()
        handle.backgroundColor    = UIColor.white.withAlphaComponent(0.15)
        handle.layer.cornerRadius = 3
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
        titleLabel.font      = UIFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let titleRow = UIStackView(arrangedSubviews: [icon, titleLabel])
        titleRow.axis      = .horizontal
        titleRow.spacing   = 10
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
            degreesField = rf
            selectedAxis = axis
            stack.addArrangedSubview(rf)
            let ap = AxisSegmentedControl(selected: axis) { [weak self] ax in
                self?.selectedAxis = ax
            }
            axisPicker = ap
            stack.addArrangedSubview(ap)

        case .editRotateFull(let start, let dur, let deg, let axis):
            let sf = LabelledField(
                label: "Start Time",
                hint:  "seconds — when this rotation begins",
                icon:  "clock",
                value: String(format: "%.2f", start),
                keyboard: .decimalPad)
            let df = LabelledField(
                label: "Duration",
                hint:  "seconds — how long the rotation lasts",
                icon:  "timer",
                value: String(format: "%.2f", dur),
                keyboard: .decimalPad)
            let rf = LabelledField(
                label: "Degrees",
                hint:  "total rotation · positive = CCW · supports >360°",
                icon:  "arrow.clockwise.circle",
                value: String(format: "%.0f", deg),
                keyboard: .numbersAndPunctuation)
            startField    = sf
            durationField = df
            degreesField  = rf
            selectedAxis  = axis
            stack.addArrangedSubview(sf)
            stack.addArrangedSubview(df)
            stack.addArrangedSubview(rf)
            let ap = AxisSegmentedControl(selected: axis) { [weak self] ax in
                self?.selectedAxis = ax
            }
            axisPicker = ap
            stack.addArrangedSubview(ap)

        case .editMoveTiming(let start, let dur):
            let sf = LabelledField(
                label: "Start Time",
                hint:  "seconds — when this move begins",
                icon:  "clock",
                value: String(format: "%.2f", start),
                keyboard: .decimalPad)
            let df = LabelledField(
                label: "Duration",
                hint:  "seconds — how long the move lasts",
                icon:  "timer",
                value: String(format: "%.2f", dur),
                keyboard: .decimalPad)
            startField    = sf
            durationField = df
            stack.addArrangedSubview(sf)
            stack.addArrangedSubview(df)

        case .addShot(let shotName, let defaultStart, let isZoom):
            let sf = LabelledField(
                label: "Start Time",
                hint:  "seconds — when this shot begins on the timeline",
                icon:  "clock",
                value: String(format: "%.1f", defaultStart),
                keyboard: .decimalPad)
            let df = LabelledField(
                label: "Duration",
                hint:  "seconds — how long this shot lasts",
                icon:  "timer",
                value: "3.0",
                keyboard: .decimalPad)
            startField    = sf
            durationField = df
            stack.addArrangedSubview(sf)
            stack.addArrangedSubview(df)
            
            if isZoom {
                // Zoom In  → target FOV lower  than current (e.g. 30° = telephoto)
                // Zoom Out → target FOV higher than current (e.g. 80° = wide angle)
                let isZoomIn = shotName.lowercased().contains("in")
                let defaultTarget = isZoomIn ? "30" : "80"
                let zf = LabelledField(
                    label: "Target FOV",
                    hint:  isZoomIn
                        ? "Field of View in degrees — lower = more zoomed in (e.g. 20–50°)"
                        : "Field of View in degrees — higher = more zoomed out / wider (e.g. 70–90°)",
                    icon:  "magnifyingglass",
                    value: defaultTarget,
                    keyboard: .numberPad)
                zoomField = zf
                stack.addArrangedSubview(zf)
            }

        case .editShot(let title, let start, let duration):
            let sf = LabelledField(
                label: "Start Time",
                hint:  "seconds — when this shot begins on the timeline",
                icon:  "clock",
                value: String(format: "%.2f", start),
                keyboard: .decimalPad)
            let df = LabelledField(
                label: "Duration",
                hint:  "seconds — how long this shot lasts",
                icon:  "timer",
                value: String(format: "%.2f", duration),
                keyboard: .decimalPad)
            startField    = sf
            durationField = df
            stack.addArrangedSubview(sf)
            stack.addArrangedSubview(df)
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

    // ── Drag-to-dismiss ───────────────────────────────────────────────────────

    private func attachDragToDismiss() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleCardDrag(_:)))
        pan.delegate = self
        card.addGestureRecognizer(pan)
    }

    @objc private func handleCardDrag(_ gesture: UIPanGestureRecognizer) {
        guard !isDismissing else { return }

        let translation = gesture.translation(in: view)
        let velocity    = gesture.velocity(in: view)

        switch gesture.state {

        case .began:
            dragStartCardOriginY = cardBottom.constant
            // Dismiss keyboard immediately when a downward drag starts — prevents
            // the keyboard-hide animation from fighting the card slide-out.
            view.endEditing(true)

        case .changed:
            // Only allow dragging downward — rubber-band upward drags
            let raw = dragStartCardOriginY + translation.y
            if raw > 0 {
                // Dragging downward: follow finger 1:1
                cardBottom.constant = raw
            } else {
                // Dragging upward: rubber-band (square-root dampening)
                let overshoot = -raw
                cardBottom.constant = -sqrt(overshoot) * 0.4
            }
            // Fade dim proportional to how far the card has been dragged down
            let progress = max(0, min(1, cardBottom.constant / cardDismissThreshold()))
            dimView.backgroundColor = UIColor.black.withAlphaComponent(0.72 * (1 - progress))

        case .ended, .cancelled:
            let shouldDismiss = cardBottom.constant > cardDismissThreshold()
                             || velocity.y > 900

            if shouldDismiss {
                performDragDismiss(initialVelocity: velocity.y)
            } else {
                // Snap back
                cardBottom.constant = 0
                UIView.animate(
                    withDuration: 0.42,
                    delay: 0,
                    usingSpringWithDamping: 0.75,
                    initialSpringVelocity: 0.3
                ) {
                    self.dimView.backgroundColor = UIColor.black.withAlphaComponent(0.72)
                    self.view.layoutIfNeeded()
                }
            }

        default: break
        }
    }

    /// The distance (in points) the card must travel before we commit to dismiss.
    private func cardDismissThreshold() -> CGFloat {
        return max(card.bounds.height * 0.35, 120)
    }

    private func performDragDismiss(initialVelocity: CGFloat) {
        isDismissing = true
        // Drive remaining distance with the finger's current velocity
        let remaining   = max(card.bounds.height - cardBottom.constant, 40)
        let springSpeed = max(initialVelocity / remaining, 1.0)

        cardBottom.constant = card.bounds.height + view.safeAreaInsets.bottom
        UIView.animate(
            withDuration: 0.32,
            delay: 0,
            usingSpringWithDamping: 0.95,
            initialSpringVelocity: springSpeed
        ) {
            self.dimView.backgroundColor = .clear
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.dismiss(animated: false)
        }
    }

    // ── Card meta ─────────────────────────────────────────────────────────────

    private func cardMeta() -> (title: String, icon: String, tint: UIColor) {
        let appRed   = UIColor(red: 177/255, green: 32/255,  blue: 57/255,  alpha: 1)
        let softBlue = UIColor(red: 64/255,  green: 156/255, blue: 255/255, alpha: 1)
        switch mode {
        case .addMove:
            return ("Add Move", "arrow.up.right.circle.fill", softBlue)
        case .addRotate:
            return ("Add Rotation", "rotate.3d.fill", appRed)
        case .editRotate, .editRotateFull:
            return ("Edit Rotation", "rotate.3d", appRed)
        case .editMoveTiming:
            return ("Edit Move Timing", "clock.arrow.2.circlepath", softBlue)
        case .addShot(let shotName, _, _):
            return (shotName, "video.fill", appRed)
        case .editShot(let title, _, _):
            return (title, "video.fill", appRed)
        }
    }

    private func buildConfirmButton() -> UIButton {
        let label: String
        switch mode {
        case .addMove:         label = "Add Move to Timeline"
        case .addRotate:       label = "Add Rotation to Timeline"
        case .addShot:         label = "Add Shot to Timeline"
        case .editRotate,
             .editRotateFull,
             .editMoveTiming,
             .editShot:        label = "Apply"
        }

        var config = UIButton.Configuration.filled()
        config.title = label
        config.baseForegroundColor = .white
        config.baseBackgroundColor = UIColor(red: 177/255, green: 32/255, blue: 57/255, alpha: 1)
        config.cornerStyle = .large
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            return out
        }
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)

        let btn = UIButton(configuration: config)
        btn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        btn.addAction(UIAction { [weak self] _ in self?.confirm() }, for: .touchUpInside)
        return btn
    }

    // ── Confirm ───────────────────────────────────────────────────────────────

    private func confirm() {
        // FIX 2: dismiss keyboard BEFORE animating out so the keyboard-hide
        // notification doesn't race against the slide-out and cause a glitch.
        view.endEditing(true)

        let startTime = Float(startField?.textField.text ?? "0") ?? 0
        let duration  = Float(durationField?.textField.text ?? "1") ?? 1
        
        var mainValue: Float = 90
        if let degText = degreesField?.textField.text, let d = Float(degText) {
            mainValue = d
        } else if let zoomText = zoomField?.textField.text, let z = Float(zoomText) {
            mainValue = z
        }
        
        let axis      = selectedAxis

        guard duration > 0 else {
            shake(durationField?.textField)
            return
        }

        animateOut {
            self.dismiss(animated: false) {
                self.onConfirm?(startTime, duration, mainValue, axis)
            }
        }
    }

    // ── Tap-outside dismiss ───────────────────────────────────────────────────

    @objc private func dismiss_() {
        guard !isDismissing else { return }
        isDismissing = true
        // FIX 2: end editing first, THEN animate the card out.
        // Without this the keyboard-hide notification fires mid-animation and
        // snaps cardBottom to 0 for one frame, causing the card to flash back.
        view.endEditing(true)
        // Give endEditing one runloop cycle to process, then animate out.
        DispatchQueue.main.async { [weak self] in
            self?.animateOut { self?.dismiss(animated: false) }
        }
    }

    // ── Slide animations ──────────────────────────────────────────────────────

    private func animateIn() {
        view.layoutIfNeeded()
        cardBottom.constant = 0
        UIView.animate(
            withDuration: 0.38,
            delay: 0,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: 0.5
        ) {
            self.dimView.backgroundColor = UIColor.black.withAlphaComponent(0.72)
            self.view.layoutIfNeeded()
        }
    }

    private func animateOut(_ completion: @escaping () -> Void) {
        isDismissing = true
        // FIX 2: use actual card height instead of a hardcoded constant so the
        // slide-out distance is always correct regardless of content or device.
        let slideDistance = card.bounds.height + view.safeAreaInsets.bottom
        cardBottom.constant = slideDistance
        UIView.animate(withDuration: 0.28, animations: {
            self.dimView.backgroundColor = .clear
            self.view.layoutIfNeeded()
        }, completion: { _ in completion() })
    }

    // ── Keyboard avoidance ────────────────────────────────────────────────────

    @objc private func keyboardWillShow(_ n: Notification) {
        // Ignore keyboard events while we are dismissing — avoids the
        // card snapping back up when confirm/dismiss fires endEditing.
        guard !isDismissing else { return }
        guard
            let info  = n.userInfo,
            let frame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
            let dur   = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue
        else { return }
        cardBottom.constant = -frame.height + view.safeAreaInsets.bottom
        UIView.animate(withDuration: dur) { self.view.layoutIfNeeded() }
    }

    @objc private func keyboardWillHide(_ n: Notification) {
        guard !isDismissing else { return }
        guard
            let dur = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue
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

// ── UIGestureRecognizerDelegate — let scrolling and field taps coexist ────────

extension AnimationInputCard: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        // Allow the pan to coexist with scroll views inside the card (if any)
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf other: UIGestureRecognizer
    ) -> Bool {
        return false
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
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)))
        iconView.tintColor = UIColor.white.withAlphaComponent(0.4)
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // Label — SF Pro caption style
        let lbl = UILabel()
        lbl.text      = label.uppercased()
        lbl.font      = UIFont.systemFont(ofSize: 11, weight: .medium)
        lbl.textColor = UIColor.white.withAlphaComponent(0.45)
        lbl.translatesAutoresizingMaskIntoConstraints = false

        // Header row
        let header = UIStackView(arrangedSubviews: [iconView, lbl])
        header.axis      = .horizontal
        header.spacing   = 6
        header.alignment = .center
        header.translatesAutoresizingMaskIntoConstraints = false

        // Text field
        textField.text            = value
        textField.keyboardType    = keyboard
        textField.font            = UIFont.monospacedDigitSystemFont(ofSize: 24, weight: .semibold)
        textField.textColor       = .white
        textField.tintColor       = UIColor(red: 177/255, green: 32/255, blue: 57/255, alpha: 1)
        textField.backgroundColor = .clear
        textField.borderStyle     = .none
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.returnKeyType   = .done

        // Hint label
        let hintLbl = UILabel()
        hintLbl.text          = hint
        hintLbl.font          = UIFont.systemFont(ofSize: 11, weight: .regular)
        hintLbl.textColor     = UIColor.white.withAlphaComponent(0.28)
        hintLbl.numberOfLines = 0
        hintLbl.translatesAutoresizingMaskIntoConstraints = false

        // Separator
        let sep = UIView()
        sep.backgroundColor = UIColor.white.withAlphaComponent(0.09)
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true

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
        .x: UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1),
        .y: UIColor(red: 0.3, green: 0.9, blue: 0.3, alpha: 1),
        .z: UIColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1),
    ]

    init(selected: RotationAxis, onChange: @escaping (RotationAxis) -> Void) {
        self.selected = selected
        self.onChange = onChange
        super.init(frame: .zero)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        let lbl = UILabel()
        lbl.text      = "ROTATION AXIS"
        lbl.font      = UIFont.systemFont(ofSize: 11, weight: .medium)
        lbl.textColor = UIColor.white.withAlphaComponent(0.45)
        lbl.translatesAutoresizingMaskIntoConstraints = false

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
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            btn.layer.cornerRadius = 12
            btn.heightAnchor.constraint(equalToConstant: 46).isActive = true
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
                btn.backgroundColor = UIColor.white.withAlphaComponent(0.05)
                btn.setTitleColor(UIColor.white.withAlphaComponent(0.4), for: .normal)
                btn.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
                btn.layer.borderWidth = 0.5
            }
        }
    }
}
