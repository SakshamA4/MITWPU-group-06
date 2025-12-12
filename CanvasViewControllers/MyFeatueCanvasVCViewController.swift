//
// MyFeatureCanvasVC.swift
// FilmsPage
//
// Created by [Your Name]
//

import UIKit

class MyFeatureCanvasVC: UIViewController, UIViewControllerTransitioningDelegate, EditCharacterDelegate {

    // MARK: - Data Model
    private var canvasItems: [String: UIView] = [:]
    private let hierarchyCategories = ["Characters", "Cameras", "Props", "Lighting", "Wall", "Background"]

    
    // MARK: - Item Data Source
        
        private func getItems(for toolName: String) -> [String] {
            switch toolName {
            case "Character":
                return ["Man in a suit","Woman 1", "Asian man",  "Woman 2", "Man in a jersey", "Woman 3"]
            case "Camera":
                return ["Default", "DSLR", "Sony", "Canon", "iPhone","GoPro","Drone","Arri"]
            case "Props":
                return ["Handbag", "Bookshelf", "Fridge", "Flower Vase", "Plant", "Wardrobe","Bag Pack","Shoe Rack"]
            case "Lights":
                return ["Lantern", "Practical light", "Fluorescent tube", "Spotlight","LED Panel","Practical Spotlight","Ringlight"]
            case "Walls":
                return ["Brick", "Wooden", "Glass"]
            case "Background":
                return ["Studio Backdrop", "Framed Sunset", "Dining Area", "Forest Landscape", "Temple","Backyard","Industrial Hall","Open terrace","Stairwell"]
            default:
                return []
            }
        }
    
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
    
    // MARK: - Sidebar Header Views
        private let sidebarHeaderView: UIView = {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.backgroundColor = .systemGray4 // Match the sidebar background slightly darker
            return view
        }()
    
    //adding new component for sidebar's header
    private let sidebarTitleLabel: UILabel = {
            let label = UILabel()
            label.text = "Scene Hierarchy"
            label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()
        
        private let sidebarCloseButton: UIButton = {
            let button = UIButton(type: .system)
            let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
            button.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: config), for: .normal)
            button.tintColor = .label
            button.translatesAutoresizingMaskIntoConstraints = false
            button.addTarget(self, action: #selector(didTapLayersButton), for: .touchUpInside) // Use the same toggle function
            return button
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
        let layersButton = UIBarButtonItem(image: UIImage(systemName: "square.stack.3d.down.right"), style: .plain, target: self, action: #selector(didTapLayersButton))
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
            // 1. Sidebar View Constraints (Pins the ENTIRE sidebar to the top/bottom of the safe area)
            sidebarView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            sidebarView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebarView.widthAnchor.constraint(equalToConstant: sidebarWidth)
        ])
        
        
        
        // --- Sidebar Header Setup ---
        sidebarView.addSubview(sidebarHeaderView)
        sidebarHeaderView.addSubview(sidebarTitleLabel)
        sidebarHeaderView.addSubview(sidebarCloseButton)

        NSLayoutConstraint.activate([
            // CRITICAL CORRECTION: Header starts at the TOP of its parent (sidebarView), NOT the view's safe area.
            sidebarHeaderView.topAnchor.constraint(equalTo: sidebarView.topAnchor), // <-- CORRECTED LINE
            sidebarHeaderView.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor),
            sidebarHeaderView.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor),
            sidebarHeaderView.heightAnchor.constraint(equalToConstant: 44),
            
            // Title and Close Button constraints are fine:
            sidebarTitleLabel.centerXAnchor.constraint(equalTo: sidebarHeaderView.centerXAnchor),
            sidebarTitleLabel.centerYAnchor.constraint(equalTo: sidebarHeaderView.centerYAnchor),
            
