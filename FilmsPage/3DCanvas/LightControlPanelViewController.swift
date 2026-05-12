//
//  LightControlPanelViewController.swift
//  FilmsPage
//
//  Real-time light property editor presented as a bottom sheet.
//  Logarithmic intensity slider, Kelvin presets, reflector presets,
//  diffusion slider, gobo selector, cone angles, reach, and shadow toggle.
//

import UIKit
import RealityKit

class LightControlPanelViewController: UIViewController {

    private weak var targetEntity: Entity?
    private var config: LightConfigComponent
    private let onUpdate: (LightConfigComponent) -> Void

    // ── UI Elements ─────────────────────────────────────────────────────
    private let intensitySlider  = UISlider()
    private let intensityLabel   = UILabel()
    private let reachSlider      = UISlider()
    private let reachLabel       = UILabel()
    private let innerAngleSlider = UISlider()
    private let innerAngleLabel  = UILabel()
    private let outerAngleSlider = UISlider()
    private let outerAngleLabel  = UILabel()
    private let diffuserSlider   = UISlider()
    private let diffuserLabel    = UILabel()
    private let shadowToggle     = UISwitch()
    private var kelvinButtons:    [UIButton] = []
    private var reflectorButtons: [UIButton] = []
    private var goboButtons:      [UIButton] = []

    // Section containers (for conditional hiding)
    private let coneSection      = UIStackView()
    private let shadowSection    = UIStackView()
    private let reflectorSection = UIStackView()
    private let diffuserSection  = UIStackView()
    private let goboSection      = UIStackView()

    // Accent color used throughout
    private let accent = UIColor(red: 90/255, green: 130/255, blue: 255/255, alpha: 1)

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
        
