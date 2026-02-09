import UIKit
import PhotosUI

class ToolSheetViewController: UIViewController {

    let tool: ToolType
    let onSelect: (SpawnItem) -> Void

    private let titleLabel = UILabel()
    private let collectionView: UICollectionView

    init(tool: ToolType, onSelect: @escaping (SpawnItem) -> Void) {
        self.tool = tool
        self.onSelect = onSelect

        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 30
        layout.itemSize = CGSize(width: 242, height: 242)
        layout.sectionInset = UIEdgeInsets(top: 20, left: 50, bottom: 20, right: 50)

        self.collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )

        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 11/255, green:  11/255, blue: 22/255, alpha: 1)

        setupTitle()
        setupCollection()

        // Only show Plus button for Background tool
        if tool == .background {
            setupPlusButton()
        }
    }

    func setupTitle() {
        titleLabel.text = tool.title
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    func setupCollection() {
        collectionView.backgroundColor = .clear
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        // Register your existing ToolCell
        collectionView.register(ToolCell.self, forCellWithReuseIdentifier: "ToolCell")
        
        collectionView.dataSource = self
        collectionView.delegate = self

        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    func setupPlusButton() {
        let plusButton = UIButton(type: .system)
        
        let largeConfig = UIImage.SymbolConfiguration(pointSize: 44, weight: .light, scale: .default)
        
        plusButton.setImage(UIImage(systemName: "plus.circle.fill", withConfiguration: largeConfig), for: .normal)
        
        plusButton.tintColor = .label
        plusButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Logic to open picker
        plusButton.addAction(UIAction { [weak self] _ in
            self?.presentBackgroundImagePicker()
        }, for: .touchUpInside)

        view.addSubview(plusButton)

        NSLayoutConstraint.activate([
            plusButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            plusButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            plusButton.widthAnchor.constraint(equalToConstant: 60),
            plusButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    func presentBackgroundImagePicker() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
}

// MARK: - Collection View DataSource & Delegate
extension ToolSheetViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return tool.items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ToolCell", for: indexPath) as! ToolCell
        
        let item = tool.items[indexPath.item]
        
        cell.configure(with: item)
        
        if let customImage = item.customImage {
            cell.imageView.image = customImage
        }
        
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let item = tool.items[indexPath.item]

        // 1. Handle Background Logic
        if tool == .background {
            // FIX: Only call onSelect.
            // Do NOT call BackgroundStore.shared.selectBackground(item) here,
            // because onSelect already triggers the spawn via the Canvas.
            
            onSelect(item)
            
            dismiss(animated: true)
            return
        }

        // 2. Handle Character Logic
        if tool == .character {
            let detailVC = CharacterDetailViewController(item: item){
                (selectedItem: SpawnItem) in
                self.onSelect(selectedItem)
                self.dismiss(animated: true)
            }
            if let canvasVC = self.presentingViewController as? CanvasViewController {
                detailVC.delegate = canvasVC
            }
            if let sheet = detailVC.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
            }
            present(detailVC, animated: true)
            return
        }

        // 3. Handle Props/Lights/etc
        onSelect(item)
        dismiss(animated: true)
    }
}

// MARK: - PHPicker Delegate
extension ToolSheetViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }

        provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
            guard let self = self, let uiImage = image as? UIImage else { return }
            
            DispatchQueue.main.async {
                self.handleNewBackgroundImage(uiImage)
            }
        }
    }
    
    func handleNewBackgroundImage(_ image: UIImage) {
        let alert = UIAlertController(title: "Name your Background",
                                      message: "Enter a name for this image",
                                      preferredStyle: .alert)
        
        alert.addTextField { $0.placeholder = "Background Name" }
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let name = alert.textFields?.first?.text ?? "New Background"
            
            // Create and Add to Store
            let newItem = BackgroundItem(title: name, imageName: nil, customImage: image)
            BackgroundStore.shared.addBackground(newItem)
            
            // Reload UI
            self.collectionView.reloadData()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(saveAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
}