            sidebarCloseButton.trailingAnchor.constraint(equalTo: sidebarHeaderView.trailingAnchor, constant: -12),
            sidebarCloseButton.centerYAnchor.constraint(equalTo: sidebarHeaderView.centerYAnchor)
        ])


        // Initial position: off-screen. This is the constraint we animate.
        sidebarLeadingConstraint = sidebarView.leadingAnchor.constraint(equalTo: canvasView.leadingAnchor, constant: -sidebarWidth)
        sidebarLeadingConstraint.isActive = true

        // Hierarchy Content Setup
        sidebarView.addSubview(hierarchyScrollView)
        hierarchyScrollView.addSubview(hierarchyStackView)

        NSLayoutConstraint.activate([
            // Scroll View starts immediately below the Header
            hierarchyScrollView.topAnchor.constraint(equalTo: sidebarHeaderView.bottomAnchor),
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
        
        let layersIcon = isSidebarVisible ? "xmark" : "square.stack.3d.down.right"
        navigationItem.leftBarButtonItem?.image = UIImage(systemName: layersIcon)
        
        print("Sidebar toggled. Visible: \(isSidebarVisible)")
    }

    
    @objc func didTapTool(_ sender: UIButton) {
            guard let toolName = sender.accessibilityIdentifier else { return }
            print("\(toolName) tool tapped.")
            
            // Now, all buttons launch the picker, using their own name as the type
            presentItemPicker(for: toolName)
        }
    
    
    func presentItemPicker(for toolName: String) {
            let storyboard = UIStoryboard(name: "ItemPicker", bundle: nil)
            
            guard let pickerVC = storyboard.instantiateInitialViewController() as? ItemPickerVC else {
                 print("Error: ItemPickerVC not found in ItemPicker.storyboard.")
                 return
            }
            
            // --- Setup for ALL Tools ---
            pickerVC.modalTitle = "Add \(toolName)"
            pickerVC.itemType = toolName // Pass the type (e.g., "Character", "Props")
            pickerVC.itemsToDisplay = getItems(for: toolName) // Pass the specific list
            
            pickerVC.modalPresentationStyle = .custom
            pickerVC.transitioningDelegate = self
            
            pickerVC.onItemSelected = { [weak self] selectedItem in
                self?.launchEditModal(selectedItemName: selectedItem, itemType: toolName) // Pass the itemType back
            }

            present(pickerVC, animated: true)
        }
    
    // NEW FUNCTION: Launches the second modal (EditCharacterVC) after selection in the first modal.
        func launchEditModal(selectedItemName: String, itemType: String) {
            
            // We only launch the edit modal if it's a Character
            if itemType != "Character" {
                // For Props, Lights, etc., just add them immediately (use the old logic here)
                addItemToCanvas(itemName: selectedItemName, itemType: itemType)
                return
            }

            let editVC = EditCharacterVC() // Assume EditCharacterVC handles its own complex UI layout
            editVC.selectedCharacterName = selectedItemName
            editVC.delegate = self

            // Use the same custom bottom sheet presentation for the Edit modal
            editVC.modalPresentationStyle = .custom
            editVC.transitioningDelegate = self

            present(editVC, animated: true)
        }
        
        
    // ITEM ADDITION AND DRAGGING LOGIC( for non-character items)
        func addItemToCanvas(itemName: String, itemType: String) {
            let uniqueItemName = itemName + " (\(UUID().uuidString.prefix(4)))"
            
            
            if itemType == "Character" || itemType == "Props" {
                // --- 1. Create the Icon Container ---
                let itemIcon = UIView()
                itemIcon.translatesAutoresizingMaskIntoConstraints = true
                
                
                // Set appearance based on type (Character is complex silhouette, others can be simple box)
                if itemType == "Character" {
                    // Create the gray silhouette view inside the container
                    let silhouetteView = UIView()
                    silhouetteView.backgroundColor = UIColor.systemGray3.withAlphaComponent(0.8)
                    silhouetteView.layer.cornerRadius = 35 // Creates the circular shape (half of 70)
                    silhouetteView.clipsToBounds = true // Ensure the silhouette is clipped to the circle
                    silhouetteView.translatesAutoresizingMaskIntoConstraints = false
                    
                    // Add a visible indicator (like a tiny head shape)
                    let headIndicator = UIView()
                    headIndicator.backgroundColor = .systemGray
                    headIndicator.layer.cornerRadius = 6
                    headIndicator.translatesAutoresizingMaskIntoConstraints = false
                    silhouetteView.addSubview(headIndicator)
                    
                    itemIcon.addSubview(silhouetteView)
                    
                    let size: CGFloat = 80
                    // Set frame for initial positioning (visible center)
                    itemIcon.frame = CGRect(x: view.frame.width/2 - size/2, y: view.frame.height/2 - size/2, width: size, height: size)
                    
                    // Set constraints for the silhouette view inside the characterIcon (fills the container)
                    NSLayoutConstraint.activate([
                        silhouetteView.centerXAnchor.constraint(equalTo: itemIcon.centerXAnchor),
                        silhouetteView.centerYAnchor.constraint(equalTo: itemIcon.centerYAnchor),
                        silhouetteView.widthAnchor.constraint(equalToConstant: 70),
                        silhouetteView.heightAnchor.constraint(equalToConstant: 70),
                        
                        // Head Indicator constraints (at the top of the silhouette circle)
                        headIndicator.topAnchor.constraint(equalTo: silhouetteView.topAnchor, constant: 5),
                        headIndicator.centerXAnchor.constraint(equalTo: silhouetteView.centerXAnchor),
                        headIndicator.widthAnchor.constraint(equalToConstant: 12),
                        headIndicator.heightAnchor.constraint(equalToConstant: 12),
                    ])
                } else {
                    // Generic square icon for Props, Lights, etc.
                    itemIcon.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.5)
                    itemIcon.layer.cornerRadius = 8
                    let size: CGFloat = 60
                    itemIcon.frame = CGRect(x: view.frame.width/2 - size/2, y: view.frame.height/2 - size/2, width: size, height: size)
                    
                    let label = UILabel()
                    label.text = itemName.prefix(4).uppercased()
                    label.textColor = .white
                    label.textAlignment = .center
                    label.translatesAutoresizingMaskIntoConstraints = false
                    itemIcon.addSubview(label)
                    
                    NSLayoutConstraint.activate([
                        label.centerXAnchor.constraint(equalTo: itemIcon.centerXAnchor),
                        label.centerYAnchor.constraint(equalTo: itemIcon.centerYAnchor),
                    ])
                    
                }
                
                // --- 2. Make it Draggable ---
                itemIcon.isUserInteractionEnabled = true
                let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
                itemIcon.addGestureRecognizer(panGesture)
                
                canvasView.addSubview(itemIcon)
                
                
                
                // --- 3. Store the item and refresh the sidebar ---
                itemIcon.accessibilityLabel = uniqueItemName
                canvasItems[uniqueItemName] = itemIcon
                refreshSidebarContent()
                
                canvasView.bringSubviewToFront(itemIcon)
                
                print("Added draggable item: \(uniqueItemName) of type \(itemType) to canvas.")
                
            } else {
                // Logic for Camera, Wall, Background (non-visual items on canvas)
                print("Set non-visual property: \(itemName) as \(itemType).")
                
                // We still want this in the hierarchy
                canvasItems[uniqueItemName] = UIView() // Store a placeholder view
                refreshSidebarContent()
            }
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
    
    
    // MARK: - EditCharacterDelegate
        func didConfirmCharacter(name: String) {
            // This is the FINAL step: add the confirmed character to the canvas!
            addItemToCanvas(itemName: name, itemType: "Character")
        }
    
}
