//
//  CinematicLookPicker.swift
//  FilmsPage
//
//  Bottom sheet look picker for the cinematic camera system.
//  Displays built-in looks as visual preview cards grouped by category,
//  with an intensity slider and LUT import button.
//

import UIKit

// MARK: - CinematicLookPicker

final class CinematicLookPicker: UIViewController {
    
    // MARK: - Callbacks
    
    var onLookSelected: ((_ look: CinematicLook) -> Void)?
    var onIntensityChanged: ((_ intensity: Float) -> Void)?
    var onImportLUT: (() -> Void)?
    
    // MARK: - State
    
    private var allLooks: [CinematicLook] = []
    private var categories: [CinematicLookCategory] = []
    private var looksByCategory: [CinematicLookCategory: [CinematicLook]] = [:]
    private var selectedCategoryIndex: Int = 0
    private var selectedLookID: String?
    private var currentIntensity: Float = 1.0
    
    // MARK: - Style
    
    private let cardBg = UIColor(red: 0.08, green: 0.08, blue: 0.14, alpha: 1.0)
    private let accent = UIColor(red: 0.92, green: 0.32, blue: 0.18, alpha: 1.0)
    private let dimText = UIColor.white.withAlphaComponent(0.5)
    
    // MARK: - UI
    
    private let handleBar = UIView()
    private let titleLabel = UILabel()
    private let categoryStack = UIStackView()
    private let categoryScroll = UIScrollView()
    private let lookCollectionView: UICollectionView
    private let intensitySlider = UISlider()
    private let intensityLabel = UILabel()
    private let importButton = UIButton(type: .system)
    
    // MARK: - Init
    
    init(currentLookID: String? = nil, intensity: Float = 1.0) {
        self.selectedLookID = currentLookID
        self.currentIntensity = intensity
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 10
        layout.itemSize = CGSize(width: 120, height: 150)
        self.lookCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        super.init(nibName: nil, bundle: nil)
        
        allLooks = CinematicLookDatabase.allLooks
        for look in allLooks {
            looksByCategory[look.category, default: []].append(look)
        }
        categories = Array(looksByCategory.keys).sorted { $0.rawValue < $1.rawValue }
        
        if let currentID = currentLookID,
           let current = allLooks.first(where: { $0.id == currentID }),
           let idx = categories.firstIndex(of: current.category) {
            selectedCategoryIndex = idx
        }
        
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
        setupTitle()
        setupCategoryTabs()
        setupLookCards()
        setupIntensitySlider()
        setupImportButton()
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
    
    private func setupTitle() {
        titleLabel.text = "CINEMATIC LOOK"
        titleLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        titleLabel.textColor = dimText
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: handleBar.bottomAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    private func setupCategoryTabs() {
        categoryScroll.showsHorizontalScrollIndicator = false
        categoryScroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(categoryScroll)
        
        categoryStack.axis = .horizontal
        categoryStack.spacing = 6
        categoryStack.alignment = .center
        categoryStack.translatesAutoresizingMaskIntoConstraints = false
        categoryScroll.addSubview(categoryStack)
        
        for (idx, category) in categories.enumerated() {
            let btn = UIButton(type: .system)
            var config = UIButton.Configuration.filled()
            config.attributedTitle = AttributedString(
                category.rawValue,
                attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 11, weight: .bold)])
            )
            config.baseBackgroundColor = idx == selectedCategoryIndex
                ? accent : UIColor.white.withAlphaComponent(0.06)
            config.baseForegroundColor = idx == selectedCategoryIndex
                ? .white : dimText
            config.cornerStyle = .capsule
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
            btn.configuration = config
            btn.tag = idx
            btn.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside)
            categoryStack.addArrangedSubview(btn)
        }
        
        NSLayoutConstraint.activate([
            categoryScroll.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 14),
            categoryScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            categoryScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            categoryScroll.heightAnchor.constraint(equalToConstant: 36),
            
            categoryStack.leadingAnchor.constraint(equalTo: categoryScroll.contentLayoutGuide.leadingAnchor),
            categoryStack.trailingAnchor.constraint(equalTo: categoryScroll.contentLayoutGuide.trailingAnchor),
            categoryStack.topAnchor.constraint(equalTo: categoryScroll.contentLayoutGuide.topAnchor),
            categoryStack.bottomAnchor.constraint(equalTo: categoryScroll.contentLayoutGuide.bottomAnchor),
            categoryStack.heightAnchor.constraint(equalTo: categoryScroll.frameLayoutGuide.heightAnchor)
        ])
    }
    
    private func setupLookCards() {
        lookCollectionView.backgroundColor = .clear
        lookCollectionView.showsHorizontalScrollIndicator = false
        lookCollectionView.delegate = self
        lookCollectionView.dataSource = self
        lookCollectionView.register(LookPreviewCell.self, forCellWithReuseIdentifier: "LookCell")
        lookCollectionView.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        lookCollectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(lookCollectionView)
        
        NSLayoutConstraint.activate([
            lookCollectionView.topAnchor.constraint(equalTo: categoryScroll.bottomAnchor, constant: 14),
            lookCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            lookCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            lookCollectionView.heightAnchor.constraint(equalToConstant: 158)
        ])
    }
    
    private func setupIntensitySlider() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        
        let label = UILabel()
        label.text = "INTENSITY"
        label.font = UIFont.systemFont(ofSize: 9, weight: .bold)
        label.textColor = dimText
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        
        intensitySlider.minimumValue = 0
        intensitySlider.maximumValue = 1
        intensitySlider.value = currentIntensity
        intensitySlider.minimumTrackTintColor = accent
        intensitySlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.1)
        intensitySlider.addTarget(self, action: #selector(intensityChanged), for: .valueChanged)
        intensitySlider.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(intensitySlider)
        
        intensityLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .bold)
        intensityLabel.textColor = .white
        intensityLabel.text = "100%"
        intensityLabel.textAlignment = .right
        intensityLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(intensityLabel)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: lookCollectionView.bottomAnchor, constant: 16),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            container.heightAnchor.constraint(equalToConstant: 32),
            
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 65),
            
            intensitySlider.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            intensitySlider.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            intensitySlider.trailingAnchor.constraint(equalTo: intensityLabel.leadingAnchor, constant: -8),
            
            intensityLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            intensityLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            intensityLabel.widthAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func setupImportButton() {
        var config = UIButton.Configuration.filled()
        let imgCfg = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        config.image = UIImage(systemName: "doc.badge.plus", withConfiguration: imgCfg)
        config.imagePadding = 6
        config.attributedTitle = AttributedString(
            "Import LUT",
            attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 12, weight: .semibold)])
        )
        config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.06)
        config.baseForegroundColor = dimText
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        importButton.configuration = config
        importButton.addTarget(self, action: #selector(importTapped), for: .touchUpInside)
        importButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(importButton)
        
        NSLayoutConstraint.activate([
            importButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            importButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func categoryTapped(_ sender: UIButton) {
        selectedCategoryIndex = sender.tag
        for (idx, v) in categoryStack.arrangedSubviews.enumerated() {
            guard let btn = v as? UIButton, var cfg = btn.configuration else { continue }
            cfg.baseBackgroundColor = idx == selectedCategoryIndex
                ? accent : UIColor.white.withAlphaComponent(0.06)
            cfg.baseForegroundColor = idx == selectedCategoryIndex ? .white : dimText
            btn.configuration = cfg
        }
        lookCollectionView.reloadData()
        UISelectionFeedbackGenerator().selectionChanged()
    }
    
    @objc private func intensityChanged() {
        let val = intensitySlider.value
        intensityLabel.text = "\(Int(val * 100))%"
        onIntensityChanged?(val)
    }
    
    @objc private func importTapped() {
        onImportLUT?()
    }
    
    // MARK: - Data
    
    private var currentCategoryLooks: [CinematicLook] {
        guard selectedCategoryIndex < categories.count else { return [] }
        return looksByCategory[categories[selectedCategoryIndex]] ?? []
    }
}

// MARK: - UICollectionView

extension CinematicLookPicker: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return currentCategoryLooks.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LookCell", for: indexPath) as! LookPreviewCell
        let look = currentCategoryLooks[indexPath.item]
        let isSelected = look.id == selectedLookID
        cell.configure(look: look, isSelected: isSelected, accent: accent)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let look = currentCategoryLooks[indexPath.item]
        selectedLookID = look.id
        collectionView.reloadData()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onLookSelected?(look)
    }
}

