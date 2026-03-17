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
    private var item: SpawnItem
    // Data source for the collection view
    private var poses: [SpawnPose] = [] // Changed from [String] to [SpawnPose]
    
    private var selectedPoseModelName: String
    private var currentScale: Float = 1.0
    
    //UI Constants
    private let accentColor = UIColor.systemBlue // Changed to Blue for Light Theme standard
    
    //UI Elements
    
    //Container
    private lazy var containerView: UIView = {
        let view = UIView()
        // Light Theme: Light Gray Card
        view.backgroundColor = UIColor(red: 20/255, green:  20/255, blue: 30/255, alpha: 1)
        view.layer.cornerRadius = 24
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let headerLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "Edit Character"
        lbl.font = UIFont.systemFont(ofSize: 28, weight: .bold) // Increased font size
        lbl.textColor = .white// Black in light mode
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    private lazy var addButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Add", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        btn.backgroundColor = UIColor(red: 177/255, green: 32/255, blue: 57/255, alpha: 1)
        btn.layer.cornerRadius = 18
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(didTapConfirm), for: .touchUpInside)
        return btn
    }()
    
    private lazy var characterImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.image = UIImage(named: item.imageName ?? "")
        iv.backgroundColor = .systemBackground // White bg for image
        iv.layer.cornerRadius = 16
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    
    // Name Input
    private lazy var nameLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "Character Name"
        lbl.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        lbl.textColor = .white // Dark Gray
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
        lbl.textColor = .white
        return lbl
    }()
    
    private let heightValueLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "170 cms"
        lbl.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        lbl.textColor = .white
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
        lbl.textColor = .white
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
    var onSelectModel:(_ item: SpawnItem) -> Void
    // MARK: - Init
    init(item: SpawnItem, onSelectModel: @escaping (_ item: SpawnItem) -> Void) {
        self.item = item
        // Load the rich pose data
        self.poses = item.poses ?? []

        // Default selection
        if let firstPose = self.poses.first {
            self.selectedPoseModelName = firstPose.modelFileName
        } else {
            self.selectedPoseModelName = item.modelFileName
        }
        self.onSelectModel = onSelectModel

        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Light Theme Background
        view.backgroundColor = UIColor(red: 11/255, green:  11/255, blue: 22/255, alpha: 1)
        
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

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.posesCollectionView.collectionViewLayout.invalidateLayout()
        })
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
            posesTitleLabel.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 26),
            posesTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            
            // Poses Collection
            posesCollectionView.topAnchor.constraint(equalTo: posesTitleLabel.bottomAnchor, constant: 12),
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
    

//    @objc private func didTapConfirm() {
//        guard let name = nameTextField.text, !name.isEmpty else { return }
//        
//        // 1. Create a COPY of the item
//        var finalItem = self.item
//        
//        // 2. IMPORTANT: Overwrite the model name with the user's selection
//        // If you skip this, it will always spawn the default T-Pose/Standing model
//        finalItem.modelFileName = selectedPoseModelName
//        
//        // 3. Send to delegate
//        delegate?.didConfirmCharacterSelection(item: finalItem, scale: currentScale, name: name)
//    }
    @objc private func didTapConfirm() {
        guard let name = nameTextField.text, !name.isEmpty else { return }
        
        // 1. Prepare final item selection
        var finalItem = self.item
        finalItem.modelFileName = selectedPoseModelName
        
        // 2. Notify the canvas to spawn the character
        delegate?.didConfirmCharacterSelection(item: finalItem, scale: currentScale, name: name)
        
        // 3. Trigger secondary closure logic
        self.onSelectModel(finalItem)
        
        // 4. 📍 THE FIX: Dismiss both modals
        // Calling dismiss on presentingViewController closes the chain
        self.presentingViewController?.presentingViewController?.dismiss(animated: true)
    }
}

// MARK: - Collection View Data Source & Delegate
extension CharacterDetailViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return poses.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PoseCell.reuseID, for: indexPath) as? PoseCell else { return UICollectionViewCell() }

        let pose = poses[indexPath.item]

        // Use the specific image name for this pose
        // If that fails, fallback to main item image
        let image = UIImage(named: pose.imageName) ?? UIImage(named: item.imageName ?? "")

        cell.configure(image: image, title: pose.title)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedPose = poses[indexPath.item]
        
        // 1. Update the tracking variable to the new model filename
        self.selectedPoseModelName = selectedPose.modelFileName
        
        // 2. Sync the internal item state for the preview
        self.item.modelFileName = selectedPose.modelFileName
        self.item.selectedPose = selectedPose.modelFileName
        
        // 3. Update the preview image on the left side of the container
        if let poseImage = UIImage(named: selectedPose.imageName) {
            characterImageView.image = poseImage
            
        }
         print("Pose selection updated to: \(selectedPose.modelFileName). Press 'Add' to confirm.")
    }
}
