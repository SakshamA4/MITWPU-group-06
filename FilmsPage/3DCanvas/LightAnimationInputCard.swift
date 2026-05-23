import UIKit
import RealityKit

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - LightAnimationInputCard
//
// A polished bottom-sheet modal for adding light animation clips to the
// timeline. Offers quick presets (ON / OFF / Fade In / Fade Out) and a
// custom keyframe section for full control over intensity, color (Kelvin),
// and visibility tracks.
//
// Follows the same design language as AnimationInputCard:
//   • Dark card (rgb 18/18/34), 28 pt corner radius, drag-to-dismiss
//   • Spring slide-up animation, keyboard avoidance
//   • Haptic feedback on preset taps
// ─────────────────────────────────────────────────────────────────────────────

final class LightAnimationInputCard: UIViewController {

    // ── Callbacks ─────────────────────────────────────────────────────────────
    var onConfirm: ((AnimationClip) -> Void)?

    // ── State ─────────────────────────────────────────────────────────────────
    private let entityName: String
    private let currentIntensity: Float
    private let currentKelvin: Float

    // Custom keyframe state
    private var selectedTrackIndex: Int = 0  // 0=Intensity, 1=Color, 2=Visibility
    private var selectedEasingIndex: Int = 3 // 0=Linear, 1=EaseIn, 2=EaseOut, 3=EaseInOut

    // ── UI ────────────────────────────────────────────────────────────────────
    private let dimView  = UIView()
    private let card     = UIView()
    private var cardBottom: NSLayoutConstraint!

    // Preset fade fields (shown when Fade In / Fade Out is tapped)
    private var fadeStartField: UITextField?
    private var fadeDurationField: UITextField?
    private var fadeConfirmButton: UIButton?
    private var fadeSectionStack: UIStackView?
    private var activeFadePreset: FadePreset = .fadeIn
    
    // Instant ON/OFF timing fields (shown when ON / OFF is tapped)
    private var instantStartField: UITextField?
    private var instantSectionStack: UIStackView?
    private var activeVisibilityPreset: Float = 1 // 1 = ON, 0 = OFF

    // Custom keyframe fields
    private var trackSegment: UISegmentedControl!
    private var startField: UITextField!
    private var durationField: UITextField!
    private var fromField: UITextField!
    private var toField: UITextField!
    private var fromLabel: UILabel!
    private var toLabel: UILabel!
    private var easingSegment: UISegmentedControl!

    // Drag-to-dismiss
    private var dragStartCardOriginY: CGFloat = 0
    private var isDismissing = false

    // ── Colors ────────────────────────────────────────────────────────────────
    private let cardBg    = UIColor(red: 18/255, green: 18/255, blue: 34/255, alpha: 1)
    private let accentRed = UIColor(red: 177/255, green: 32/255, blue: 57/255, alpha: 1)
    private let dimAlpha: CGFloat = 0.72

    private enum FadePreset { case fadeIn, fadeOut }

    // ── Init ──────────────────────────────────────────────────────────────────

    init(entityName: String, currentIntensity: Float, currentKelvin: Float) {
        self.entityName = entityName
        self.currentIntensity = currentIntensity
        self.currentKelvin = currentKelvin
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle   = .crossDissolve
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
    }