// MARK: - LookPreviewCell

private final class LookPreviewCell: UICollectionViewCell {
    
    private let nameLabel = UILabel()
    private let categoryBadge = UILabel()
    private let gradientView = UIView()
    private let gradientLayer = CAGradientLayer()
    private let bg = UIView()
    private let checkmark = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        bg.layer.cornerRadius = 14
        bg.clipsToBounds = true
        bg.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bg)
        
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(gradientView)
        gradientView.layer.addSublayer(gradientLayer)
        
        nameLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        nameLabel.textColor = .white
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(nameLabel)
        
        categoryBadge.font = UIFont.systemFont(ofSize: 8, weight: .bold)
        categoryBadge.textColor = UIColor.white.withAlphaComponent(0.6)
        categoryBadge.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(categoryBadge)
        
        let checkCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        checkmark.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: checkCfg)
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.isHidden = true
        bg.addSubview(checkmark)
        
        NSLayoutConstraint.activate([
            bg.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bg.topAnchor.constraint(equalTo: contentView.topAnchor),
            bg.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            gradientView.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
            gradientView.topAnchor.constraint(equalTo: bg.topAnchor),
            gradientView.heightAnchor.constraint(equalToConstant: 80),
            
            nameLabel.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -10),
            nameLabel.topAnchor.constraint(equalTo: gradientView.bottomAnchor, constant: 8),
            
            categoryBadge.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            categoryBadge.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            
            checkmark.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -8),
            checkmark.topAnchor.constraint(equalTo: bg.topAnchor, constant: 8)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = gradientView.bounds
    }
    
    func configure(look: CinematicLook, isSelected: Bool, accent: UIColor) {
        nameLabel.text = look.name
        categoryBadge.text = look.category.rawValue.uppercased()
        
        // Generate preview gradient from look parameters
        let warmColor = UIColor(
            red: CGFloat(0.5 + look.warmth * 0.3),
            green: CGFloat(0.3 + look.tint * 0.1),
            blue: CGFloat(0.4 - look.warmth * 0.2),
            alpha: 1.0
        )
        let coolColor = UIColor(
            red: CGFloat(0.15 + look.shadowLift * 0.1),
            green: CGFloat(0.15 + look.contrast * 0.05),
            blue: CGFloat(0.25 + look.highlightRolloff * 0.1),
            alpha: 1.0
        )
        
        gradientLayer.colors = [warmColor.cgColor, coolColor.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 8
        
        checkmark.isHidden = !isSelected
        checkmark.tintColor = accent
        
        bg.layer.borderWidth = isSelected ? 1.5 : 0
        bg.layer.borderColor = isSelected ? accent.cgColor : nil
        bg.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.16, alpha: 1.0)
    }
}
