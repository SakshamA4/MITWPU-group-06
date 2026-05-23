//
//  FrameGuidePicker.swift
//  FilmsPage
//
//  Bottom sheet picker for cinema aspect ratios and frame guide overlays.
//  Two sections: aspect ratio selector (visual ratio cards) and
//  frame guide toggles (thirds, safe areas, golden ratio, etc).
//

import UIKit

// MARK: - FrameGuidePicker

final class FrameGuidePicker: UIViewController {
    
    // MARK: - Callbacks
    
    var onAspectRatioSelected: ((_ preset: CinemaAspectRatioPreset) -> Void)?
    var onFrameGuidesChanged: ((_ config: FrameGuideConfig) -> Void)?
    
    // MARK: - State
    
    private var selectedAspectRatio: CinemaAspectRatioPreset = .scope239
    private var guideConfig = FrameGuideConfig()
    
    // MARK: - Style
    
    private let cardBg = UIColor(red: 0.08, green: 0.08, blue: 0.14, alpha: 1.0)
    private let accent = UIColor(red: 0.92, green: 0.32, blue: 0.18, alpha: 1.0)
    private let dimText = UIColor.white.withAlphaComponent(0.5)
    
    // MARK: - UI
    
    private let handleBar = UIView()
    private let aspectTitle = UILabel()
    private let aspectCollectionView: UICollectionView
    private let guidesTitle = UILabel()
    private let guidesStack = UIStackView()
    private let opacitySlider = UISlider()
    private let opacityLabel = UILabel()
    
    private let allAspectRatios = CinemaAspectRatioPreset.allCases
    
    // MARK: - Init
    
    init(currentAspect: CinemaAspectRatioPreset = .scope239, currentGuides: FrameGuideConfig = FrameGuideConfig()) {
        self.selectedAspectRatio = currentAspect
        self.guideConfig = currentGuides
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 8
        layout.itemSize = CGSize(width: 100, height: 70)
        self.aspectCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        super.init(nibName: nil, bundle: nil)
        
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.preferredCornerRadius = 24
        }
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = cardBg
        setupHandle()
        setupAspectSection()
        setupGuidesSection()
        setupOpacitySlider()
    }
    
    // MARK: - Setup
    
    private func setupHandle() {
        handleBar.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        handleBar.layer.cornerRadius = 2.5
        handleBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(handleBar)
        
        NSLayoutConstraint.activate([
            handleBar.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            handleBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            handleBar.widthAnchor.constraint(equalToConstant: 36),
            handleBar.heightAnchor.constraint(equalToConstant: 5)
        ])
    }
    
    private func setupAspectSection() {
        aspectTitle.text = "ASPECT RATIO"
        aspectTitle.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        aspectTitle.textColor = dimText
        aspectTitle.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(aspectTitle)
        
        aspectCollectionView.backgroundColor = .clear
        aspectCollectionView.showsHorizontalScrollIndicator = false
        aspectCollectionView.delegate = self
        aspectCollectionView.dataSource = self
        aspectCollectionView.register(AspectRatioCell.self, forCellWithReuseIdentifier: "AspectCell")
        aspectCollectionView.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        aspectCollectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(aspectCollectionView)
        
        NSLayoutConstraint.activate([
            aspectTitle.topAnchor.constraint(equalTo: handleBar.bottomAnchor, constant: 16),
            aspectTitle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            aspectCollectionView.topAnchor.constraint(equalTo: aspectTitle.bottomAnchor, constant: 10),
            aspectCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            aspectCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            aspectCollectionView.heightAnchor.constraint(equalToConstant: 78)
        ])
    }
    
    private func setupGuidesSection() {
        guidesTitle.text = "FRAME GUIDES"
        guidesTitle.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        guidesTitle.textColor = dimText
        guidesTitle.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(guidesTitle)
        
        guidesStack.axis = .vertical
        guidesStack.spacing = 4
        guidesStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(guidesStack)
        
        // Build guide toggle rows
        let guideTypes: [(FrameGuideType, String, String)] = [
            (.thirds, "Rule of Thirds", "square.grid.3x3"),
            (.centerCross, "Center Cross", "plus"),
            (.diagonal, "Diagonals", "arrow.up.right.and.arrow.down.left"),
            (.goldenRatio, "Golden Ratio", "rectangle.split.3x3"),
            (.actionSafe, "Action Safe (90%)", "rectangle.inset.filled"),
            (.titleSafe, "Title Safe (80%)", "rectangle.center.inset.filled"),
            (.crosshair, "Crosshair", "scope"),
            (.horizon, "Horizon Line", "line.horizontal.star.fill.line.horizontal"),
        ]
        
        for (type, title, icon) in guideTypes {
            let row = createGuideRow(type: type, title: title, icon: icon)
            guidesStack.addArrangedSubview(row)
        }
        
        NSLayoutConstraint.activate([
            guidesTitle.topAnchor.constraint(equalTo: aspectCollectionView.bottomAnchor, constant: 18),
            guidesTitle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            guidesStack.topAnchor.constraint(equalTo: guidesTitle.bottomAnchor, constant: 10),
            guidesStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            guidesStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }
    
    private func setupOpacitySlider() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        
        let label = UILabel()
        label.text = "OPACITY"
        label.font = UIFont.systemFont(ofSize: 9, weight: .bold)
        label.textColor = dimText
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        
        opacitySlider.minimumValue = 0.1
        opacitySlider.maximumValue = 1.0
        opacitySlider.value = guideConfig.globalOpacity
        opacitySlider.minimumTrackTintColor = accent
        opacitySlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.1)
        opacitySlider.addTarget(self, action: #selector(opacityChanged), for: .valueChanged)
        opacitySlider.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(opacitySlider)
        
        opacityLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        opacityLabel.textColor = .white
        opacityLabel.text = "\(Int(guideConfig.globalOpacity * 100))%"
        opacityLabel.textAlignment = .right
        opacityLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(opacityLabel)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: guidesStack.bottomAnchor, constant: 16),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            container.heightAnchor.constraint(equalToConstant: 28),
            
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 55),
            
            opacitySlider.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            opacitySlider.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            opacitySlider.trailingAnchor.constraint(equalTo: opacityLabel.leadingAnchor, constant: -8),
            
            opacityLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            opacityLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            opacityLabel.widthAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    // MARK: - Guide Row Builder
    
    private func createGuideRow(type: FrameGuideType, title: String, icon: String) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 36).isActive = true
        
        let iconCfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconCfg))
        iconView.tintColor = dimText
        iconView.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(iconView)
        
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(label)
        
        let toggle = UISwitch()
        toggle.isOn = guideConfig.activeGuides.contains(type)
        toggle.onTintColor = accent
        toggle.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        toggle.translatesAutoresizingMaskIntoConstraints = false
        toggle.tag = type.hashValue
        toggle.accessibilityIdentifier = type.rawValue
        toggle.addTarget(self, action: #selector(guideToggled(_:)), for: .valueChanged)
        row.addSubview(toggle)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 4),
            iconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            
            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            
            toggle.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -4),
            toggle.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        
        return row
    }
    
    // MARK: - Actions
    
    @objc private func guideToggled(_ sender: UISwitch) {
        guard let identifier = sender.accessibilityIdentifier,
              let type = FrameGuideType(rawValue: identifier) else { return }
        
        if sender.isOn {
            guideConfig.activeGuides.insert(type)
        } else {
            guideConfig.activeGuides.remove(type)
        }
        onFrameGuidesChanged?(guideConfig)
    }
    
    @objc private func opacityChanged() {
        let val = opacitySlider.value
        guideConfig.globalOpacity = val
        opacityLabel.text = "\(Int(val * 100))%"
        onFrameGuidesChanged?(guideConfig)
    }
}