        // Let the presentation controller know roughly how tall the content is.
        // It will be clamped by RightPanelPresentationController if it exceeds max bounds.
        preferredContentSize = CGSize(width: 300, height: 600)
    }

    // MARK: - Logarithmic Intensity Mapping

    private func sliderToLumens(_ value: Float) -> Float {
        pow(10, 3.0 + value * 2.699)
    }
    private func lumensToSlider(_ lumens: Float) -> Float {
        (log10(max(lumens, 1)) - 3.0) / 2.699
    }

    // MARK: - Build UI

    private func buildUI() {
        let header = buildHeader()
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            header.heightAnchor.constraint(equalToConstant: 44),
            
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
        ])

        // ── Intensity ───────────────────────────────────────────────────
        contentStack.addArrangedSubview(buildSliderSection(
            title: "INTENSITY", slider: intensitySlider, valueLabel: intensityLabel,
            minValue: 0, maxValue: 1, action: #selector(intensityChanged)))

        // ── Color Temperature ───────────────────────────────────────────
        contentStack.addArrangedSubview(buildKelvinSection())

        // ── Reflector Type (spot only) ──────────────────────────────────
        buildReflectorSection()
        contentStack.addArrangedSubview(reflectorSection)
        reflectorSection.isHidden = (config.lightKind != .spot)

        // ── Cone Angle (spot + panel) ───────────────────────────────────
        coneSection.axis = .vertical
        coneSection.spacing = 14
        coneSection.addArrangedSubview(buildSliderSection(
            title: "INNER ANGLE", slider: innerAngleSlider, valueLabel: innerAngleLabel,
            minValue: 1, maxValue: 60, action: #selector(innerAngleChanged)))
        coneSection.addArrangedSubview(buildSliderSection(
            title: "OUTER ANGLE", slider: outerAngleSlider, valueLabel: outerAngleLabel,
            minValue: 5, maxValue: 120, action: #selector(outerAngleChanged)))
        contentStack.addArrangedSubview(coneSection)
        coneSection.isHidden = (config.lightKind == .point)

        // ── Diffusion (spot + panel, mapped differently for point) ──────
        buildDiffuserSection()
        contentStack.addArrangedSubview(diffuserSection)

        // ── Gobo (spot only) ────────────────────────────────────────────
        buildGoboSection()
        contentStack.addArrangedSubview(goboSection)
        goboSection.isHidden = (config.lightKind != .spot)

        // ── Reach ───────────────────────────────────────────────────────
        contentStack.addArrangedSubview(buildSliderSection(
            title: "REACH", slider: reachSlider, valueLabel: reachLabel,
            minValue: 1, maxValue: 8, action: #selector(reachChanged)))

        // ── Shadow Toggle (spot only) ───────────────────────────────────
        shadowSection.axis = .horizontal
        shadowSection.spacing = 12
        shadowSection.alignment = .center
        let shadowLabel = UILabel()
        shadowLabel.text = "Shadows"
        shadowLabel.font = .systemFont(ofSize: 15, weight: .medium)
        shadowLabel.textColor = .white
        shadowSection.addArrangedSubview(shadowLabel)
        shadowSection.addArrangedSubview(UIView()) // spacer
        shadowToggle.onTintColor = accent
        shadowToggle.addTarget(self, action: #selector(shadowToggled), for: .valueChanged)
        shadowSection.addArrangedSubview(shadowToggle)
        contentStack.addArrangedSubview(shadowSection)
        shadowSection.isHidden = (config.lightKind != .spot)
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
        if let procKind = config.proceduralKind {
            switch procKind {
            case .practicalLantern: titleLabel.text = "Practical Lantern"
            case .fluorescentTube:  titleLabel.text = "Fluorescent Tube"
            case .skyPanel:         titleLabel.text = "Sky Panel"
            }
        } else {
            switch config.lightKind {
            case .spot:  titleLabel.text = "Spotlight"
            case .panel: titleLabel.text = "LED Panel"
            case .point: titleLabel.text = "Lantern"
            }
        }
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .white
        container.addArrangedSubview(titleLabel)

        container.addArrangedSubview(UIView()) // flex spacer

        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let doneBtn = UIButton(type: .system)
        doneBtn.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        doneBtn.tintColor = .white
        doneBtn.backgroundColor = UIColor(white: 0.2, alpha: 1)
        doneBtn.layer.cornerRadius = 16
        doneBtn.translatesAutoresizingMaskIntoConstraints = false
        doneBtn.widthAnchor.constraint(equalToConstant: 32).isActive = true
        doneBtn.heightAnchor.constraint(equalToConstant: 32).isActive = true
        doneBtn.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        container.addArrangedSubview(doneBtn)

        return container
    }

    // MARK: - Slider Section Builder

    private func buildSliderSection(
        title: String, slider: UISlider, valueLabel: UILabel,
        minValue: Float, maxValue: Float, action: Selector
    ) -> UIStackView {
        let section = UIStackView()
        section.axis = .vertical
        section.spacing = 6

        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = UIColor(white: 0.5, alpha: 1)
        headerRow.addArrangedSubview(label)
        headerRow.addArrangedSubview(UIView()) // spacer
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        valueLabel.textColor = .white
        headerRow.addArrangedSubview(valueLabel)
        section.addArrangedSubview(headerRow)

        slider.minimumValue = minValue
        slider.maximumValue = maxValue
        slider.minimumTrackTintColor = accent
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

        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 10

        for preset in kelvinPresets {
            let btn = makePresetButton(
                mainText: preset.label, subText: preset.subtitle, tag: Int(preset.kelvin))
            btn.addTarget(self, action: #selector(kelvinTapped(_:)), for: .touchUpInside)
            row.addArrangedSubview(btn)
            kelvinButtons.append(btn)
        }
        section.addArrangedSubview(row)
        return section
    }

    // MARK: - Reflector Section

    private func buildReflectorSection() {
        reflectorSection.axis = .vertical
        reflectorSection.spacing = 8

        let label = UILabel()
        label.text = "REFLECTOR TYPE"
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = UIColor(white: 0.5, alpha: 1)
        reflectorSection.addArrangedSubview(label)

        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 8

        for (i, type) in ReflectorType.allCases.enumerated() {
            let btn = makePresetButton(mainText: type.displayName, subText: nil, tag: i)
            btn.addTarget(self, action: #selector(reflectorTapped(_:)), for: .touchUpInside)
            row.addArrangedSubview(btn)
            reflectorButtons.append(btn)
        }
        reflectorSection.addArrangedSubview(row)
    }

    // MARK: - Diffuser Section

    private func buildDiffuserSection() {
        diffuserSection.axis = .vertical
        diffuserSection.spacing = 6

        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        let titleLabel = UILabel()
        titleLabel.text = "DIFFUSION"
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = UIColor(white: 0.5, alpha: 1)
        headerRow.addArrangedSubview(titleLabel)
        headerRow.addArrangedSubview(UIView())
        diffuserLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        diffuserLabel.textColor = .white
        headerRow.addArrangedSubview(diffuserLabel)
        diffuserSection.addArrangedSubview(headerRow)

        let labelRow = UIStackView()
        labelRow.axis = .horizontal
        let hardLabel = UILabel()
        hardLabel.text = "Hard Edge"
        hardLabel.font = .systemFont(ofSize: 11, weight: .regular)
        hardLabel.textColor = UIColor(white: 0.45, alpha: 1)
        labelRow.addArrangedSubview(hardLabel)
        labelRow.addArrangedSubview(UIView())
        let silkLabel = UILabel()
        silkLabel.text = "Silk"
        silkLabel.font = .systemFont(ofSize: 11, weight: .regular)
        silkLabel.textColor = UIColor(white: 0.45, alpha: 1)
        labelRow.addArrangedSubview(silkLabel)
        diffuserSection.addArrangedSubview(labelRow)

        diffuserSlider.minimumValue = 0
        diffuserSlider.maximumValue = 1
        diffuserSlider.minimumTrackTintColor = accent
        diffuserSlider.maximumTrackTintColor = UIColor(white: 0.2, alpha: 1)
        diffuserSlider.addTarget(self, action: #selector(diffuserChanged), for: .valueChanged)
        diffuserSection.addArrangedSubview(diffuserSlider)
    }

    // MARK: - Gobo Section

    private func buildGoboSection() {
        goboSection.axis = .vertical
        goboSection.spacing = 8

        let label = UILabel()
        label.text = "GOBO"
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = UIColor(white: 0.5, alpha: 1)
        goboSection.addArrangedSubview(label)

        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 8

        for (i, pattern) in GoboPattern.allCases.enumerated() {
            let btn = makePresetButton(mainText: pattern.displayName, subText: nil, tag: i)
            btn.addTarget(self, action: #selector(goboTapped(_:)), for: .touchUpInside)
            row.addArrangedSubview(btn)
            goboButtons.append(btn)
        }
        goboSection.addArrangedSubview(row)
    }

    // MARK: - Preset Button Factory

    private func makePresetButton(mainText: String, subText: String?, tag: Int) -> UIButton {
        let btn = UIButton(type: .system)
        btn.tag = tag

        let titleStack = UIStackView()
        titleStack.axis = .vertical
        titleStack.alignment = .center
        titleStack.spacing = 2
        titleStack.isUserInteractionEnabled = false

        let mainLabel = UILabel()
        mainLabel.text = mainText
        mainLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        mainLabel.textColor = .white
        mainLabel.textAlignment = .center
        titleStack.addArrangedSubview(mainLabel)

        if let sub = subText {
            let subLabel = UILabel()
            subLabel.text = sub
            subLabel.font = .systemFont(ofSize: 10, weight: .regular)
            subLabel.textColor = UIColor(white: 0.6, alpha: 1)
            subLabel.textAlignment = .center
            titleStack.addArrangedSubview(subLabel)
        }

        btn.addSubview(titleStack)
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleStack.centerXAnchor.constraint(equalTo: btn.centerXAnchor),
            titleStack.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
        ])

        btn.layer.cornerRadius = 8
        btn.layer.borderWidth = 1
        btn.layer.borderColor = UIColor(white: 0.3, alpha: 1).cgColor
        btn.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return btn
    }

    // MARK: - Populate from Config

    private func populateFromConfig() {
        intensitySlider.value = lumensToSlider(config.intensity)
        intensityLabel.text = formatLumens(config.intensity)

        innerAngleSlider.value = config.innerAngleDeg
        innerAngleLabel.text = "\(Int(config.innerAngleDeg))°"
        outerAngleSlider.value = config.outerAngleDeg
        outerAngleLabel.text = "\(Int(config.outerAngleDeg))°"

        reachSlider.value = config.attenuationRadius
        reachLabel.text = "\(Int(config.attenuationRadius))m"

        shadowToggle.isOn = config.shadowEnabled

        diffuserSlider.value = config.diffuserAmount
        diffuserLabel.text = String(format: "%.0f%%", config.diffuserAmount * 100)

        updateKelvinHighlight()
        updateReflectorHighlight()
        updateGoboHighlight()
    }

    private func formatLumens(_ lumens: Float) -> String {
        lumens >= 1000
            ? String(format: "%.0fK lm", lumens / 1000)
            : String(format: "%.0f lm", lumens)
    }

    // MARK: - Highlight Helpers

    private func updateKelvinHighlight() {
        for btn in kelvinButtons {
            let sel = btn.tag == Int(config.colorTemperatureKelvin)
            btn.backgroundColor = sel ? UIColor.white.withAlphaComponent(0.15) : .clear
            btn.layer.borderColor = sel ? accent.cgColor : UIColor(white: 0.3, alpha: 1).cgColor
        }
    }

    private func updateReflectorHighlight() {
        let allCases = ReflectorType.allCases
        for btn in reflectorButtons {
            let sel = btn.tag < allCases.count && allCases[btn.tag] == config.reflectorType
            btn.backgroundColor = sel ? UIColor.white.withAlphaComponent(0.15) : .clear
            btn.layer.borderColor = sel ? accent.cgColor : UIColor(white: 0.3, alpha: 1).cgColor
        }
    }

    private func updateGoboHighlight() {
        let allCases = GoboPattern.allCases
        for btn in goboButtons {
            let sel = btn.tag < allCases.count && allCases[btn.tag] == config.activeGobo
            btn.backgroundColor = sel ? UIColor.white.withAlphaComponent(0.15) : .clear
            btn.layer.borderColor = sel ? accent.cgColor : UIColor(white: 0.3, alpha: 1).cgColor
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

    @objc private func reflectorTapped(_ sender: UIButton) {
        let allCases = ReflectorType.allCases
        guard sender.tag < allCases.count else { return }
        let type = allCases[sender.tag]
        config.reflectorType = type
        config.innerAngleDeg = type.innerAngle
        config.outerAngleDeg = type.outerAngle
        // Sync sliders to reflect new values
        innerAngleSlider.value = config.innerAngleDeg
        outerAngleSlider.value = config.outerAngleDeg
        innerAngleLabel.text = "\(Int(config.innerAngleDeg))°"
        outerAngleLabel.text = "\(Int(config.outerAngleDeg))°"
        updateReflectorHighlight()
        onUpdate(config)
    }

    @objc private func diffuserChanged() {
        config.diffuserAmount = diffuserSlider.value
        diffuserLabel.text = String(format: "%.0f%%", config.diffuserAmount * 100)
        // For spot/panel: apply diffusion to inner/outer ratio
        if config.lightKind != .point {
            applyDiffuser(to: &config)
            innerAngleSlider.value = config.innerAngleDeg
            innerAngleLabel.text = "\(Int(config.innerAngleDeg))°"
        }
        onUpdate(config)
    }

    @objc private func goboTapped(_ sender: UIButton) {
        let allCases = GoboPattern.allCases
        guard sender.tag < allCases.count else { return }
        config.activeGobo = allCases[sender.tag]
        updateGoboHighlight()
        onUpdate(config)
    }

    @objc private func doneTapped() {
        dismiss(animated: true)
    }
}
