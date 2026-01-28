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
        view.backgroundColor = .systemBackground

        setupTitle()
        setupCollection()

        if tool == .background {
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
        // Fetch items directly from your DataStore extension on ToolType
        if tool == .background {
            // Combine default backgrounds + user imported ones
            return tool.items.count + BackgroundStore.shared.images.count
        }
        return tool.items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ToolCell", for: indexPath) as! ToolCell
        
        // Logic to handle user-imported backgrounds vs standard items
        if tool == .background {
            // Standard items come first
            if indexPath.item < tool.items.count {
                let item = tool.items[indexPath.item]
                cell.configure(with: item)
            } else {
                // User imported images
                let imageIndex = indexPath.item - tool.items.count
                let image = BackgroundStore.shared.images[imageIndex]
                cell.imageView.image = image
                cell.label.text = "Background \(imageIndex + 1)"
            }
        } else {
            // Standard behavior for Characters, Props, Lights, etc.
            let item = tool.items[indexPath.item]
            cell.configure(with: item)
        }
        
        return cell
    }

  

    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        // 1. Handle Background Logic
        if tool == .background {

            var selectedImage: UIImage?

            if indexPath.item < tool.items.count {

                let item = tool.items[indexPath.item]
                selectedImage = UIImage(named: item.imageName)
            } else {
                // It's a user-imported background
                let imageIndex = indexPath.item - tool.items.count
                if imageIndex < BackgroundStore.shared.images.count {
                    selectedImage = BackgroundStore.shared.images[imageIndex]
                }
            }

            if let image = selectedImage {
                BackgroundStore.shared.selectImage(image)
            }
            
            dismiss(animated: true)
            return
        }

        // 2. Handle Character Logic
        if tool == .character {
            print("🔥 didSelectItemAt fired for tool:", tool)
            let item = tool.items[indexPath.item]
            let detailVC = CharacterDetailViewController(item: item){
                (selectedItem: SpawnItem) in
                print("Selecting", selectedItem)
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
//            onSelect(item)
            return
        }

        // 3. Handle Props/Lights/etc
        let item = tool.items[indexPath.item]
        print("Selecting props")
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
            if let uiImage = image as? UIImage {
                DispatchQueue.main.async {
                    // 1. Add to the list (Your existing code)
                    BackgroundStore.shared.images.append(uiImage)
                    
                    // 3. Reload UI
                    self?.collectionView.reloadData()
                }
            }
        }
    }
}
