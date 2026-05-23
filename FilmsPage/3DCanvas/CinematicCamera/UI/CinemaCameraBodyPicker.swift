//
//  CinemaCameraBodyPicker.swift
//  FilmsPage
//
//  Bottom sheet camera body picker for the cinematic camera system.
//  Brand-first navigation: user selects a brand tab, then picks
//  a camera model from that brand's lineup.
//

import UIKit

// MARK: - CinemaCameraBodyPicker

final class CinemaCameraBodyPicker: UIViewController {
    
    // MARK: - Callbacks
    
    var onCameraSelected: ((_ body: CinemaCameraBody) -> Void)?
    
    // MARK: - State
    
    private var allBrands: [CinemaCameraBrand] = []
    private var camerasByBrand: [CinemaCameraBrand: [CinemaCameraBody]] = [:]
    private var selectedBrandIndex: Int = 0
    private var selectedCameraID: String?
    
    // MARK: - Style
    
    private let cardBg = UIColor(red: 0.08, green: 0.08, blue: 0.14, alpha: 1.0)
    private let accent = UIColor(red: 0.92, green: 0.32, blue: 0.18, alpha: 1.0)
    private let dimText = UIColor.white.withAlphaComponent(0.5)
    
    // MARK: - UI
    
    private let handleBar = UIView()
    private let titleLabel = UILabel()
    private let brandSegment: UIScrollView
    private let brandStack = UIStackView()
    private let cameraCollectionView: UICollectionView
    
    // MARK: - Init
    
    init(currentCameraID: String? = nil) {
        self.selectedCameraID = currentCameraID
        self.brandSegment = UIScrollView()
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        self.cameraCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        super.init(nibName: nil, bundle: nil)
        
        // Build brand → camera map
        let allCameras = CinemaCameraDatabase.allCameras
        for camera in allCameras {
            camerasByBrand[camera.brand, default: []].append(camera)
        }
        allBrands = Array(camerasByBrand.keys).sorted { $0.rawValue < $1.rawValue }
        
        // Select brand of current camera
        if let currentID = currentCameraID,
           let current = allCameras.first(where: { $0.id == currentID }),
           let idx = allBrands.firstIndex(of: current.brand) {
            selectedBrandIndex = idx
        }
        
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberIndicator = false
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
        setupBrandTabs()
        setupCameraGrid()
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
        titleLabel.text = "CAMERA BODY"
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
    
    private func setupBrandTabs() {
        brandSegment.showsHorizontalScrollIndicator = false
        brandSegment.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(brandSegment)
        
        brandStack.axis = .horizontal
        brandStack.spacing = 6
        brandStack.alignment = .center
        brandStack.translatesAutoresizingMaskIntoConstraints = false
        brandSegment.addSubview(brandStack)
        
        for (idx, brand) in allBrands.enumerated() {
            let btn = UIButton(type: .system)
            var config = UIButton.Configuration.filled()
            config.attributedTitle = AttributedString(
                brand.rawValue,
                attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 12, weight: .bold)])
            )
            config.baseBackgroundColor = idx == selectedBrandIndex
                ? accent : UIColor.white.withAlphaComponent(0.06)
            config.baseForegroundColor = idx == selectedBrandIndex
                ? .white : dimText
            config.cornerStyle = .capsule
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            btn.configuration = config
            btn.tag = idx
            btn.addTarget(self, action: #selector(brandTapped(_:)), for: .touchUpInside)
            brandStack.addArrangedSubview(btn)
        }
        
        NSLayoutConstraint.activate([
            brandSegment.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 14),
            brandSegment.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            brandSegment.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            brandSegment.heightAnchor.constraint(equalToConstant: 40),
            
            brandStack.leadingAnchor.constraint(equalTo: brandSegment.contentLayoutGuide.leadingAnchor),
            brandStack.trailingAnchor.constraint(equalTo: brandSegment.contentLayoutGuide.trailingAnchor),
            brandStack.topAnchor.constraint(equalTo: brandSegment.contentLayoutGuide.topAnchor),
            brandStack.bottomAnchor.constraint(equalTo: brandSegment.contentLayoutGuide.bottomAnchor),
            brandStack.heightAnchor.constraint(equalTo: brandSegment.frameLayoutGuide.heightAnchor)
        ])
    }
    
    private func setupCameraGrid() {
        cameraCollectionView.backgroundColor = .clear
        cameraCollectionView.delegate = self
        cameraCollectionView.dataSource = self
        cameraCollectionView.register(CameraBodyCell.self, forCellWithReuseIdentifier: "BodyCell")
        cameraCollectionView.translatesAutoresizingMaskIntoConstraints = false
        cameraCollectionView.showsVerticalScrollIndicator = false
        view.addSubview(cameraCollectionView)
        
        NSLayoutConstraint.activate([
            cameraCollectionView.topAnchor.constraint(equalTo: brandSegment.bottomAnchor, constant: 14),
            cameraCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            cameraCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            cameraCollectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func brandTapped(_ sender: UIButton) {
        selectedBrandIndex = sender.tag
        
        // Update tab appearance
        for (idx, view) in brandStack.arrangedSubviews.enumerated() {
            guard let btn = view as? UIButton, var config = btn.configuration else { continue }
            config.baseBackgroundColor = idx == selectedBrandIndex
                ? accent : UIColor.white.withAlphaComponent(0.06)
            config.baseForegroundColor = idx == selectedBrandIndex
                ? .white : dimText
            btn.configuration = config
        }
        
        cameraCollectionView.reloadData()
        UISelectionFeedbackGenerator().selectionChanged()
    }
    
    // MARK: - Data
    
    private var currentBrandCameras: [CinemaCameraBody] {
        guard selectedBrandIndex < allBrands.count else { return [] }
        return camerasByBrand[allBrands[selectedBrandIndex]] ?? []
    }
}

// MARK: - UICollectionView

extension CinemaCameraBodyPicker: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return currentBrandCameras.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "BodyCell", for: indexPath) as! CameraBodyCell
        let camera = currentBrandCameras[indexPath.item]
        let isSelected = camera.id == selectedCameraID
        cell.configure(camera: camera, isSelected: isSelected, accent: accent)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let camera = currentBrandCameras[indexPath.item]
        selectedCameraID = camera.id
        collectionView.reloadData()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onCameraSelected?(camera)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width - 8) / 2
        return CGSize(width: width, height: 110)
    }
}

