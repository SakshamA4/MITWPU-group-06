import Combine
import PhotosUI
import RealityKit
import UIKit
import ARKit

extension CanvasViewController {

    func setupTopControlsUI() {
        // 1. Add Breakdown button
        view.addSubview(shotBreakdownBtn)

        // 2. Re-anchor Play Button from the old stack
        view.addSubview(playButton)
        playButton.translatesAutoresizingMaskIntoConstraints = false

        // 3. Style Play Button to match Breakdown/Layers style
        playButton.backgroundColor = UIColor(
            red: 11 / 255,
            green: 11 / 255,
            blue: 22 / 255,
            alpha: 1
        )
        playButton.tintColor = .white
        playButton.layer.cornerRadius = 22
        playButton.clipsToBounds = false

        NSLayoutConstraint.activate([
            shotBreakdownBtn.centerYAnchor.constraint(
                equalTo: layersButton.centerYAnchor
            ),
            shotBreakdownBtn.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -16
            ),
            shotBreakdownBtn.widthAnchor.constraint(equalToConstant: 44),
            shotBreakdownBtn.heightAnchor.constraint(equalToConstant: 44),

            playButton.centerYAnchor.constraint(
                equalTo: layersButton.centerYAnchor
            ),
            playButton.trailingAnchor.constraint(
                equalTo: shotBreakdownBtn.leadingAnchor,
                constant: -16
            ),
            playButton.widthAnchor.constraint(equalToConstant: 44),
            playButton.heightAnchor.constraint(equalToConstant: 44),
        ])

