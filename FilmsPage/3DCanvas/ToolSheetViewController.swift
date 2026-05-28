import UIKit
import PhotosUI

class ToolSheetViewController: UIViewController {

    let tool: ToolType
    let onSelect: (SpawnItem) -> Void

    private let titleLabel = UILabel()
    private let collectionView: UICollectionView
    private var importCoordinator: PropImportCoordinator?

    private lazy var noSkyImage: UIImage = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 226, height: 170))
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: CGSize(width: 226, height: 170))
            let colors = [
                UIColor(red: 30/255, green: 30/255, blue: 45/255, alpha: 1).cgColor,
                UIColor(red: 15/255, green: 15/255, blue: 25/255, alpha: 1).cgColor
            ] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) else { return }
            ctx.cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 170), options: [])
            
            ctx.cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.15).cgColor)
            ctx.cgContext.setLineWidth(1)
            let path = UIBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 10)
            ctx.cgContext.addPath(path.cgPath)
            ctx.cgContext.strokePath()
            
            if let symbol = UIImage(systemName: "xmark.circle.fill")?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                let symbolSize = CGSize(width: 50, height: 50)
                let symbolRect = CGRect(
                    x: (226 - symbolSize.width) / 2,
                    y: (170 - symbolSize.height) / 2,
                    width: symbolSize.width,
                    height: symbolSize.height
                )
                symbol.draw(in: symbolRect)
            }
        }
    }()

    // ── Grip segment support (Light modal only) ──────────────────────────
    private var segmentedControl: UISegmentedControl?
    private var gripItems: [GripItem] = []
    private let userDefaultsSegmentKey = "lightModalLastSegment"

    /// Represents a single reflector or diffuser card in the Grip tab.
    struct GripItem {
        enum Kind {
            case reflector(SceneReflectorType)
            case diffuser(DiffuserType)
        }
        let kind: Kind
        var displayName: String {
            switch kind {
            case .reflector(let t): return t.displayName
            case .diffuser(let t):  return t.displayName
            }
        }
        var iconName: String {
            switch kind {
            case .reflector(let t): return t.iconName
            case .diffuser(let t):  return t.iconName
            }
        }
        var swatchColor: UIColor {
            switch kind {
            case .reflector(let t): return t.swatchColor
            case .diffuser(let t):  return t.swatchColor
            }
        }
    }

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
        view.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 22/255, alpha: 1)

        setupTitle()
        setupCollection()

        // Light tool: add Sources/Grip segmented control
        if tool == .light {
            buildGripItems()
            setupSegmentedControl()
        }



        // Show Plus button for Background and Prop tools
        if tool == .background || tool == .prop {
            setupPlusButton()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(handlePropsUpdated), name: NSNotification.Name(NotificationNames.propsUpdated), object: nil)
    }

    @objc private func handlePropsUpdated() {
        self.collectionView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NotificationCenter.default.post(
            name: .onboardingVCAppeared,
            object: nil,
            userInfo: ["vcType": "toolSheet"]
        )
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
        }, completion: nil)
    }

    func setupTitle() {
        titleLabel.text = tool.title
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = .white
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

        // Offset the collection view top based on tool:
        //  - .light  → 60pt (segment control)
        //  - others  → 20pt
        let topOffset: CGFloat = {
            if tool == .light { return 60 }
            return 20
        }()

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: topOffset),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }



    // MARK: - Grip / Segmented Control (Light modal only)

    /// Builds the data source for the Grip tab.
    private func buildGripItems() {
        gripItems = SceneReflectorType.allCases.map { GripItem(kind: .reflector($0)) }
                  + DiffuserType.allCases.map { GripItem(kind: .diffuser($0)) }
    }

    /// Adds a Sources / Grip segmented control between the title and collection view.
    private func setupSegmentedControl() {
        let sc = UISegmentedControl(items: ["Sources", "Grip"])
        sc.translatesAutoresizingMaskIntoConstraints = false
        sc.selectedSegmentTintColor = UIColor(red: 90/255, green: 130/255, blue: 255/255, alpha: 1)
        sc.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        sc.setTitleTextAttributes([.foregroundColor: UIColor.lightGray], for: .normal)
        sc.backgroundColor = UIColor(white: 0.15, alpha: 1)

        // Restore last segment
        let lastSegment = UserDefaults.standard.integer(forKey: userDefaultsSegmentKey)
        sc.selectedSegmentIndex = min(lastSegment, 1)

        sc.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
        view.addSubview(sc)

        NSLayoutConstraint.activate([
            sc.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            sc.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            sc.widthAnchor.constraint(equalToConstant: 240),
            sc.heightAnchor.constraint(equalToConstant: 32)
        ])

        segmentedControl = sc

        // If restoring to Grip tab, reload immediately
        if sc.selectedSegmentIndex == 1 {
            collectionView.reloadData()
        }
    }

    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        UserDefaults.standard.set(sender.selectedSegmentIndex, forKey: userDefaultsSegmentKey)
        collectionView.reloadData()
    }

    func setupPlusButton() {
        let plusButton = UIButton(type: .system)

        if tool == .prop {
            plusButton.setImage(UIImage(systemName: "plus"), for: .normal)
        } else {
            let largeConfig = UIImage.SymbolConfiguration(pointSize: 44, weight: .light, scale: .default)
            plusButton.setImage(UIImage(systemName: "plus.circle.fill", withConfiguration: largeConfig), for: .normal)
        }

        plusButton.tintColor = tool == .prop ? UIColor(named: "AccentColor") ?? .systemBlue : .label
        plusButton.translatesAutoresizingMaskIntoConstraints = false

        // Logic to open picker
        plusButton.addAction(UIAction { [weak self] _ in
            if self?.tool == .background {
                self?.presentBackgroundImagePicker()
            } else if self?.tool == .prop {
                self?.presentPropImportPicker()
            }
        }, for: .touchUpInside)

        view.addSubview(plusButton)

        NSLayoutConstraint.activate([
            plusButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            plusButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            plusButton.widthAnchor.constraint(equalToConstant: 60),
            plusButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }

    func presentPropImportPicker() {
        let coordinator = PropImportCoordinator()
        self.importCoordinator = coordinator
        coordinator.start(presentingViewController: self)
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
        if tool == .light, segmentedControl?.selectedSegmentIndex == 1 {
            return gripItems.count
        }
        return tool.items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        // Grip tab: use grip-specific cell
        if tool == .light, segmentedControl?.selectedSegmentIndex == 1 {
            return gripCell(for: indexPath, in: collectionView)
        }

        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ToolCell", for: indexPath) as? ToolCell else {
            return UICollectionViewCell()
        }

        let item = tool.items[indexPath.item]

        cell.configure(with: item)

        if tool == .sky, item.modelFileName == "none" {
            cell.imageView.image = noSkyImage
        } else if let customImage = item.customImage {
            cell.imageView.image = customImage
        }

        return cell
    }

    /// Cell for Grip tab items (reflectors/diffusers).
    private func gripCell(for indexPath: IndexPath, in collectionView: UICollectionView) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ToolCell", for: indexPath) as! ToolCell
        let grip = gripItems[indexPath.item]

        // Re-use ToolCell but configure with grip-specific display
        let fakeItem = SpawnItem(
            title: grip.displayName,
            imageName: grip.iconName,
            modelFileName: ""
        )
        cell.configure(with: fakeItem)

        // Override image with a colored swatch
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120))
        let swatchImage = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: CGSize(width: 120, height: 120))
            ctx.cgContext.setFillColor(UIColor(red: 11/255, green: 11/255, blue: 22/255, alpha: 1).cgColor)
            ctx.cgContext.fill(rect)

            // Draw swatch circle
            let circleRect = rect.insetBy(dx: 25, dy: 25)
            ctx.cgContext.setFillColor(grip.swatchColor.cgColor)
            ctx.cgContext.fillEllipse(in: circleRect)

            // Draw border
            ctx.cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.3).cgColor)
            ctx.cgContext.setLineWidth(2)
            ctx.cgContext.strokeEllipse(in: circleRect)
        }
        cell.imageView.image = swatchImage

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        // Grip tab: spawn reflector or diffuser
        if tool == .light, segmentedControl?.selectedSegmentIndex == 1 {
            let grip = gripItems[indexPath.item]
            // Capture VC reference before dismiss — presentingViewController is nil in completion
            guard let canvasVC = self.presentingViewController as? CanvasViewController
                    ?? (self.presentingViewController as? UINavigationController)?.viewControllers.first(where: { $0 is CanvasViewController }) as? CanvasViewController
            else { return }
            dismiss(animated: true) {
                switch grip.kind {
                case .reflector(let type): canvasVC.spawnReflector(type: type)
                case .diffuser(let type):  canvasVC.spawnDiffuser(type: type)
                }
            }
            return
        }

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
            let detailVC = CharacterDetailViewController(item: item) { (selectedItem: SpawnItem) in
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

        provider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
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
