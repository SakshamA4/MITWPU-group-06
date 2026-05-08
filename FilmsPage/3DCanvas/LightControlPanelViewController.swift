//
//  LightControlPanelViewController.swift
//  FilmsPage
//
//  Real-time light property editor presented as a bottom sheet.
//  Logarithmic intensity slider, Kelvin presets, cone angle enforcement,
//  shadow toggle, and reach slider — all wired to live RealityKit updates.
//

import UIKit
import RealityKit

class LightControlPanelViewController: UIViewController {

    // The entity whose light is being edited — held weakly so we don't
    // prevent the canvas from removing it
    private weak var targetEntity: Entity?
    private var config: LightConfigComponent
    private let onUpdate: (LightConfigComponent) -> Void

    // UI elements
    private let intensitySlider  = UISlider()
    private let intensityLabel   = UILabel()
    private let reachSlider      = UISlider()
    private let reachLabel       = UILabel()
    private let innerAngleSlider = UISlider()
    private let innerAngleLabel  = UILabel()
    private let outerAngleSlider = UISlider()
    private let outerAngleLabel  = UILabel()
    private let shadowToggle     = UISwitch()
    private var kelvinButtons: [UIButton] = []

    // Section containers (for hiding)
    private let coneSection   = UIStackView()
    private let shadowSection = UIStackView()

    // The three Kelvin presets matching real film lighting standards
    private let kelvinPresets: [(label: String, subtitle: String, kelvin: Float)] = [
        ("2700K", "Tungsten",  2700),
        ("5600K", "Daylight",  5600),
        ("7000K", "Cool",      7000)
    ]