// MARK: - CameraBodyCell

private final class CameraBodyCell: UICollectionViewCell {
    
    private let nameLabel = UILabel()
    private let sensorLabel = UILabel()
    private let resLabel = UILabel()
    private let drLabel = UILabel()
    private let sensorDiagram = SensorSizeDiagram()
    private let bg = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        bg.layer.cornerRadius = 14
        bg.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bg)
        
        nameLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        nameLabel.textColor = .white
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)
        
        sensorLabel.font = UIFont.systemFont(ofSize: 9, weight: .medium)
        sensorLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sensorLabel)
        
        resLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)
        resLabel.textColor = UIColor.white.withAlphaComponent(0.4)
        resLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(resLabel)
        
        drLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)
        drLabel.textColor = UIColor.white.withAlphaComponent(0.4)
        drLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(drLabel)
        
        sensorDiagram.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sensorDiagram)
        
        NSLayoutConstraint.activate([
            bg.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bg.topAnchor.constraint(equalTo: contentView.topAnchor),
            bg.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: sensorDiagram.leadingAnchor, constant: -8),
            
            sensorLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            sensorLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            
            resLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            resLabel.topAnchor.constraint(equalTo: sensorLabel.bottomAnchor, constant: 2),
            
            drLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            drLabel.topAnchor.constraint(equalTo: resLabel.bottomAnchor, constant: 2),
            
            sensorDiagram.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            sensorDiagram.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            sensorDiagram.widthAnchor.constraint(equalToConstant: 44),
            sensorDiagram.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(camera: CinemaCameraBody, isSelected: Bool, accent: UIColor) {
        nameLabel.text = camera.name
        sensorLabel.text = camera.sensor.format.rawValue
        sensorLabel.textColor = isSelected ? accent : UIColor.white.withAlphaComponent(0.5)
        resLabel.text = "\(camera.nativeResolution.width)×\(camera.nativeResolution.height)"
        drLabel.text = "\(camera.dynamicRange)+ stops DR"
        
        sensorDiagram.configure(
            width: camera.sensor.sensorWidth,
            height: camera.sensor.sensorHeight,
            accent: isSelected ? accent : UIColor.white.withAlphaComponent(0.2)
        )
        
        bg.backgroundColor = isSelected
            ? accent.withAlphaComponent(0.15)
            : UIColor.white.withAlphaComponent(0.04)
        bg.layer.borderWidth = isSelected ? 1 : 0
        bg.layer.borderColor = isSelected ? accent.withAlphaComponent(0.4).cgColor : nil
    }
}

// MARK: - SensorSizeDiagram

/// Tiny visual representation of sensor dimensions relative to full-frame.
private final class SensorSizeDiagram: UIView {
    
    private let sensorRect = CAShapeLayer()
    private let ffRect = CAShapeLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        ffRect.strokeColor = UIColor.white.withAlphaComponent(0.1).cgColor
        ffRect.fillColor = nil
        ffRect.lineWidth = 0.5
        ffRect.lineDashPattern = [2, 2]
        layer.addSublayer(ffRect)
        
        sensorRect.fillColor = nil
        sensorRect.lineWidth = 1.5
        layer.addSublayer(sensorRect)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(width: Float, height: Float, accent: UIColor) {
        sensorRect.strokeColor = accent.cgColor
        setNeedsLayout()
        
        // Store for layout
        objc_setAssociatedObject(self, "sw", width, .OBJC_ASSOCIATION_COPY)
        objc_setAssociatedObject(self, "sh", height, .OBJC_ASSOCIATION_COPY)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let sw = (objc_getAssociatedObject(self, "sw") as? Float) ?? 36.0
        let sh = (objc_getAssociatedObject(self, "sh") as? Float) ?? 24.0
        
        // Full-frame reference (36×24mm) at full bounds
        let ffPath = UIBezierPath(roundedRect: bounds, cornerRadius: 2)
        ffRect.path = ffPath.cgPath
        ffRect.frame = bounds
        
        // Sensor scaled relative to full-frame
        let scaleW = CGFloat(sw / 36.0)
        let scaleH = CGFloat(sh / 24.0)
        let sW = bounds.width * scaleW
        let sH = bounds.height * scaleH
        let sX = (bounds.width - sW) / 2
        let sY = (bounds.height - sH) / 2
        
        let sPath = UIBezierPath(roundedRect: CGRect(x: sX, y: sY, width: sW, height: sH), cornerRadius: 1.5)
        sensorRect.path = sPath.cgPath
        sensorRect.frame = bounds
    }
}
