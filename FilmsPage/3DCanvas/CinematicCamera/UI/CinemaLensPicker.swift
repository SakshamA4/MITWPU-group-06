//
//  CinemaLensPicker.swift
//  FilmsPage
//
//  Bottom sheet lens picker for the cinematic camera system.
//  Displays lens families in a scrollable list with a horizontal
//  focal length wheel for the selected family.
//
//  Design: Apple Music-style floating card with haptic feedback
//  at standard focal lengths.
//

import UIKit

// MARK: - CinemaLensPicker

final class CinemaLensPicker: UIViewController {
    
    // MARK: - Callbacks
    
    /// Called when the user selects a lens family + focal length.
    var onLensSelected: ((_ lens: CinemaLensFamily, _ focalLength: Float) -> Void)?
    
    // MARK: - State
    
    private var allLensFamilies: [CinemaLensFamily] = []
    private var selectedFamilyIndex: Int = 0
    private var selectedFocalLength: Float = 50.0
    
    // MARK: - Style
    
    private let cardBg = UIColor(red: 0.08, green: 0.08, blue: 0.14, alpha: 1.0)
    private let accentColor = UIColor(red: 0.92, green: 0.32, blue: 0.18, alpha: 1.0)
    private let dimText = UIColor.white.withAlphaComponent(0.5)
    
    // MARK: - UI Elements
    
    private let handleBar = UIView()
    private let titleLabel = UILabel()
    private let familyCollectionView: UICollectionView
    private let focalWheelCollectionView: UICollectionView
    private let focalReadout = UILabel()
    private let brandLabel = UILabel()
    private let characterLabel = UILabel()
    
    private let feedbackGenerator = UISelectionFeedbackGenerator()
    
    // MARK: - Init
    
