//
// MyFeatureCanvasVC.swift
// FilmsPage
//
// Created by [Your Name]
//

import UIKit

class MyFeatureCanvasVC: UIViewController, UIViewControllerTransitioningDelegate {

    // MARK: - Data Model
    private var canvasItems: [String: UIView] = [:]
    private let hierarchyCategories = ["Characters", "Cameras", "Props", "Lighting", "Wall", "Background"]

    // MARK: - Core Views
    private let canvasView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Top Toolbar Views
    private let toolbarContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 20
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let toolStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .equalSpacing
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Sidebar Views and Constraints
    private let sidebarView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray5
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.3
        view.layer.shadowRadius = 5
        view.layer.shadowOffset = CGSize(width: 3, height: 0)
        return view
    }()
    
    private var sidebarLeadingConstraint: NSLayoutConstraint!
    private let sidebarWidth: CGFloat = 260
    private var isSidebarVisible = false
    
    // Sidebar Hierarchy Content Views
    private let hierarchyScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let hierarchyStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 8
        sv.alignment = .fill
        sv.distribution = .equalSpacing
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupViewsAndConstraints() // Combined setup function
    }
    
    // MARK: - Setup UI Methods
    
    func setupNavigationBar() {
        navigationItem.title = "Scene 1"
        let layersButton = UIBarButtonItem(image: UIImage(systemName: "list.bullet.indent"), style: .plain, target: self, action: #selector(didTapLayersButton))
        navigationItem.leftBarButtonItem = layersButton
        let undo = UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.backward"), style: .plain, target: self, action: nil)
        let redo = UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.forward"), style: .plain, target: self, action: nil)
        let more = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), style: .plain, target: self, action: nil)
        navigationItem.rightBarButtonItems = [more, redo, undo]
    }
    
    // CONSOLIDATED VIEW AND CONSTRAINT SETUP
    func setupViewsAndConstraints() {
        // --- 1. Canvas Setup (Highest Layer) ---
        view.addSubview(canvasView)
        NSLayoutConstraint.activate([
            canvasView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // --- 2. Sidebar Setup (Below Toolbar) ---
        canvasView.addSubview(sidebarView)
        
        NSLayoutConstraint.activate([
            sidebarView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            sidebarView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebarView.widthAnchor.constraint(equalToConstant: sidebarWidth)
        ])
        
        // Initial position: off-screen. This is the constraint we animate.
        sidebarLeadingConstraint = sidebarView.leadingAnchor.constraint(equalTo: canvasView.leadingAnchor, constant: -sidebarWidth)
        sidebarLeadingConstraint.isActive = true
        
        // Hierarchy Content Setup
        sidebarView.addSubview(hierarchyScrollView)
        hierarchyScrollView.addSubview(hierarchyStackView)

        NSLayoutConstraint.activate([
            hierarchyScrollView.topAnchor.constraint(equalTo: sidebarView.topAnchor, constant: 40),
            hierarchyScrollView.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor),
            hierarchyScrollView.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor),
            hierarchyScrollView.bottomAnchor.constraint(equalTo: sidebarView.bottomAnchor, constant: -40)
        ])
        
        NSLayoutConstraint.activate([
            hierarchyStackView.topAnchor.constraint(equalTo: hierarchyScrollView.contentLayoutGuide.topAnchor),
            hierarchyStackView.leadingAnchor.constraint(equalTo: hierarchyScrollView.contentLayoutGuide.leadingAnchor),
            hierarchyStackView.trailingAnchor.constraint(equalTo: hierarchyScrollView.contentLayoutGuide.trailingAnchor),
            hierarchyStackView.bottomAnchor.constraint(equalTo: hierarchyScrollView.contentLayoutGuide.bottomAnchor),
            hierarchyStackView.widthAnchor.constraint(equalTo: hierarchyScrollView.frameLayoutGuide.widthAnchor)
        ])
        
        // --- 3. Toolbar Setup (Highest Layer on Canvas) ---
        canvasView.addSubview(toolbarContainer)
        toolbarContainer.addSubview(toolStackView)
        
        NSLayoutConstraint.activate([
            toolbarContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            toolbarContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toolbarContainer.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        NSLayoutConstraint.activate([
            toolStackView.topAnchor.constraint(equalTo: toolbarContainer.topAnchor, constant: 4),
            toolStackView.bottomAnchor.constraint(equalTo: toolbarContainer.bottomAnchor, constant: -4),
            toolStackView.leadingAnchor.constraint(equalTo: toolbarContainer.leadingAnchor, constant: 16),
            toolStackView.trailingAnchor.constraint(equalTo: toolbarContainer.trailingAnchor, constant: -16),
        ])
        
        let tools = [
            ("person.3.fill", #selector(didTapTool(_:)), "Character"),
            ("camera.fill", #selector(didTapTool(_:)), "Camera"),
            ("cube.fill", #selector(didTapTool(_:)), "Props"),
            ("lightbulb.fill", #selector(didTapTool(_:)), "Lights"),
            ("square.fill.on.square", #selector(didTapTool(_:)), "Walls"),
            ("photo.fill", #selector(didTapTool(_:)), "Background")
        ]
        
        for (imageName, action, title) in tools {
            let button = createToolbarButton(imageName: imageName, title: title)
            button.addTarget(self, action: action, for: .touchUpInside)
            toolStackView.addArrangedSubview(button)
        }
    }
    
    func createToolbarButton(imageName: String, title: String) -> UIButton {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        button.setImage(UIImage(systemName: imageName, withConfiguration: config), for: .normal)
        button.tintColor = .label
        button.accessibilityIdentifier = title
        return button
    }

    // MARK: - Actions
    
    @objc func didTapLayersButton() {
        if !isSidebarVisible {
            refreshSidebarContent()
        }

        isSidebarVisible.toggle()
        
        let newLeadingConstant: CGFloat = isSidebarVisible ? 0 : -sidebarWidth
        sidebarLeadingConstraint.constant = newLeadingConstant
        
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
        
        let layersIcon = isSidebarVisible ? "xmark" : "list.bullet.indent"
        navigationItem.leftBarButtonItem?.image = UIImage(systemName: layersIcon)
        
        print("Sidebar toggled. Visible: \(isSidebarVisible)")
    }

    @objc func didTapTool(_ sender: UIButton) {
        guard let toolName = sender.accessibilityIdentifier else { return }
        if toolName == "Character" {
            presentItemPicker(for: toolName)
        }
    }
    
    func presentItemPicker(for toolName: String) {
        let storyboard = UIStoryboard(name: "ItemPicker", bundle: nil)
        
        guard let pickerVC = storyboard.instantiateInitialViewController() as? ItemPickerVC else {
             print("Error: ItemPickerVC not found in ItemPicker.storyboard.")
             return
        }
        
        pickerVC.modalTitle = "Add \(toolName)"

        pickerVC.modalPresentationStyle = .custom
        pickerVC.transitioningDelegate = self
        
        pickerVC.onItemSelected = { [weak self] selectedItem in
            self?.addItemToCanvas(itemName: selectedItem)
        }

        present(pickerVC, animated: true)
    }
    
    // ITEM ADDITION AND DRAGGING LOGIC
    func addItemToCanvas(itemName: String) {
        let uniqueItemName = itemName + " (\(UUID().uuidString.prefix(4)))"

        // --- 1. Create the Top-Down 2D Icon Container ---
        let characterIcon = UIView()
        characterIcon.translatesAutoresizingMaskIntoConstraints = true // Allow frame manipulation
        
        // TEMPORARY VISUAL DEBUGGING
        characterIcon.layer.borderWidth = 3
        characterIcon.layer.borderColor = UIColor.red.cgColor
        
        // Create the gray silhouette view inside the container
        let silhouetteView = UIView()
        silhouetteView.backgroundColor = UIColor.systemGray3.withAlphaComponent(0.8)
        silhouetteView.layer.cornerRadius = 35
        silhouetteView.translatesAutoresizingMaskIntoConstraints = false
        
        characterIcon.addSubview(silhouetteView)
        
        let size: CGFloat = 80
        // Set frame for initial positioning (visible center)
        characterIcon.frame = CGRect(x: view.frame.width/2 - size/2, y: view.frame.height/2 - size/2, width: size, height: size)
        
        // --- 2. Make it Draggable ---
        characterIcon.isUserInteractionEnabled = true
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        characterIcon.addGestureRecognizer(panGesture)

        canvasView.addSubview(characterIcon)
        
        // Set constraints for the silhouette view inside the characterIcon
        NSLayoutConstraint.activate([
            silhouetteView.centerXAnchor.constraint(equalTo: characterIcon.centerXAnchor),
            silhouetteView.centerYAnchor.constraint(equalTo: characterIcon.centerYAnchor),
            silhouetteView.widthAnchor.constraint(equalToConstant: 70),
            silhouetteView.heightAnchor.constraint(equalToConstant: 70),
        ])
        
        // --- 3. Store the item and refresh the sidebar ---
        characterIcon.accessibilityLabel = uniqueItemName
        canvasItems[uniqueItemName] = characterIcon
        refreshSidebarContent()
        
        // Bring character icon to the very front of the canvas view to prevent it from being hidden
        canvasView.bringSubviewToFront(characterIcon)
    }
    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let draggedView = gesture.view else { return }
        let translation = gesture.translation(in: canvasView)

        // Update view position
        draggedView.center = CGPoint(
            x: draggedView.center.x + translation.x,
            y: draggedView.center.y + translation.y
        )
        gesture.setTranslation(.zero, in: canvasView)
    }

    // MARK: - Sidebar Refresh Logic
    
    func refreshSidebarContent() {
        hierarchyStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for category in hierarchyCategories {
            let itemsInCategory = canvasItems.filter { $0.key.contains("Character") && category == "Characters" }
            
            if category == "Characters" {
                let header = createHierarchyHeader(title: category, count: itemsInCategory.count)
                hierarchyStackView.addArrangedSubview(header)
                
                for (name, _) in itemsInCategory {
                    let itemRow = createHierarchyItemRow(title: name)
                    hierarchyStackView.addArrangedSubview(itemRow)
                }
            } else {
                let placeholderHeader = createHierarchyHeader(title: category, count: 1, isPlaceholder: true)
                hierarchyStackView.addArrangedSubview(placeholderHeader)
                
                if category == "Wall" {
                    let placeholderItem = createHierarchyItemRow(title: "Brick Wall", isPlaceholder: true)
                    hierarchyStackView.addArrangedSubview(placeholderItem)
                }
            }
        }
        
        let totalObjects = UILabel()
        totalObjects.text = "\nTotal Objects: \(canvasItems.count)"
        totalObjects.textColor = .systemGray
        totalObjects.font = UIFont.systemFont(ofSize: 12)
        hierarchyStackView.addArrangedSubview(totalObjects)
    }
    
    // ... (createHierarchyHeader and createHierarchyItemRow functions omitted for brevity, ensure they are present)
    private func createHierarchyHeader(title: String, count: Int, isPlaceholder: Bool = false) -> UIView {
        // ... (implementation needed here)
        let label = UILabel()
        label.text = "\(title) (\(count))"
        label.textColor = isPlaceholder ? .systemGray : .label
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        let container = UIView()
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16), label.topAnchor.constraint(equalTo: container.topAnchor, constant: 12), label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)])
        return container
    }
    private func createHierarchyItemRow(title: String, isPlaceholder: Bool = false) -> UIView {
        // ... (implementation needed here)
        let label = UILabel()
        label.text = title
        label.textColor = isPlaceholder ? .systemGray : .systemRed
        label.font = UIFont.systemFont(ofSize: 14)
        let container = UIView()
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32), label.topAnchor.constraint(equalTo: container.topAnchor, constant: 4), label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)])
        return container
    }

    // MARK: - UIViewControllerTransitioningDelegate
    
    func presentationController(forPresented presented: UIViewController,
                                presenting: UIViewController?,
                                source: UIViewController) -> UIPresentationController? {

        return BottomSheetPresentationController(
            presentedViewController: presented,
            presenting: presenting
        )
    }
}
