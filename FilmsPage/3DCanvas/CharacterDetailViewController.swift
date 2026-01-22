//
//  CharacterDetailViewController.swift
//  3DCanvas
//
//  Created by SDC-USER on 20/01/26.
//

import UIKit

// Protocol to send the final configuration back to CanvasViewController
protocol CharacterDetailDelegate: AnyObject {
    func didConfirmCharacterSelection(item: SpawnItem, scale: Float, name: String)
}

class CharacterDetailViewController: UIViewController {
    
    //Properties
    weak var delegate: CharacterDetailDelegate?
    private let item: SpawnItem
    
    private var selectedPoseModelName: String
    private var currentScale: Float = 1.0
    
    // Data source for the collection view
    private var poses: [String] = []
    
    //UI Constants
    private let accentColor = UIColor.systemBlue // Changed to Blue for Light Theme standard
    
    //UI Elements
    
    //Container
    private lazy var containerView: UIView = {
        let view = UIView()
        // Light Theme: Light Gray Card
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 24
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let headerLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "Edit Character"
        lbl.font = UIFont.systemFont(ofSize: 28, weight: .bold) // Increased font size
        lbl.textColor = .label // Black in light mode
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    private lazy var addButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Add", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        btn.backgroundColor = accentColor
        btn.layer.cornerRadius = 18
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(didTapConfirm), for: .touchUpInside)
        return btn
    }()
    
    // --- Top Section: Image ---
    private lazy var characterImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.image = UIImage(named: item.imageName)
        iv.backgroundColor = .systemBackground // White bg for image
        iv.layer.cornerRadius = 16
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    // --- Top Section: Controls ---
    
    // Name Input
    private lazy var nameLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "Character Name"
        lbl.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        lbl.textColor = .secondaryLabel // Dark Gray
        return lbl
    }()
    
    private lazy var nameTextField: UITextField = {
            let tf = UITextField()
            tf.text = item.title
            tf.font = UIFont.systemFont(ofSize: 22, weight: .bold)
            tf.textColor = .label
            tf.borderStyle = .roundedRect // Visibly editable
            tf.backgroundColor = .systemBackground
            tf.returnKeyType = .done
            tf.translatesAutoresizingMaskIntoConstraints = false
            return tf
        }()

    // Height Slider
    private let heightLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "Height"
        lbl.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        lbl.textColor = .label
        return lbl
    }()
    
    private let heightValueLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "170 cms"
        lbl.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        lbl.textColor = .secondaryLabel
        lbl.textAlignment = .right
        return lbl
    }()
    
    private lazy var scaleSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0.5
        slider.maximumValue = 2.0
        slider.value = 1.0
        slider.thumbTintColor = .white
        slider.minimumTrackTintColor = accentColor
        slider.maximumTrackTintColor = .systemGray4
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        return slider
    }()
    
    // --- Bottom Section: Poses ---
    private let posesTitleLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "Character Poses"
        lbl.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        lbl.textColor = .label
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    private lazy var posesCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 110, height: 140) // Slightly larger cards
        layout.minimumInteritemSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.register(PoseCell.self, forCellWithReuseIdentifier: PoseCell.reuseID)
        cv.dataSource = self
        cv.delegate = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()
    
    // MARK: - Init
    init(item: SpawnItem) {
        self.item = item
        if let firstPose = item.poses?.first {
            self.poses = item.poses ?? []
            self.selectedPoseModelName = firstPose
        } else {
            self.poses = []
            self.selectedPoseModelName = item.modelFileName
        }
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Light Theme Background
        view.backgroundColor = .systemBackground
        
        // Force Large Sheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        
        setupUI()
        
        if !poses.isEmpty {
            posesCollectionView.selectItem(at: IndexPath(item: 0, section: 0), animated: false, scrollPosition: .left)
        }
    }
    
    // MARK: - Setup UI
    private func setupUI() {
        view.addSubview(containerView)
        
        containerView.addSubview(headerLabel)
        containerView.addSubview(addButton)
        containerView.addSubview(characterImageView)
        
        // Stack for Name and Height (Right Side)
        let controlsStack = UIStackView()
        controlsStack.axis = .vertical
        controlsStack.spacing = 30 // Increased spacing since colors are gone
        controlsStack.distribution = .fill
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Name Section
        let nameStack = UIStackView(arrangedSubviews: [nameLabel, nameTextField])
        nameStack.axis = .vertical
        nameStack.spacing = 8
        
        // Slider Section
        let sliderContainer = UIView()
        sliderContainer.translatesAutoresizingMaskIntoConstraints = false
        sliderContainer.heightAnchor.constraint(equalToConstant: 60).isActive = true
        
        let sliderLabelStack = UIStackView(arrangedSubviews: [heightLabel, heightValueLabel])
        sliderLabelStack.axis = .horizontal
        sliderLabelStack.distribution = .fill
        
        let sliderFullStack = UIStackView(arrangedSubviews: [sliderLabelStack, scaleSlider])
        sliderFullStack.axis = .vertical
        sliderFullStack.spacing = 10
        sliderFullStack.translatesAutoresizingMaskIntoConstraints = false
        
        sliderContainer.addSubview(sliderFullStack)
        
        // Add to main controls stack
        controlsStack.addArrangedSubview(nameStack)
        controlsStack.addArrangedSubview(sliderContainer)
        
        // Add spacer to push content up/center
        controlsStack.addArrangedSubview(UIView())
        
        containerView.addSubview(controlsStack)
        
        // Poses
        view.addSubview(posesTitleLabel)
        view.addSubview(posesCollectionView)
        
        NSLayoutConstraint.activate([
            // Container (Edit Character Card) - INCREASED HEIGHT
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            containerView.heightAnchor.constraint(equalToConstant: 400), // Height Increased
            
            // Header
            headerLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            headerLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            
            // Add Button
            addButton.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor),
            addButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            addButton.widthAnchor.constraint(equalToConstant: 90),
            addButton.heightAnchor.constraint(equalToConstant: 36),
            
            // Image (Left) - Bigger now
            characterImageView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 24),
            characterImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            characterImageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
            characterImageView.widthAnchor.constraint(equalTo: characterImageView.heightAnchor, multiplier: 0.75),
            
            // Controls Stack (Right)
            controlsStack.topAnchor.constraint(equalTo: characterImageView.topAnchor, constant: 20), // Align slightly below image top
            controlsStack.leadingAnchor.constraint(equalTo: characterImageView.trailingAnchor, constant: 24),
            controlsStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            controlsStack.bottomAnchor.constraint(equalTo: characterImageView.bottomAnchor),
            
            // Slider Internal Layout
            sliderFullStack.leadingAnchor.constraint(equalTo: sliderContainer.leadingAnchor),
            sliderFullStack.trailingAnchor.constraint(equalTo: sliderContainer.trailingAnchor),
            sliderFullStack.centerYAnchor.constraint(equalTo: sliderContainer.centerYAnchor),
            
            // Poses Header
            posesTitleLabel.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 30),
            posesTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            
            // Poses Collection
            posesCollectionView.topAnchor.constraint(equalTo: posesTitleLabel.bottomAnchor, constant: 16),
            posesCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            posesCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            posesCollectionView.heightAnchor.constraint(equalToConstant: 160)
        ])
    }
    
    // MARK: - Actions
    @objc private func sliderValueChanged(_ sender: UISlider) {
        currentScale = sender.value
        let approxHeightCm = Int(170 * currentScale)
        heightValueLabel.text = "\(approxHeightCm) cms"
    }
    
    @objc private func didTapConfirm() {
            // Use the text from the field, or fallback to the original title
            let finalName = nameTextField.text ?? item.title
            
            // Pass the item, scale, AND name back to CanvasViewController
            delegate?.didConfirmCharacterSelection(item: item, scale: currentScale, name: finalName)
            
            self.presentingViewController?.presentingViewController?.dismiss(animated: true, completion: nil)
        }
}

// MARK: - Collection View Data Source & Delegate
extension CharacterDetailViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return poses.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PoseCell.reuseID, for: indexPath) as? PoseCell else { return UICollectionViewCell() }
        
        let poseName = poses[indexPath.item]
        let image = UIImage(named: poseName) ?? UIImage(named: item.imageName)
        
        cell.configure(image: image, title: poseName)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedPoseModelName = poses[indexPath.item]
        print("Selected pose: \(selectedPoseModelName)")
    }
}