    // ══════════════════════════════════════════════════════════════════════════
    // MARK: - Dim View
    // ══════════════════════════════════════════════════════════════════════════

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
            UITapGestureRecognizer(target: self, action: #selector(dismissCard))
        )
    }

    // ══════════════════════════════════════════════════════════════════════════
    // MARK: - Card
    // ══════════════════════════════════════════════════════════════════════════

    private func buildCard() {
        card.backgroundColor    = cardBg
        card.layer.cornerRadius = 28
        card.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        card.layer.shadowColor   = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.6
        card.layer.shadowRadius  = 24
        card.layer.borderColor   = UIColor.white.withAlphaComponent(0.07).cgColor
        card.layer.borderWidth   = 1
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)

        cardBottom = card.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 800)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            card.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 420),
            card.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: 0.9),
            cardBottom,
        ])

        // ── Handle bar ───────────────────────────────────────────────────
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

        // ── Title row ────────────────────────────────────────────────────
        let icon = UILabel()
        icon.text = "💡"
        icon.font = .systemFont(ofSize: 22)

        let titleLabel = UILabel()
        titleLabel.text      = "Light Animation"
        titleLabel.font      = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .white

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

        // ── Scroll content ───────────────────────────────────────────────
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        card.addSubview(scrollView)

        let stack = UIStackView()
        stack.axis    = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: titleRow.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: card.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])

        let contentGuide = scrollView.contentLayoutGuide
        let frameGuide = scrollView.frameLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: frameGuide.widthAnchor, constant: -48),
        ])

        // ── Quick Presets ────────────────────────────────────────────────
        let presetLabel = makeSectionLabel("QUICK PRESETS")
        stack.addArrangedSubview(presetLabel)

        let presetGrid = buildPresetGrid()
        stack.addArrangedSubview(presetGrid)
        
        // ── Instant section (hidden by default, shown on ON/OFF tap) ─────
        let instantStack = buildInstantSection()
        instantSectionStack = instantStack
        instantStack.isHidden = true
        stack.addArrangedSubview(instantStack)

        // ── Fade section (hidden by default, shown on Fade In/Out tap) ──
        let fadeStack = buildFadeSection()
        fadeSectionStack = fadeStack
        fadeStack.isHidden = true
        stack.addArrangedSubview(fadeStack)

        // ── Separator ────────────────────────────────────────────────────
        let sep = UIView()
        sep.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.heightAnchor.constraint(equalToConstant: 1).isActive = true
        stack.addArrangedSubview(sep)

        // ── Custom Keyframe section ──────────────────────────────────────
        let customLabel = makeSectionLabel("CUSTOM KEYFRAME")
        stack.addArrangedSubview(customLabel)

        let customSection = buildCustomSection()
        stack.addArrangedSubview(customSection)

        // ── Confirm button ───────────────────────────────────────────────
        let confirmBtn = buildConfirmButton(title: "Add Keyframe to Timeline")
        confirmBtn.addAction(UIAction { [weak self] _ in self?.confirmCustom() }, for: .touchUpInside)
        stack.addArrangedSubview(confirmBtn)

        // ── Keyboard avoidance ───────────────────────────────────────────
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    // ══════════════════════════════════════════════════════════════════════════
    // MARK: - Preset Grid
    // ══════════════════════════════════════════════════════════════════════════

    private func buildPresetGrid() -> UIView {
        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.spacing = 12
        topRow.distribution = .fillEqually

        let bottomRow = UIStackView()
        bottomRow.axis = .horizontal
        bottomRow.spacing = 12
        bottomRow.distribution = .fillEqually

        // Instant ON
        let onBtn = makePresetButton(
            title: "ON", subtitle: "Instant",
            icon: "bolt.fill",
            tintColor: UIColor(red: 0.3, green: 0.85, blue: 0.4, alpha: 1)
        ) { [weak self] in self?.handleInstantOn() }
        topRow.addArrangedSubview(onBtn)

        // Instant OFF
        let offBtn = makePresetButton(
            title: "OFF", subtitle: "Instant",
            icon: "bolt.slash.fill",
            tintColor: UIColor(red: 1.0, green: 0.38, blue: 0.38, alpha: 1)
        ) { [weak self] in self?.handleInstantOff() }
        topRow.addArrangedSubview(offBtn)

        // Fade In
        let fadeInBtn = makePresetButton(
            title: "Fade In", subtitle: "Animated",
            icon: "sunrise.fill",
            tintColor: UIColor(red: 1.0, green: 0.76, blue: 0.28, alpha: 1)
        ) { [weak self] in self?.handleFadeIn() }
        bottomRow.addArrangedSubview(fadeInBtn)

        // Fade Out
        let fadeOutBtn = makePresetButton(
            title: "Fade Out", subtitle: "Animated",
            icon: "sunset.fill",
            tintColor: UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1)
        ) { [weak self] in self?.handleFadeOut() }
        bottomRow.addArrangedSubview(fadeOutBtn)

        let grid = UIStackView(arrangedSubviews: [topRow, bottomRow])
        grid.axis = .vertical
        grid.spacing = 12
        return grid
    }

    private func makePresetButton(title: String, subtitle: String, icon: String,
                                   tintColor: UIColor, action: @escaping () -> Void) -> UIButton {
        let btn = UIButton(type: .system)
        btn.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        btn.layer.cornerRadius = 14
        btn.layer.borderWidth = 1
        btn.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        btn.heightAnchor.constraint(equalToConstant: 70).isActive = true

        let iconView = UIImageView(image: UIImage(systemName: icon)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)))
        iconView.tintColor = tintColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLbl.textColor = .white

        let subtitleLbl = UILabel()
        subtitleLbl.text = subtitle
        subtitleLbl.font = .systemFont(ofSize: 11, weight: .regular)
        subtitleLbl.textColor = UIColor.white.withAlphaComponent(0.4)

        let textStack = UIStackView(arrangedSubviews: [titleLbl, subtitleLbl])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.isUserInteractionEnabled = false

        let contentStack = UIStackView(arrangedSubviews: [iconView, textStack])
        contentStack.axis = .horizontal
        contentStack.spacing = 10
        contentStack.alignment = .center
        contentStack.isUserInteractionEnabled = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        btn.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.centerXAnchor.constraint(equalTo: btn.centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
        ])

        btn.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return btn
    }

    // ══════════════════════════════════════════════════════════════════════════
    // MARK: - Fade Section (Start Time + Duration for Fade presets)
    // ══════════════════════════════════════════════════════════════════════════

    private func buildFadeSection() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12

        let fadeTitle = UILabel()
        fadeTitle.text = "FADE SETTINGS"
        fadeTitle.font = .systemFont(ofSize: 11, weight: .medium)
        fadeTitle.textColor = UIColor.white.withAlphaComponent(0.45)
        stack.addArrangedSubview(fadeTitle)

        let startTF = makeTextField(placeholder: "0.0", label: "Start Time (sec)")
        fadeStartField = startTF.textField
        stack.addArrangedSubview(startTF.container)

        let durTF = makeTextField(placeholder: "1.0", label: "Duration (sec)")
        fadeDurationField = durTF.textField
        stack.addArrangedSubview(durTF.container)

        let btn = buildConfirmButton(title: "Add Fade to Timeline")
        btn.addAction(UIAction { [weak self] _ in self?.confirmFade() }, for: .touchUpInside)
        fadeConfirmButton = btn
        stack.addArrangedSubview(btn)

        return stack
    }
    
    private func buildInstantSection() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12

        let title = UILabel()
        title.text = "INSTANT TOGGLE SETTINGS"
        title.font = .systemFont(ofSize: 11, weight: .medium)
        title.textColor = UIColor.white.withAlphaComponent(0.45)
        stack.addArrangedSubview(title)

        let startTF = makeTextField(placeholder: "0.0", label: "Start Time (sec)")
        instantStartField = startTF.textField
        stack.addArrangedSubview(startTF.container)

        let hint = UILabel()
        hint.text = "Visibility switches ON/OFF instantly at the start time."
        hint.font = .systemFont(ofSize: 12, weight: .regular)
        hint.textColor = UIColor.white.withAlphaComponent(0.55)
        hint.numberOfLines = 0
        stack.addArrangedSubview(hint)

        let button = buildConfirmButton(title: "Add Toggle to Timeline")
        button.addAction(UIAction { [weak self] _ in self?.confirmInstantToggle() }, for: .touchUpInside)
        stack.addArrangedSubview(button)

        return stack
    }

    // ══════════════════════════════════════════════════════════════════════════
    // MARK: - Custom Keyframe Section
    // ══════════════════════════════════════════════════════════════════════════

    private func buildCustomSection() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14

        // Track picker
        let trackLabel = makeSectionLabel("TRACK")
        stack.addArrangedSubview(trackLabel)

        trackSegment = UISegmentedControl(items: ["Intensity", "Color", "Visibility"])
        trackSegment.selectedSegmentIndex = 0
        trackSegment.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        trackSegment.selectedSegmentTintColor = accentRed
        trackSegment.setTitleTextAttributes([
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
        ], for: .selected)
        trackSegment.setTitleTextAttributes([
            .foregroundColor: UIColor.white.withAlphaComponent(0.5),
            .font: UIFont.systemFont(ofSize: 13, weight: .medium)
        ], for: .normal)
        trackSegment.addTarget(self, action: #selector(trackChanged), for: .valueChanged)
        stack.addArrangedSubview(trackSegment)

        // Start time
        let startTF = makeTextField(placeholder: "0.0", label: "Start Time (sec)")
        startField = startTF.textField
        stack.addArrangedSubview(startTF.container)

        // Duration
        let durTF = makeTextField(placeholder: "1.0", label: "Duration (sec)")
        durationField = durTF.textField
        stack.addArrangedSubview(durTF.container)

        // From value
        fromLabel = UILabel()
        fromLabel.text = "FROM (LUMENS)"
        fromLabel.font = .systemFont(ofSize: 11, weight: .medium)
        fromLabel.textColor = UIColor.white.withAlphaComponent(0.45)
        stack.addArrangedSubview(fromLabel)

        let fromTF = makeTextField(
            placeholder: String(format: "%.0f", currentIntensity),
            label: ""
        )
        fromField = fromTF.textField
        fromField.text = String(format: "%.0f", currentIntensity)
        stack.addArrangedSubview(fromTF.container)

        // To value
        toLabel = UILabel()
        toLabel.text = "TO (LUMENS)"
        toLabel.font = .systemFont(ofSize: 11, weight: .medium)
        toLabel.textColor = UIColor.white.withAlphaComponent(0.45)
        stack.addArrangedSubview(toLabel)

        let toTF = makeTextField(
            placeholder: String(format: "%.0f", currentIntensity),
            label: ""
        )
        toField = toTF.textField
        toField.text = String(format: "%.0f", currentIntensity)
        stack.addArrangedSubview(toTF.container)

        // Easing picker
        let easingLabel = makeSectionLabel("EASING")
        stack.addArrangedSubview(easingLabel)

        easingSegment = UISegmentedControl(items: ["Linear", "Ease In", "Ease Out", "Ease In-Out"])
        easingSegment.selectedSegmentIndex = 3
        easingSegment.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        easingSegment.selectedSegmentTintColor = accentRed
        easingSegment.setTitleTextAttributes([
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold)
        ], for: .selected)
        easingSegment.setTitleTextAttributes([
            .foregroundColor: UIColor.white.withAlphaComponent(0.5),
            .font: UIFont.systemFont(ofSize: 12, weight: .medium)
        ], for: .normal)
        stack.addArrangedSubview(easingSegment)

        return stack
    }

    @objc private func trackChanged() {
        selectedTrackIndex = trackSegment.selectedSegmentIndex
        switch selectedTrackIndex {
        case 0: // Intensity
            fromLabel.text = "FROM (LUMENS)"
            toLabel.text   = "TO (LUMENS)"
            fromField.text = String(format: "%.0f", currentIntensity)
            toField.text   = String(format: "%.0f", currentIntensity)
            fromField.placeholder = "e.g. 1000"
            toField.placeholder   = "e.g. 500000"
        case 1: // Color (Kelvin)
            fromLabel.text = "FROM (KELVIN)"
            toLabel.text   = "TO (KELVIN)"
            fromField.text = String(format: "%.0f", currentKelvin)
            toField.text   = String(format: "%.0f", currentKelvin)
            fromField.placeholder = "e.g. 2700"
            toField.placeholder   = "e.g. 7000"
        case 2: // Visibility
            fromLabel.text = "FROM (0=OFF, 1=ON)"
            toLabel.text   = "TO (0=OFF, 1=ON)"
            fromField.text = "1"
            toField.text   = "0"
            fromField.placeholder = "0 or 1"
            toField.placeholder   = "0 or 1"
        default: break
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // MARK: - Preset Actions
    // ══════════════════════════════════════════════════════════════════════════

    private func handleInstantOn() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        activeVisibilityPreset = 1
        instantStartField?.text = "0.0"
        UIView.animate(withDuration: 0.25) {
            self.fadeSectionStack?.isHidden = true
            self.instantSectionStack?.isHidden = false
        }
    }

    private func handleInstantOff() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        activeVisibilityPreset = 0
        instantStartField?.text = "0.0"
        UIView.animate(withDuration: 0.25) {
            self.fadeSectionStack?.isHidden = true
            self.instantSectionStack?.isHidden = false
        }
    }
    
    private func confirmInstantToggle() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        view.endEditing(true)

        let startTime = Float(instantStartField?.text ?? "0") ?? 0
        let toValue = activeVisibilityPreset
        let fromValue: Float = toValue >= 0.5 ? 0 : 1

        let clip = AnimationClip(
            entityName: entityName,
            type: .light,
            track: .visibility,
            easing: .linear,
            startTime: startTime,
            duration: 0.01,
            fromValue: SIMD3<Float>(fromValue, 0, 0),
            toValue:   SIMD3<Float>(toValue, 0, 0)
        )

        animateOut {
            self.dismiss(animated: false) {
                self.onConfirm?(clip)
            }
        }
    }

    private func handleFadeIn() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        activeFadePreset = .fadeIn
        fadeStartField?.text = "0.0"
        fadeDurationField?.text = "1.0"
        UIView.animate(withDuration: 0.3) {
            self.instantSectionStack?.isHidden = true
            self.fadeSectionStack?.isHidden = false
        }
    }

    private func handleFadeOut() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        activeFadePreset = .fadeOut
        fadeStartField?.text = "0.0"
        fadeDurationField?.text = "1.0"
        UIView.animate(withDuration: 0.3) {
            self.instantSectionStack?.isHidden = true
            self.fadeSectionStack?.isHidden = false
        }
    }

    private func confirmFade() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        view.endEditing(true)

        let startTime = Float(fadeStartField?.text ?? "0") ?? 0
        let duration  = Float(fadeDurationField?.text ?? "1") ?? 1
        guard duration > 0 else { return }

        let clip: AnimationClip
        switch activeFadePreset {
        case .fadeIn:
            clip = AnimationClip(
                entityName: entityName,
                type: .light,
                track: .intensity,
                easing: .easeInOut,
                startTime: startTime,
                duration: duration,
                fromValue: SIMD3<Float>(0, 0, 0),
                toValue:   SIMD3<Float>(currentIntensity, 0, 0)
            )
        case .fadeOut:
            clip = AnimationClip(
                entityName: entityName,
                type: .light,
                track: .intensity,
                easing: .easeInOut,
                startTime: startTime,
                duration: duration,
                fromValue: SIMD3<Float>(currentIntensity, 0, 0),
                toValue:   SIMD3<Float>(0, 0, 0)
            )
        }

        animateOut {
            self.dismiss(animated: false) {
                self.onConfirm?(clip)
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // MARK: - Custom Keyframe Confirm
    // ══════════════════════════════════════════════════════════════════════════

    private func confirmCustom() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        view.endEditing(true)

        let startTime = Float(startField.text ?? "0") ?? 0
        let duration  = Float(durationField.text ?? "1") ?? 1
        let fromVal   = Float(fromField.text ?? "0") ?? 0
        let toVal     = Float(toField.text ?? "0") ?? 0
        guard duration > 0 else { return }

        let track: AnimationTrack
        switch selectedTrackIndex {
        case 0:  track = .intensity
        case 1:  track = .color
        case 2:  track = .visibility
        default: track = .intensity
        }

        let easing: EasingType
        switch easingSegment.selectedSegmentIndex {
        case 0:  easing = .linear
        case 1:  easing = .easeIn
        case 2:  easing = .easeOut
        case 3:  easing = .easeInOut
        default: easing = .easeInOut
        }

        let clip = AnimationClip(
            entityName: entityName,
            type: .light,
            track: track,
            easing: easing,
            startTime: startTime,
            duration: duration,
            fromValue: SIMD3<Float>(fromVal, 0, 0),
            toValue:   SIMD3<Float>(toVal, 0, 0)
        )

        animateOut {
            self.dismiss(animated: false) {
                self.onConfirm?(clip)
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // MARK: - Helpers
    // ══════════════════════════════════════════════════════════════════════════

    private func makeSectionLabel(_ text: String) -> UILabel {
        let lbl = UILabel()
        lbl.text = text
        lbl.font = .systemFont(ofSize: 11, weight: .medium)
        lbl.textColor = UIColor.white.withAlphaComponent(0.45)
        return lbl
    }

    private func makeTextField(placeholder: String, label: String) -> (container: UIView, textField: UITextField) {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        if !label.isEmpty {
            let lbl = UILabel()
            lbl.text = label.uppercased()
            lbl.font = .systemFont(ofSize: 11, weight: .medium)
            lbl.textColor = UIColor.white.withAlphaComponent(0.45)
            lbl.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(lbl)
            NSLayoutConstraint.activate([
                lbl.topAnchor.constraint(equalTo: container.topAnchor),
                lbl.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            ])
        }

        let tf = UITextField()
        tf.text            = ""
        tf.placeholder     = placeholder
        tf.keyboardType    = .decimalPad
        tf.font            = .monospacedDigitSystemFont(ofSize: 22, weight: .semibold)
        tf.textColor       = .white
        tf.tintColor       = accentRed
        tf.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        tf.layer.cornerRadius = 10
        tf.borderStyle     = .none
        tf.leftView        = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        tf.leftViewMode    = .always
        tf.translatesAutoresizingMaskIntoConstraints = false

        // Done button on keyboard
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard)),
        ]
        tf.inputAccessoryView = toolbar

        container.addSubview(tf)
        let topOffset: CGFloat = label.isEmpty ? 0 : 18
        NSLayoutConstraint.activate([
            tf.topAnchor.constraint(equalTo: container.topAnchor, constant: topOffset),
            tf.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tf.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tf.heightAnchor.constraint(equalToConstant: 48),
            tf.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return (container, tf)
    }

    private func buildConfirmButton(title: String) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseForegroundColor = .white
        config.baseBackgroundColor = accentRed
        config.cornerStyle = .large
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            return out
        }
        let btn = UIButton(configuration: config)
        btn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        return btn
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // ══════════════════════════════════════════════════════════════════════════
    // MARK: - Drag-to-Dismiss
    // ══════════════════════════════════════════════════════════════════════════

    private func attachDragToDismiss() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleCardDrag(_:)))
        card.addGestureRecognizer(pan)
    }

    @objc private func handleCardDrag(_ gesture: UIPanGestureRecognizer) {
        guard !isDismissing else { return }
        let translation = gesture.translation(in: view)
        let velocity    = gesture.velocity(in: view)

        switch gesture.state {
        case .began:
            dragStartCardOriginY = cardBottom.constant
            view.endEditing(true)
        case .changed:
            let raw = dragStartCardOriginY + translation.y
            if raw > 0 {
                cardBottom.constant = raw
            } else {
                cardBottom.constant = -sqrt(-raw) * 0.4
            }
            let progress = max(0, min(1, cardBottom.constant / max(card.bounds.height * 0.35, 120)))
            dimView.backgroundColor = UIColor.black.withAlphaComponent(dimAlpha * (1 - progress))
        case .ended, .cancelled:
            let threshold = max(card.bounds.height * 0.35, 120)
            if cardBottom.constant > threshold || velocity.y > 900 {
                performDragDismiss(velocity: velocity.y)
            } else {
                cardBottom.constant = 0
                UIView.animate(withDuration: 0.42, delay: 0,
                               usingSpringWithDamping: 0.75, initialSpringVelocity: 0.3) {
                    self.dimView.backgroundColor = UIColor.black.withAlphaComponent(self.dimAlpha)
                    self.view.layoutIfNeeded()
                }
            }
        default: break
        }
    }

    private func performDragDismiss(velocity: CGFloat) {
        isDismissing = true
        let remaining = max(card.bounds.height - cardBottom.constant, 40)
        let speed = max(velocity / remaining, 1.0)
        cardBottom.constant = card.bounds.height + view.safeAreaInsets.bottom
        UIView.animate(withDuration: 0.32, delay: 0,
                       usingSpringWithDamping: 0.95, initialSpringVelocity: speed) {
            self.dimView.backgroundColor = .clear
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.dismiss(animated: false)
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // MARK: - Animations
    // ══════════════════════════════════════════════════════════════════════════

    private func animateIn() {
        view.layoutIfNeeded()
        cardBottom.constant = 0
        UIView.animate(withDuration: 0.38, delay: 0,
                       usingSpringWithDamping: 0.82, initialSpringVelocity: 0.5) {
            self.dimView.backgroundColor = UIColor.black.withAlphaComponent(self.dimAlpha)
            self.view.layoutIfNeeded()
        }
    }

    private func animateOut(_ completion: @escaping () -> Void) {
        isDismissing = true
        let slideDistance = card.bounds.height + view.safeAreaInsets.bottom
        cardBottom.constant = slideDistance
        UIView.animate(withDuration: 0.28, animations: {
            self.dimView.backgroundColor = .clear
            self.view.layoutIfNeeded()
        }, completion: { _ in completion() })
    }

    @objc private func dismissCard() {
        guard !isDismissing else { return }
        isDismissing = true
        view.endEditing(true)
        DispatchQueue.main.async { [weak self] in
            self?.animateOut { self?.dismiss(animated: false) }
        }
    }

    // ── Keyboard avoidance ────────────────────────────────────────────────────

    @objc private func keyboardWillShow(_ n: Notification) {
        guard !isDismissing else { return }
        guard let frame = (n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let dur   = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue
        else { return }
        cardBottom.constant = -frame.height + view.safeAreaInsets.bottom
        UIView.animate(withDuration: dur) { self.view.layoutIfNeeded() }
    }

    @objc private func keyboardWillHide(_ n: Notification) {
        guard !isDismissing else { return }
        guard let dur = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue
        else { return }
        cardBottom.constant = 0
        UIView.animate(withDuration: dur) { self.view.layoutIfNeeded() }
    }
}