    init(entity: Entity, config: LightConfigComponent, onUpdate: @escaping (LightConfigComponent) -> Void) {
        self.targetEntity = entity
        self.config       = config
        self.onUpdate     = onUpdate
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 22/255, alpha: 1)
        buildUI()
        populateFromConfig()
    }

    // MARK: - Logarithmic Intensity Mapping

    /// Slider value (0...1) → lumens via log scale
    /// 10^3 = 1000 at 0, 10^5.699 ≈ 500000 at 1
    private func sliderToLumens(_ value: Float) -> Float {
        pow(10, 3.0 + value * 2.699)
    }

    /// Lumens → slider value (inverse)
    private func lumensToSlider(_ lumens: Float) -> Float {
        (log10(max(lumens, 1)) - 3.0) / 2.699
    }

    // MARK: - Build UI

    private func buildUI() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
        ])

        // ── Header ──────────────────────────────────────────────────────
        let header = buildHeader()
        contentStack.addArrangedSubview(header)

        // ── Intensity ───────────────────────────────────────────────────
        let intensitySection = buildSliderSection(
            title: "INTENSITY",
            slider: intensitySlider,
            valueLabel: intensityLabel,
            minValue: 0, maxValue: 1,
            action: #selector(intensityChanged)
        )
        contentStack.addArrangedSubview(intensitySection)

        // ── Color Temperature ───────────────────────────────────────────
        let kelvinSection = buildKelvinSection()
        contentStack.addArrangedSubview(kelvinSection)

        // ── Cone Angle (hidden for point lights) ────────────────────────
        coneSection.axis = .vertical
        coneSection.spacing = 16

        let innerSection = buildSliderSection(
            title: "INNER ANGLE",
            slider: innerAngleSlider,
            valueLabel: innerAngleLabel,
            minValue: 1, maxValue: 60,
            action: #selector(innerAngleChanged)
        )
        coneSection.addArrangedSubview(innerSection)

        let outerSection = buildSliderSection(
            title: "OUTER ANGLE",
            slider: outerAngleSlider,
            valueLabel: outerAngleLabel,
            minValue: 5, maxValue: 120,
            action: #selector(outerAngleChanged)
        )
        coneSection.addArrangedSubview(outerSection)

        contentStack.addArrangedSubview(coneSection)

        // ── Reach ───────────────────────────────────────────────────────
        let reachSection = buildSliderSection(
            title: "REACH",
            slider: reachSlider,
            valueLabel: reachLabel,
            minValue: 1, maxValue: 15,   // capped at 15m — beyond this shadows corrupt in non-AR
            action: #selector(reachChanged)
        )
        contentStack.addArrangedSubview(reachSection)

        // ── Shadow Toggle (hidden for point lights) ─────────────────────
        shadowSection.axis = .horizontal
        shadowSection.spacing = 12
        shadowSection.alignment = .center

        let shadowLabel = UILabel()
        shadowLabel.text = "Shadows"
        shadowLabel.font = .systemFont(ofSize: 15, weight: .medium)
        shadowLabel.textColor = .white
        shadowSection.addArrangedSubview(shadowLabel)

        let spacer = UIView()
        shadowSection.addArrangedSubview(spacer)

        shadowToggle.onTintColor = UIColor(red: 90/255, green: 130/255, blue: 255/255, alpha: 1)
        shadowToggle.addTarget(self, action: #selector(shadowToggled), for: .valueChanged)
        shadowSection.addArrangedSubview(shadowToggle)

        contentStack.addArrangedSubview(shadowSection)

        // Hide cone and shadow sections for point lights
        coneSection.isHidden   = (config.lightKind == .point)
        shadowSection.isHidden = (config.lightKind == .point)
    }

    // MARK: - Header

    private func buildHeader() -> UIView {
        let container = UIStackView()
        container.axis = .horizontal
        container.alignment = .center

        let icon = UILabel()
        icon.text = "💡"
        icon.font = .systemFont(ofSize: 24)
        container.addArrangedSubview(icon)

        let spacer1 = UIView()
        spacer1.widthAnchor.constraint(equalToConstant: 8).isActive = true
        container.addArrangedSubview(spacer1)

        let titleLabel = UILabel()
        let lightName: String
        switch config.lightKind {
        case .spot:  lightName = "Spotlight"
        case .panel: lightName = "LED Panel"
        case .point: lightName = "Lantern"
        }
        titleLabel.text = lightName
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .white
        container.addArrangedSubview(titleLabel)

        let flexSpacer = UIView()
        flexSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        container.addArrangedSubview(flexSpacer)

        let doneBtn = UIButton(type: .system)
        doneBtn.setTitle("Done", for: .normal)
        doneBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        doneBtn.tintColor = UIColor(red: 90/255, green: 130/255, blue: 255/255, alpha: 1)
        doneBtn.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        container.addArrangedSubview(doneBtn)

        return container
    }

    // MARK: - Slider Section Builder

    private func buildSliderSection(
        title: String,
        slider: UISlider,
        valueLabel: UILabel,
        minValue: Float,
        maxValue: Float,
        action: Selector
    ) -> UIStackView {
        let section = UIStackView()
        section.axis = .vertical
        section.spacing = 8

        let headerRow = UIStackView()
        headerRow.axis = .horizontal

        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = UIColor(white: 0.5, alpha: 1)
        headerRow.addArrangedSubview(label)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerRow.addArrangedSubview(spacer)

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        valueLabel.textColor = .white
        headerRow.addArrangedSubview(valueLabel)

        section.addArrangedSubview(headerRow)

        slider.minimumValue = minValue
        slider.maximumValue = maxValue
        slider.minimumTrackTintColor = UIColor(red: 90/255, green: 130/255, blue: 255/255, alpha: 1)
        slider.maximumTrackTintColor = UIColor(white: 0.2, alpha: 1)
        slider.addTarget(self, action: action, for: .valueChanged)
        section.addArrangedSubview(slider)

        return section
    }

    // MARK: - Kelvin Section

    private func buildKelvinSection() -> UIStackView {
        let section = UIStackView()
        section.axis = .vertical
        section.spacing = 8

        let label = UILabel()
        label.text = "COLOR TEMPERATURE"
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = UIColor(white: 0.5, alpha: 1)
        section.addArrangedSubview(label)

        let buttonRow = UIStackView()
        buttonRow.axis = .horizontal
        buttonRow.distribution = .fillEqually
        buttonRow.spacing = 12

        for preset in kelvinPresets {
            let btn = UIButton(type: .system)
            btn.tag = Int(preset.kelvin)

            let titleStack = UIStackView()
            titleStack.axis = .vertical
            titleStack.alignment = .center
            titleStack.spacing = 2
            titleStack.isUserInteractionEnabled = false

            let mainLabel = UILabel()
            mainLabel.text = preset.label
            mainLabel.font = .systemFont(ofSize: 15, weight: .semibold)
            mainLabel.textColor = .white
            mainLabel.textAlignment = .center

            let subLabel = UILabel()
            subLabel.text = preset.subtitle
            subLabel.font = .systemFont(ofSize: 11, weight: .regular)
            subLabel.textColor = UIColor(white: 0.6, alpha: 1)
            subLabel.textAlignment = .center

            titleStack.addArrangedSubview(mainLabel)
            titleStack.addArrangedSubview(subLabel)

            btn.addSubview(titleStack)
            titleStack.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                titleStack.centerXAnchor.constraint(equalTo: btn.centerXAnchor),
                titleStack.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
            ])

            btn.layer.cornerRadius = 10
            btn.layer.borderWidth = 1
            btn.layer.borderColor = UIColor(white: 0.3, alpha: 1).cgColor
            btn.heightAnchor.constraint(equalToConstant: 52).isActive = true

            btn.addTarget(self, action: #selector(kelvinTapped(_:)), for: .touchUpInside)
            buttonRow.addArrangedSubview(btn)
            kelvinButtons.append(btn)
        }

        section.addArrangedSubview(buttonRow)
        return section
    }

    // MARK: - Populate from Config

    private func populateFromConfig() {
        // Intensity (log scale)
        intensitySlider.value = lumensToSlider(config.intensity)
        intensityLabel.text = formatLumens(config.intensity)

        // Cone angles
        innerAngleSlider.value = config.innerAngleDeg
        innerAngleLabel.text = "\(Int(config.innerAngleDeg))°"
        outerAngleSlider.value = config.outerAngleDeg
        outerAngleLabel.text = "\(Int(config.outerAngleDeg))°"

        // Reach
        reachSlider.value = config.attenuationRadius
        reachLabel.text = "\(Int(config.attenuationRadius))m"

        // Shadow
        shadowToggle.isOn = config.shadowEnabled

        // Kelvin button highlight
        updateKelvinHighlight()
    }

    private func formatLumens(_ lumens: Float) -> String {
        if lumens >= 1000 {
            return String(format: "%.0fK lm", lumens / 1000)
        }
        return String(format: "%.0f lm", lumens)
    }

    private func updateKelvinHighlight() {
        for btn in kelvinButtons {
            let isSelected = btn.tag == Int(config.colorTemperatureKelvin)
            btn.backgroundColor = isSelected
                ? UIColor.white.withAlphaComponent(0.15)
                : .clear
            btn.layer.borderColor = isSelected
                ? UIColor(red: 90/255, green: 130/255, blue: 255/255, alpha: 1).cgColor
                : UIColor(white: 0.3, alpha: 1).cgColor
        }
    }

    // MARK: - Actions

    @objc private func intensityChanged() {
        config.intensity = sliderToLumens(intensitySlider.value)
        intensityLabel.text = formatLumens(config.intensity)
        onUpdate(config)
    }

    @objc private func innerAngleChanged() {
        config.innerAngleDeg = innerAngleSlider.value
        // Enforce: outer must be at least inner + 5
        if config.outerAngleDeg < config.innerAngleDeg + 5 {
            config.outerAngleDeg = config.innerAngleDeg + 5
            outerAngleSlider.value = config.outerAngleDeg
            outerAngleLabel.text = "\(Int(config.outerAngleDeg))°"
        }
        innerAngleLabel.text = "\(Int(config.innerAngleDeg))°"
        onUpdate(config)
    }

    @objc private func outerAngleChanged() {
        config.outerAngleDeg = outerAngleSlider.value
        // Enforce: inner must be at most outer - 5
        if config.innerAngleDeg > config.outerAngleDeg - 5 {
            config.innerAngleDeg = config.outerAngleDeg - 5
            innerAngleSlider.value = config.innerAngleDeg
            innerAngleLabel.text = "\(Int(config.innerAngleDeg))°"
        }
        outerAngleLabel.text = "\(Int(config.outerAngleDeg))°"
        onUpdate(config)
    }

    @objc private func reachChanged() {
        config.attenuationRadius = reachSlider.value
        reachLabel.text = "\(Int(config.attenuationRadius))m"
        onUpdate(config)
    }

    @objc private func shadowToggled() {
        config.shadowEnabled = shadowToggle.isOn
        onUpdate(config)
    }

    @objc private func kelvinTapped(_ sender: UIButton) {
        config.colorTemperatureKelvin = Float(sender.tag)
        updateKelvinHighlight()
        onUpdate(config)
    }

    @objc private func doneTapped() {
        dismiss(animated: true)
    }
}