        shotBreakdownBtn.addTarget(
            self,
            action: #selector(shotBreakdownTapped),
            for: .touchUpInside
        )
    }

    
    
    
    private func setupNavigationBar() {

        self.navigationItem.title = self.sceneName

        // 1. Back Button Logic
        
        // This creates a custom back button that pops the view controller
        let backButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(backButtonTapped)
        )
        
        // 2. Undo & Redo (Moved beside the back button)
        let undoBtn = UIBarButtonItem(
            image: UIImage(systemName: "arrow.uturn.backward"),
            style: .plain,
            target: self,
            action: #selector(undoTapped)
        )
        
        let redoBtn = UIBarButtonItem(
            image: UIImage(systemName: "arrow.uturn.forward"),
            style: .plain,
            target: self,
            action: #selector(redoTapped)
        )
        
        // Combine Back, Undo, Redo on the left
        navigationItem.leftBarButtonItems = [backButton, undoBtn, redoBtn]
        
        // 3. Right Side: Export and 3-Dots
        let exportBtn = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(exportTapped)  // Uses your existing export logic
        )
        
        let moreBtn = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            style: .plain,
            target: self,
            action: #selector(moreTapped)
        )
        
        navigationItem.rightBarButtonItems = [moreBtn, exportBtn]
        
        // 4. Configure Appearance (Dark background like your image)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(
            red: 11 / 255,
            green: 11 / 255,
            blue: 22 / 255,
            alpha: 1
        )

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
        ]

        appearance.titleTextAttributes = titleAttributes  // 📍 Apply here
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = .systemBlue
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
        ]

    }

    
    @objc func moreTapped() {
        let infoVC = SceneInfoViewController()
        
        // Pass tracked data to the modal
        infoVC.sceneName = self.sceneName
        infoVC.sequenceName = self.sequenceName
        infoVC.filmName = self.filmName
        infoVC.initialNotes = self.sceneNotes
        infoVC.lastEditedDate = self.lastEditedDate
        if let imageName = self.sceneImageName {
            infoVC.sceneImage = UIImage(named: imageName)
        }
        
        infoVC.onSave = { [weak self] newName, newNotes in
            guard let self = self else { return }
            
            // 1. Update local UI state
            self.sceneName = newName
            self.sceneNotes = newNotes
            self.lastEditedDate = Date()
            self.sceneNameLabel.text = newName.uppercased()
            self.navigationItem.title = newName
            
            // 2. 📍 SAVE TO DATABASE: This now works because 'notes' is in ScenesModel
            if var sceneToUpdate = self.currentSceneObject {
                sceneToUpdate.name = newName
                sceneToUpdate.notes = newNotes
                
                // Use your service to save changes permanently
                SceneService.shared.updateScene(sceneToUpdate)
                
                // Update local reference
                self.currentSceneObject = sceneToUpdate
            }

            let updatedModel = ScenesModel(
                name: newName,
                image: self.sceneImageName ?? "Image",
                notes: newNotes
            )
            ScenesDataStore.shared.addToRecent(scene: updatedModel)
            
            NotificationCenter.default.post(
                name: NSNotification.Name("scenesUpdated"),
                object: nil
            )
        }
        
        // Snapshot logic
        arView.snapshot(saveToHDR: false) { image in
            infoVC.sceneImage = image
        }
        
        infoVC.modalPresentationStyle = .overCurrentContext
        infoVC.modalTransitionStyle = .crossDissolve
        self.present(infoVC, animated: true)
    }


    func presentToolSheet(tool: ToolType) {
        let sheet = ToolSheetViewController(tool: tool) { [weak self] item in
            self?.spawnEntity(item: item, toolType: tool)
        }
        present(sheet, animated: true)
    }

    
    @objc func toggleRotationMode(_ button: UIButton) {
        interactionMode = (interactionMode == .move) ? .rotate : .move

        button.backgroundColor =
            interactionMode == .rotate ? .systemOrange : .systemBlue

        // Immediately swap gizmo ↔ rings on the currently selected entity
        updateGizmoMode()
    }

    
    func makeIconToolbarButton(title: String, systemImage: String) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: systemImage)?
            .applyingSymbolConfiguration(
                UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            )
        config.imagePlacement = .top
        config.imagePadding = 2
        config.title = title
        config.baseForegroundColor = .label
        
        let button = UIButton(configuration: config)
        button.titleLabel?.font = .systemFont(ofSize: 10, weight: .medium)
        return button
    }

    
    func makeViewModeButton(title: String) -> UIButton {
        
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = .label
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 6,
            leading: 14,
            bottom: 6,
            trailing: 14
        )
        
        let button = UIButton(configuration: config)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        
        return button
    }

    func makeGrid(size: Int, spacing: Float) -> Entity {
        let container = Entity()
        let length = Float(size) * spacing * 2
        
        for i in -size...size {
            let isMajor = i % 5 == 0
            
            var xColor: UIColor =
            isMajor ? .gray : .lightGray.withAlphaComponent(0.8)
            var zColor: UIColor =
            isMajor ? .gray : .lightGray.withAlphaComponent(0.8)
            
            if i == 0 {
                xColor = .red
                zColor = .blue
            }
            
            let xLine = ModelEntity(
                mesh: .generateBox(size: [length, 0.002, 0.002]),
                materials: [SimpleMaterial(color: xColor, isMetallic: false)]
            )
            xLine.position = [0, 0, Float(i) * spacing]
            container.addChild(xLine)
            
            let zLine = ModelEntity(
                mesh: .generateBox(size: [0.002, 0.002, length]),
                materials: [SimpleMaterial(color: zColor, isMetallic: false)]
            )
            zLine.position = [Float(i) * spacing, 0, 0]
            container.addChild(zLine)
        }
        
        return container
    }

    func setEntityTransparency(_ entity: Entity?, alpha: Float) {
        guard let entity = entity else { return }

        // Recursively walk all descendants using native RealityKit .children
        func applyOpacity(to e: Entity) {
            if let model = e as? ModelEntity {
                var opacityComp = model.components[OpacityComponent.self] ?? OpacityComponent(opacity: 1.0)
                opacityComp.opacity = alpha
                model.components.set(opacityComp)
            }
            for child in e.children {
                applyOpacity(to: child)
            }
        }
        applyOpacity(to: entity)
    }

    func setLockTitle(isLocked: Bool) {
        // This finds the button labeled "Lock" or "Unlock" and updates it
        stackView.arrangedSubviews.compactMap { $0 as? UIButton }.forEach {
            btn in
            if btn.currentTitle == "Lock" || btn.currentTitle == "Unlock" {
                btn.setTitle(isLocked ? "Unlock" : "Lock", for: .normal)
            }
        }
    }


    private func addMenuButton(
        title: String,
        action: ActionType,
        isDestructive: Bool = false
    ) {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        btn.tintColor =
            isDestructive
            ? UIColor(red: 169 / 255, green: 32 / 255, blue: 57 / 255, alpha: 1)
            : .label
        btn.addAction(
            UIAction { [weak self] _ in self?.onAction?(action) },
            for: .touchUpInside
        )
        stackView.addArrangedSubview(btn)
    }


    @objc func didTapLayersButton() {
        if !isSidebarVisible {
            refreshSidebarContent()
        }
        
        isSidebarVisible.toggle()
        sidebarLeadingConstraint.constant = isSidebarVisible ? 0 : -sidebarWidth
        
        UIView.animate(withDuration: 0.2) {
            // Hide the layer button if sidebar is visible, show it if not
            self.layersButton.alpha = self.isSidebarVisible ? 0 : 1
            self.playbackButtonStack.alpha = self.isSidebarVisible ? 0 : 1
            self.playbackButtonStack.isHidden = self.isSidebarVisible
            self.view.layoutIfNeeded()
        }
    }


    
    func refreshSidebarContent() {
        hierarchyStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let allEntities = arView.scene.anchors.flatMap { $0.children }
        
        var itemsByCategory: [ToolType: [Entity]] = [:]
        ToolType.allCases.forEach { itemsByCategory[$0] = [] }
        
        for entity in allEntities {
            guard
                let category = entity.components[CategoryComponent.self]?
                    .toolType
            else { continue }
            
            itemsByCategory[category]?.append(entity)
        }
        
        for tool in ToolType.allCases {
            let entities = itemsByCategory[tool] ?? []
            let header = createHierarchyHeader(
                title: tool.hierarchyTitle,
                count: entities.count
            )
            hierarchyStackView.addArrangedSubview(header)
            
            for entity in entities {
                let row = createHierarchyItemRow(title: entity.name)
                hierarchyStackView.addArrangedSubview(row)
            }
        }
    }


    
    private func createHierarchyHeader(title: String, count: Int) -> UIView {
        let label = UILabel()
        label.text = "\(title) (\(count))"
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.textColor = .label
        let container = UIView()
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(
                equalTo: container.leadingAnchor,
                constant: 16
            ),
            label.topAnchor.constraint(
                equalTo: container.topAnchor,
                constant: 12
            ),
            label.bottomAnchor.constraint(
                equalTo: container.bottomAnchor,
                constant: -4
            ),
        ])
        return container
    }


    
    private func createHierarchyItemRow(title: String) -> UIView {
        // 1. Create a modern Plain configuration
        var config = UIButton.Configuration.plain()
        
        // 2. Set the title and color
        config.title = title
        let isSelected = selectedEntity?.name == title
        config.baseForegroundColor = isSelected ? .systemRed : .label
        
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 4,
            leading: 32,
            bottom: 4,
            trailing: 0
        )
        
        config.titleTextAttributesTransformer =
        UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 14)
            return outgoing
        }
        
        let button = UIButton(configuration: config)
        
        // Alignment still works on the button property
        button.contentHorizontalAlignment = .leading
        
        // 6. Add the action
        button.addAction(
            UIAction { [weak self] _ in
                self?.selectEntityFromSidebar(named: title)
            },
            for: .touchUpInside
        )
        
        return button
    }


    
    
    func setupUI() {
        
        // 1. TOP TOOLBAR (Floating)
        let toolbar = UIStackView()
        toolbar.axis = .horizontal
        toolbar.spacing = 6
        toolbar.alignment = .center
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.backgroundColor = UIColor.systemBackground.withAlphaComponent(
            0.9
        )
        toolbar.layer.cornerRadius = 35
        toolbar.isLayoutMarginsRelativeArrangement = true
        toolbar.layoutMargins = UIEdgeInsets(
            top: 6,
            left: 10,
            bottom: 6,
            right: 10
        )
        toolbar.layer.shadowColor = UIColor.black.cgColor
        toolbar.layer.shadowOpacity = 0.1
        toolbar.layer.shadowRadius = 8
        
        for tool in ToolType.allCases {
            let btn = makeIconToolbarButton(
                title: tool.title,
                systemImage: tool.icon
            )
            btn.addAction(
                UIAction { _ in
                    self.presentToolSheet(tool: tool)
                },
                for: .touchUpInside
            )
            toolbar.addArrangedSubview(btn)
        }
        
        // 3. 2D / 3D BUTTONS (Bottom-Right)
        let viewModeControl = UISegmentedControl(items: ["2D", "3D"])
        viewModeControl.selectedSegmentIndex = 1
        viewModeControl.translatesAutoresizingMaskIntoConstraints = false
        viewModeControl.backgroundColor = UIColor.systemBackground
            .withAlphaComponent(0.9)
        viewModeControl.selectedSegmentTintColor = UIColor(
            red: 177 / 255,
            green: 32 / 255,
            blue: 57 / 255,
            alpha: 1.0
        )
        viewModeControl.setTitleTextAttributes(
            [.foregroundColor: UIColor.white],
            for: .selected
        )
        viewModeControl.setTitleTextAttributes(
            [.foregroundColor: UIColor.label],
            for: .normal
        )
        
        viewModeControl.addAction(
            UIAction { _ in
                if viewModeControl.selectedSegmentIndex == 0 {
                    self.setTopView()
                } else {
                    self.setFrontView()
                }
            },
            for: .valueChanged
        )
        
        view.addSubview(viewModeControl)
        
        //         4. ROTATE BUTTON (Bottom-Left - Blue Button)
        let rotateBtn = UIButton(type: .system)
        rotateBtn.setImage(UIImage(systemName: "rotate.right"), for: .normal)
        rotateBtn.tintColor = .white
        rotateBtn.backgroundColor = .systemBlue
        rotateBtn.layer.cornerRadius = 22
        rotateBtn.translatesAutoresizingMaskIntoConstraints = false
        
        rotateBtn.addAction(
            UIAction { _ in
                self.toggleRotationMode(rotateBtn)
            },
            for: .touchUpInside
        )
        
      
        movementToggleButton.translatesAutoresizingMaskIntoConstraints = false
        movementToggleButton.addTarget(
            self,
            action: #selector(toggleMovementTapped(_:)),
            for: .touchUpInside
        )


        //                let undoBtn = UIButton(type: .system)
        //                undoBtn.setImage(UIImage(systemName: "arrow.uturn.backward"), for: .normal) // Standard icon
        //                undoBtn.tintColor = .white
        //                undoBtn.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 22/255, alpha: 1)
        //                undoBtn.layer.cornerRadius = 20
        //                undoBtn.translatesAutoresizingMaskIntoConstraints = false
        //                undoBtn.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)
        //
        //                let redoBtn = UIButton(type: .system)
        //                redoBtn.setImage(UIImage(systemName: "arrow.uturn.forward"), for: .normal)
        //                redoBtn.tintColor = .white
        //                redoBtn.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 22/255, alpha: 1)
        //                redoBtn.layer.cornerRadius = 20
        //                redoBtn.translatesAutoresizingMaskIntoConstraints = false
        //                redoBtn.addTarget(self, action: #selector(redoTapped), for: .touchUpInside)
        //
        //                let exportBtn = UIButton(type: .system)
        //                exportBtn.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        //                exportBtn.tintColor = .white
        //                exportBtn.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 22/255, alpha: 1)
        //                exportBtn.layer.cornerRadius = 20
        //                exportBtn.translatesAutoresizingMaskIntoConstraints = false
        //                exportBtn.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)
        //
        //                view.addSubview(exportBtn)
        //                view.addSubview(undoBtn)
        //                view.addSubview(redoBtn)
      
        
        // AR MODE BUTTON
        let arButton = UIButton(type: .system)
        let arIconCfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        arButton.setImage(UIImage(systemName: "arkit", withConfiguration: arIconCfg), for: .normal)
        arButton.tintColor = .systemGreen
        arButton.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 22/255, alpha: 1)
        arButton.layer.cornerRadius = 16
        arButton.clipsToBounds = true
        arButton.translatesAutoresizingMaskIntoConstraints = false
        self.arModeButton = arButton
        arButton.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.isARModeActive.toggle()
            self.toggleARMode(isOn: self.isARModeActive)
        }, for: .touchUpInside)

        // 6. ADD TO VIEW
        view.addSubview(toolbar)
        view.addSubview(rotateBtn)
        view.addSubview(movementToggleButton)
        view.addSubview(arButton)

        
        //undo redo
        //               NSLayoutConstraint.activate([
        //                    // Redo Button (Closest to Layers Button)
        //                    redoBtn.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
        //                    redoBtn.trailingAnchor.constraint(equalTo: exportBtn.leadingAnchor,constant: -12),
        //                    redoBtn.widthAnchor.constraint(equalToConstant: 40),
        //                    redoBtn.heightAnchor.constraint(equalToConstant: 40),
        //
        //                    // Undo Button (To the left of Redo)
        //                    undoBtn.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
        //                    undoBtn.trailingAnchor.constraint(equalTo: redoBtn.leadingAnchor, constant: -12),
        //                    undoBtn.widthAnchor.constraint(equalToConstant: 40),
        //                    undoBtn.heightAnchor.constraint(equalToConstant: 40),
        //                ])
        //
        //        NSLayoutConstraint.activate([
        //                            exportBtn.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
        //                            // Place it to the left of your Undo button
        //                            exportBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        //                            exportBtn.widthAnchor.constraint(equalToConstant: 40),
        //                            exportBtn.heightAnchor.constraint(equalToConstant: 40)
        //                        ])
        
        //new undo redo ends
      
        
        // 7. CONSTRAINTS
        NSLayoutConstraint.activate([
            
            // Toolbar (Top Center)
            toolbar.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 12
            ),
            toolbar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // 2D / 3D Control (Bottom Right)
            viewModeControl.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -16
            ),
            viewModeControl.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -20
            ),
            viewModeControl.heightAnchor.constraint(equalToConstant: 32),
            viewModeControl.widthAnchor.constraint(equalToConstant: 120),

            // AR Button (bottom-right, left of 2D/3D control)
            arButton.trailingAnchor.constraint(equalTo: viewModeControl.leadingAnchor, constant: -12),
            arButton.centerYAnchor.constraint(equalTo: viewModeControl.centerYAnchor),
            arButton.widthAnchor.constraint(equalToConstant: 44),
            arButton.heightAnchor.constraint(equalToConstant: 44),

            // Rotate Button (Bottom Left)
            rotateBtn.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: 16
            ),
            rotateBtn.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -20
            ),
            rotateBtn.widthAnchor.constraint(equalToConstant: 40),
            rotateBtn.heightAnchor.constraint(equalToConstant: 40),
            
        ])
        
        // 8. CAMERA COLLECTION VIEW (Right Side)
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.itemSize = CGSize(width: 120, height: 120)
        layout.minimumLineSpacing = 10
        
        cameraCollectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )
        
        cameraCollectionView.register(
            CameraPreviewCell.self,
            forCellWithReuseIdentifier: CameraPreviewCell.reuseID
        )
        
        cameraCollectionView.backgroundColor = UIColor.black.withAlphaComponent(
            0.85
        )
        cameraCollectionView.layer.cornerRadius = 14
        cameraCollectionView.translatesAutoresizingMaskIntoConstraints = false
        
        cameraCollectionView.dataSource = self
        cameraCollectionView.delegate = self
        
        view.addSubview(cameraCollectionView)
        
        NSLayoutConstraint.activate([
            cameraCollectionView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -16
            ),
            cameraCollectionView.centerYAnchor.constraint(
                equalTo: view.centerYAnchor
            ),
            cameraCollectionView.widthAnchor.constraint(equalToConstant: 140),
            cameraCollectionView.heightAnchor.constraint(equalToConstant: 320),
        ])
        
        // 9. SIDEBAR & HIERARCHY
        view.addSubview(sidebarView)
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        sidebarView.addSubview(scrollView)
        scrollView.addSubview(hierarchyStackView)
        
        sidebarLeadingConstraint = sidebarView.leadingAnchor.constraint(
            equalTo: view.leadingAnchor,
            constant: -sidebarWidth
        )
        
        NSLayoutConstraint.activate([
            sidebarView.topAnchor.constraint(equalTo: toolbar.topAnchor),
            sidebarView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebarView.widthAnchor.constraint(equalToConstant: sidebarWidth),
            sidebarLeadingConstraint,
            
            scrollView.topAnchor.constraint(
                equalTo: sidebarView.safeAreaLayoutGuide.topAnchor,
                constant: 60
            ),
            scrollView.leadingAnchor.constraint(
                equalTo: sidebarView.leadingAnchor
            ),
            scrollView.trailingAnchor.constraint(
                equalTo: sidebarView.trailingAnchor
            ),
            scrollView.bottomAnchor.constraint(
                equalTo: sidebarView.bottomAnchor
            ),
            
            hierarchyStackView.topAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.topAnchor
            ),
            hierarchyStackView.leadingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.leadingAnchor
            ),
            hierarchyStackView.trailingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.trailingAnchor
            ),
            hierarchyStackView.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor
            ),
            hierarchyStackView.widthAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.widthAnchor
            ),
        ])
        
        view.addSubview(layersButton)
        layersButton.addTarget(
            self,
            action: #selector(didTapLayersButton),
            for: .touchUpInside
        )
        NSLayoutConstraint.activate([
            layersButton.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: 16
            ),
            layersButton.centerYAnchor.constraint(
                equalTo: toolbar.centerYAnchor
            ),
            layersButton.widthAnchor.constraint(equalToConstant: 44),
            layersButton.heightAnchor.constraint(equalToConstant: 44),
            layersButton.widthAnchor.constraint(equalToConstant: 44),
            layersButton.heightAnchor.constraint(equalToConstant: 44),
        ])
        
        
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(
            UIImage(systemName: "xmark", withConfiguration: config),
            for: .normal
        )
        closeBtn.tintColor = .white
        closeBtn.backgroundColor = UIColor(
            red: 11 / 255,
            green: 11 / 255,
            blue: 22 / 255,
            alpha: 1
        )
        closeBtn.layer.cornerRadius = 22
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addTarget(
            self,
            action: #selector(didTapLayersButton),
            for: .touchUpInside
        )
        
        sidebarView.addSubview(closeBtn)
        NSLayoutConstraint.activate([
            closeBtn.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            closeBtn.trailingAnchor.constraint(
                equalTo: sidebarView.trailingAnchor,
                constant: -16
            ),
            closeBtn.widthAnchor.constraint(equalToConstant: 44),
            closeBtn.heightAnchor.constraint(equalToConstant: 40),
        ])
        
        // Ensure the sidebar stays on top of the 3D scene
        view.bringSubviewToFront(sidebarView)
        view.bringSubviewToFront(layersButton)
        
    }



    private func setupUI() {
        backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        layer.cornerRadius = 28
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 12

        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        addMenuButton(title: "Move", action: .move)
        addSeparator()
        addMenuButton(title: "Rotate", action: .rotate)
        addSeparator()
        addMenuButton(title: "Lock", action: .lock)
        addSeparator()
        addMenuButton(title: "Delete", action: .delete, isDestructive: true)
    }

}