    init(currentLens: CinemaLensFamily? = nil, currentFocalLength: Float = 50) {
        // Family list layout
        let familyLayout = UICollectionViewFlowLayout()
        familyLayout.scrollDirection = .vertical
        familyLayout.minimumLineSpacing = 4
        familyLayout.itemSize = CGSize(width: 300, height: 52)
        self.familyCollectionView = UICollectionView(frame: .zero, collectionViewLayout: familyLayout)
        
        // Focal wheel layout
        let wheelLayout = UICollectionViewFlowLayout()
        wheelLayout.scrollDirection = .horizontal
        wheelLayout.minimumLineSpacing = 0
        wheelLayout.itemSize = CGSize(width: 64, height: 56)
        self.focalWheelCollectionView = UICollectionView(frame: .zero, collectionViewLayout: wheelLayout)
        
        super.init(nibName: nil, bundle: nil)
        
        self.allLensFamilies = CinemaLensDatabase.allFamilies
        
        if let current = currentLens,
           let idx = allLensFamilies.firstIndex(where: { $0.id == current.id }) {
            selectedFamilyIndex = idx
        }
        selectedFocalLength = currentFocalLength
        
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
        setupBrandInfo()
        setupFocalWheel()
        setupFamilyList()
        
        feedbackGenerator.prepare()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Scroll to selected family
        let indexPath = IndexPath(item: selectedFamilyIndex, section: 0)
        familyCollectionView.selectItem(at: indexPath, animated: true, scrollPosition: .centeredVertically)
        updateFocalWheel()
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
        titleLabel.text = "LENS"
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
    
    private func setupBrandInfo() {
        brandLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        brandLabel.textColor = .white
        brandLabel.textAlignment = .center
        brandLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(brandLabel)
        
        characterLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        characterLabel.textColor = dimText
        characterLabel.textAlignment = .center
        characterLabel.numberOfLines = 2
        characterLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(characterLabel)
        
        NSLayoutConstraint.activate([
            brandLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            brandLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            characterLabel.topAnchor.constraint(equalTo: brandLabel.bottomAnchor, constant: 4),
            characterLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            characterLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
        
        updateBrandInfo()
    }
    
    private func setupFocalWheel() {
        focalWheelCollectionView.backgroundColor = .clear
        focalWheelCollectionView.showsHorizontalScrollIndicator = false
        focalWheelCollectionView.delegate = self
        focalWheelCollectionView.dataSource = self
        focalWheelCollectionView.register(FocalLengthCell.self, forCellWithReuseIdentifier: "FocalCell")
        focalWheelCollectionView.translatesAutoresizingMaskIntoConstraints = false
        focalWheelCollectionView.tag = 200
        view.addSubview(focalWheelCollectionView)
        
        focalReadout.font = UIFont.monospacedDigitSystemFont(ofSize: 28, weight: .bold)
        focalReadout.textColor = accentColor
        focalReadout.textAlignment = .center
        focalReadout.text = "\(Int(selectedFocalLength))mm"
        focalReadout.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(focalReadout)
        
        NSLayoutConstraint.activate([
            focalReadout.topAnchor.constraint(equalTo: characterLabel.bottomAnchor, constant: 16),
            focalReadout.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            focalWheelCollectionView.topAnchor.constraint(equalTo: focalReadout.bottomAnchor, constant: 8),
            focalWheelCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            focalWheelCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            focalWheelCollectionView.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    private func setupFamilyList() {
        familyCollectionView.backgroundColor = .clear
        familyCollectionView.showsVerticalScrollIndicator = false
        familyCollectionView.delegate = self
        familyCollectionView.dataSource = self
        familyCollectionView.register(LensFamilyCell.self, forCellWithReuseIdentifier: "FamilyCell")
        familyCollectionView.translatesAutoresizingMaskIntoConstraints = false
        familyCollectionView.tag = 100
        view.addSubview(familyCollectionView)
        
        NSLayoutConstraint.activate([
            familyCollectionView.topAnchor.constraint(equalTo: focalWheelCollectionView.bottomAnchor, constant: 16),
            familyCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            familyCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            familyCollectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
    }
    
    // MARK: - Updates
    
    private func updateBrandInfo() {
        guard selectedFamilyIndex < allLensFamilies.count else { return }
        let family = allLensFamilies[selectedFamilyIndex]
        brandLabel.text = family.familyName
        
        let anamorphic = family.anamorphicMode.isAnamorphic
            ? " • Anamorphic \(family.anamorphicMode.squeezeRatio)×"
            : ""
        characterLabel.text = "\(family.brand.rawValue)\(anamorphic)"
    }
    
    private func updateFocalWheel() {
        focalWheelCollectionView.reloadData()
        
        // Select current focal length
        let family = allLensFamilies[selectedFamilyIndex]
        if let idx = family.focalLengths.firstIndex(where: { $0.focalLengthMM == selectedFocalLength }) {
            let indexPath = IndexPath(item: idx, section: 0)
            focalWheelCollectionView.selectItem(at: indexPath, animated: true, scrollPosition: .centeredHorizontally)
        }
    }
    
    private var currentFamily: CinemaLensFamily {
        allLensFamilies[selectedFamilyIndex]
    }
}

// MARK: - UICollectionView DataSource & Delegate

extension CinemaLensPicker: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView.tag == 100 {
            return allLensFamilies.count
        } else {
            return currentFamily.focalLengths.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView.tag == 100 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FamilyCell", for: indexPath) as! LensFamilyCell
            let family = allLensFamilies[indexPath.item]
            let isSelected = indexPath.item == selectedFamilyIndex
            cell.configure(family: family, isSelected: isSelected, accent: accentColor)
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FocalCell", for: indexPath) as! FocalLengthCell
            let fl = currentFamily.focalLengths[indexPath.item]
            let isSelected = fl.focalLengthMM == selectedFocalLength
            cell.configure(focalLength: fl.focalLengthMM, isSelected: isSelected, accent: accentColor)
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView.tag == 100 {
            selectedFamilyIndex = indexPath.item
            let family = allLensFamilies[selectedFamilyIndex]
            selectedFocalLength = family.defaultFocalLength.focalLengthMM
            
            familyCollectionView.reloadData()
            updateBrandInfo()
            updateFocalWheel()
            focalReadout.text = "\(Int(selectedFocalLength))mm"
            
            feedbackGenerator.selectionChanged()
            onLensSelected?(family, selectedFocalLength)
        } else {
            let fl = currentFamily.focalLengths[indexPath.item]
            selectedFocalLength = fl.focalLengthMM
            focalReadout.text = "\(Int(selectedFocalLength))mm"
            focalWheelCollectionView.reloadData()
            
            feedbackGenerator.selectionChanged()
            onLensSelected?(currentFamily, selectedFocalLength)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView.tag == 100 {
            return CGSize(width: collectionView.bounds.width, height: 52)
        } else {
            return CGSize(width: 64, height: 56)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        if collectionView.tag == 200 {
            let totalWidth = collectionView.bounds.width
            let cellWidth: CGFloat = 64
            let inset = (totalWidth - cellWidth) / 2
            return UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset)
        }
        return .zero
    }
}

// MARK: - LensFamilyCell

private final class LensFamilyCell: UICollectionViewCell {
    
    private let nameLabel = UILabel()
    private let brandLabel = UILabel()
    private let typeLabel = UILabel()
    private let bg = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        bg.layer.cornerRadius = 12
        bg.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bg)
        
        nameLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)
        
        brandLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        brandLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(brandLabel)
        
        typeLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        typeLabel.textAlignment = .right
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(typeLabel)
        
        NSLayoutConstraint.activate([
            bg.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bg.topAnchor.constraint(equalTo: contentView.topAnchor),
            bg.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -7),
            
            brandLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            brandLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            
            typeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            typeLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(family: CinemaLensFamily, isSelected: Bool, accent: UIColor) {
        nameLabel.text = family.familyName
        brandLabel.text = family.brand.rawValue
        brandLabel.textColor = isSelected ? accent.withAlphaComponent(0.8) : UIColor.white.withAlphaComponent(0.4)
        
        if family.anamorphicMode.isAnamorphic {
            typeLabel.text = "ANAMORPHIC"
            typeLabel.textColor = accent
        } else {
            typeLabel.text = "SPHERICAL"
            typeLabel.textColor = UIColor.white.withAlphaComponent(0.3)
        }
        
        bg.backgroundColor = isSelected
            ? accent.withAlphaComponent(0.15)
            : UIColor.white.withAlphaComponent(0.04)
        
        bg.layer.borderWidth = isSelected ? 1 : 0
        bg.layer.borderColor = isSelected ? accent.withAlphaComponent(0.4).cgColor : nil
    }
}

// MARK: - FocalLengthCell

private final class FocalLengthCell: UICollectionViewCell {
    
    private let label = UILabel()
    private let dot = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        
        dot.layer.cornerRadius = 3
        dot.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dot)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -6),
            
            dot.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            dot.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 4),
            dot.widthAnchor.constraint(equalToConstant: 6),
            dot.heightAnchor.constraint(equalToConstant: 6)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(focalLength: Float, isSelected: Bool, accent: UIColor) {
        label.text = "\(Int(focalLength))"
        label.textColor = isSelected ? accent : UIColor.white.withAlphaComponent(0.5)
        dot.backgroundColor = isSelected ? accent : UIColor.white.withAlphaComponent(0.15)
    }
}