// MARK: - Aspect Ratio Collection View

extension FrameGuidePicker: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return allAspectRatios.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AspectCell", for: indexPath) as! AspectRatioCell
        let preset = allAspectRatios[indexPath.item]
        let isSelected = preset == selectedAspectRatio
        cell.configure(preset: preset, isSelected: isSelected, accent: accent)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedAspectRatio = allAspectRatios[indexPath.item]
        collectionView.reloadData()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onAspectRatioSelected?(selectedAspectRatio)
    }
}

// MARK: - AspectRatioCell

private final class AspectRatioCell: UICollectionViewCell {
    
    private let ratioView = UIView()
    private let ratioLabel = UILabel()
    private let nameLabel = UILabel()
    private let bg = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        bg.layer.cornerRadius = 12
        bg.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bg)
        
        ratioView.layer.borderWidth = 1.5
        ratioView.layer.cornerRadius = 2
        ratioView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(ratioView)
        
        ratioLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        ratioLabel.textAlignment = .center
        ratioLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(ratioLabel)
        
        nameLabel.font = UIFont.systemFont(ofSize: 8, weight: .medium)
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 1
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)
        
        NSLayoutConstraint.activate([
            bg.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bg.topAnchor.constraint(equalTo: contentView.topAnchor),
            bg.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            ratioView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            ratioView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            ratioView.heightAnchor.constraint(equalToConstant: 24),
            
            ratioLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            ratioLabel.topAnchor.constraint(equalTo: ratioView.bottomAnchor, constant: 4),
            
            nameLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            nameLabel.topAnchor.constraint(equalTo: ratioLabel.bottomAnchor, constant: 2),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(preset: CinemaAspectRatioPreset, isSelected: Bool, accent: UIColor) {
        let ratio = preset.ratio
        let boxWidth: CGFloat = min(60, CGFloat(ratio) * 24)
        
        // Remove old width constraint and add new
        ratioView.constraints.filter { $0.firstAttribute == .width }.forEach { $0.isActive = false }
        ratioView.widthAnchor.constraint(equalToConstant: boxWidth).isActive = true
        
        ratioView.layer.borderColor = isSelected
            ? accent.cgColor
            : UIColor.white.withAlphaComponent(0.25).cgColor
        
        ratioLabel.text = preset.shortName
        ratioLabel.textColor = isSelected ? accent : .white
        
        nameLabel.text = preset.displayName
        nameLabel.textColor = isSelected ? accent.withAlphaComponent(0.8) : UIColor.white.withAlphaComponent(0.4)
        
        bg.backgroundColor = isSelected
            ? accent.withAlphaComponent(0.12)
            : UIColor.white.withAlphaComponent(0.04)
        bg.layer.borderWidth = isSelected ? 1 : 0
        bg.layer.borderColor = isSelected ? accent.withAlphaComponent(0.3).cgColor : nil
    }
}
