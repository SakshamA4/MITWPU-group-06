//
// MyFeatureCanvasVC.swift
// FilmsPage
//
// Created by Ritik
//

import UIKit

class MyFeatureCanvasVC: UIViewController, UIViewControllerTransitioningDelegate, EditCharacterDelegate {

    // MARK: - Data Model
    private var canvasItems: [String: UIView] = [:]
    private let hierarchyCategories = ["Characters", "Cameras", "Props", "Lighting", "Wall", "Background"]

    private let layersButton: UIButton = {
        let b = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        b.setImage(UIImage(systemName: "square.stack.3d.down.right"), for: .normal)
        b.tintColor = .label
        b.backgroundColor = .systemGray6
        b.layer.cornerRadius = 20 // Makes it a circle
        b.clipsToBounds = true
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let categoryToToolMap: [String: String] = [
        "Characters": "Character",
        "Cameras": "Camera",
        "Props": "Props",
        "Lighting": "Lights",
        "Wall": "Walls",
        "Background": "Background"
    ]
    
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
                return [ "Framed sunset", "Dining Area", "Forest Landscape", "Temple","Backyard","Industrial Hall","Open terrace","Stairwell"]
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
        
//        private let sidebarCloseButton: UIButton = {
//            let button = UIButton(type: .system)
//            let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
//            button.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: config), for: .normal)
//            button.tintColor = .label
//            button.translatesAutoresizingMaskIntoConstraints = false
//            button.addTarget(self, action: #selector(didTapLayersButton), for: .touchUpInside) // Use the same toggle function
//            return button
//        }()
    
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
        let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(didTapCloseButton))
        navigationItem.leftBarButtonItem = closeButton
        let undo = UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.backward"), style: .plain, target: self, action: nil)
        let redo = UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.forward"), style: .plain, target: self, action: nil)
        let more = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), style: .plain, target: self, action: nil)
        let exportButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(didTapExportButton))
        navigationItem.rightBarButtonItems = [more, redo, undo,exportButton]
    }
    func setupViewsAndConstraints() {
        //1. Canvas Setup
        view.addSubview(canvasView)
        NSLayoutConstraint.activate([
            canvasView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
   
        //2. Sidebar Setup
        canvasView.addSubview(sidebarView)
        NSLayoutConstraint.activate([
            sidebarView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            sidebarView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebarView.widthAnchor.constraint(equalToConstant: sidebarWidth)
        ])

        sidebarView.addSubview(sidebarHeaderView)
        sidebarHeaderView.addSubview(sidebarTitleLabel)
        //sidebarHeaderView.addSubview(sidebarCloseButton)

        NSLayoutConstraint.activate([
            sidebarHeaderView.topAnchor.constraint(equalTo: sidebarView.topAnchor),
            sidebarHeaderView.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor),
            sidebarHeaderView.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor),
            sidebarHeaderView.heightAnchor.constraint(equalToConstant: 64),
            
            // Title and Close Button constraints are fine:
            sidebarTitleLabel.centerXAnchor.constraint(equalTo: sidebarHeaderView.centerXAnchor),
            sidebarTitleLabel.centerYAnchor.constraint(equalTo: sidebarHeaderView.centerYAnchor),
            
//            sidebarCloseButton.trailingAnchor.constraint(equalTo: sidebarHeaderView.trailingAnchor, constant: -12),
//            sidebarCloseButton.centerYAnchor.constraint(equalTo: sidebarHeaderView.centerYAnchor)
        ])


        // Initial position: off-screen.
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
        
        //3. Toolbar Setup
        canvasView.addSubview(toolbarContainer)
        toolbarContainer.addSubview(toolStackView)
        view.addSubview(layersButton)
        layersButton.addTarget(self, action: #selector(didTapLayersButton), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            toolbarContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            toolbarContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toolbarContainer.heightAnchor.constraint(equalToConstant: 40),
            
            // 3. Layers Button: Level with Toolbar on the left
                    layersButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
                    layersButton.centerYAnchor.constraint(equalTo: toolbarContainer.centerYAnchor), // Keeps them perfectly level
                    layersButton.widthAnchor.constraint(equalToConstant: 40),
                    layersButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Ensure they are visible above the white canvas
            view.bringSubviewToFront(toolbarContainer)
            view.bringSubviewToFront(layersButton)
        
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
    
    @objc func didTapCloseButton() {
        self.dismiss(animated: true, completion: nil)
    }
    
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
        layersButton.setImage(UIImage(systemName: layersIcon), for: .normal)
    }

    
    @objc func didTapTool(_ sender: UIButton) {
            guard let toolName = sender.accessibilityIdentifier else { return }
            print("\(toolName) tool tapped.")
            presentItemPicker(for: toolName)
        }
    
    
    func presentItemPicker(for toolName: String) {

            let pickerVC = ItemPickerVC()
            pickerVC.modalTitle = "Add \(toolName)"
            pickerVC.itemType = toolName
            pickerVC.itemsToDisplay = getItems(for: toolName)
            
            pickerVC.modalPresentationStyle = .custom
            pickerVC.transitioningDelegate = self
            
            pickerVC.onItemSelected = { [weak self] selectedItem in
                self?.launchEditModal(selectedItemName: selectedItem, itemType: toolName)
                print("Closure fired for: \(selectedItem)")
            }

            present(pickerVC, animated: true)
        }
    
        //Launches the second modal (EditCharacterVC) after selection in the first modal.
        func launchEditModal(selectedItemName: String, itemType: String) {
            if itemType != "Character" {
                addItemToCanvas(itemName: selectedItemName, itemType: itemType)
                return
            }

            let editVC = EditCharacterVC()
            editVC.selectedCharacterName = selectedItemName
            editVC.delegate = self

            editVC.modalPresentationStyle = .custom
            editVC.transitioningDelegate = self

            present(editVC, animated: true)
        }
        
        
    func addItemToCanvas(itemName: String, itemType: String) {
        let uniqueItemName = itemName + " (" + UUID().uuidString.prefix(4) + ")"
        
        if itemType == "Character" || itemType == "Props" || itemType == "Walls" || itemType == "Camera" || itemType == "Lights" || itemType == "Background" {
            
            //1. Create the Icon Container
            let itemIcon = UIView()
            itemIcon.translatesAutoresizingMaskIntoConstraints = true
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
                // Logic for Props, Walls, Camera, Lights, and NOW Background
                let size: CGFloat = 60 // Default size for generic icons
                switch itemType {
                case "Walls":
                    // --- WALLS: Load Image View directly (Uses 150 size) ---
                    let wallSize: CGFloat = 150
                    itemIcon.frame = CGRect(x: view.frame.width/2 - wallSize/2, y: view.frame.height/2 - wallSize/2, width: wallSize, height: wallSize)
                    itemIcon.layer.cornerRadius = 8
                    itemIcon.clipsToBounds = true
                    
                    // Load and pin the image view (from previous successful step)
                    let imageView = UIImageView()
                    imageView.translatesAutoresizingMaskIntoConstraints = false
                    imageView.contentMode = .scaleToFill // Allows stretching
                    imageView.image = UIImage(named: itemName)
                    itemIcon.addSubview(imageView)
                    
                    NSLayoutConstraint.activate([
                        imageView.topAnchor.constraint(equalTo: itemIcon.topAnchor),
                        imageView.leadingAnchor.constraint(equalTo: itemIcon.leadingAnchor),
                        imageView.trailingAnchor.constraint(equalTo: itemIcon.trailingAnchor),
                        imageView.bottomAnchor.constraint(equalTo: itemIcon.bottomAnchor)
                    ])
                    break
                case "Background":
                    let backgroundSize: CGFloat = 300
                    itemIcon.frame = CGRect(x: view.frame.width/2 - backgroundSize/2, y: view.frame.height/2 - backgroundSize/2, width: backgroundSize, height: backgroundSize)
                    itemIcon.layer.cornerRadius = 0
                    itemIcon.clipsToBounds = true
                    
                    let imageView = UIImageView()
                    imageView.translatesAutoresizingMaskIntoConstraints = false
                    imageView.contentMode = .scaleAspectFill
                    imageView.image = UIImage(named: itemName)
                    itemIcon.addSubview(imageView)
                    
                    NSLayoutConstraint.activate([
                        imageView.topAnchor.constraint(equalTo: itemIcon.topAnchor),
                        imageView.leadingAnchor.constraint(equalTo: itemIcon.leadingAnchor),
                        imageView.trailingAnchor.constraint(equalTo: itemIcon.trailingAnchor),
                        imageView.bottomAnchor.constraint(equalTo: itemIcon.bottomAnchor)
                    ])
                    break
                    
                case "Camera", "Lights", "Props":
                    // --- CAMERA, LIGHTS, PROPS: Use SF Symbol Icons ---
                    
                    itemIcon.frame = CGRect(x: view.frame.width/2 - size/2, y: view.frame.height/2 - size/2, width: size, height: size)
                    itemIcon.layer.cornerRadius = 8
                    itemIcon.clipsToBounds = true
                    
                    let (color, _, symbolImage) = createSymbolIcon(for: itemType, withName: itemName, size: size)
                    
                    itemIcon.backgroundColor = color
                    
                    if let image = symbolImage {
                        let symbolView = UIImageView(image: image)
                        symbolView.translatesAutoresizingMaskIntoConstraints = false
                        symbolView.tintColor = .white
                        itemIcon.addSubview(symbolView)
                        
                        // Pin the symbol image centered and slightly smaller than the container
                        NSLayoutConstraint.activate([
                            symbolView.centerXAnchor.constraint(equalTo: itemIcon.centerXAnchor),
                            symbolView.centerYAnchor.constraint(equalTo: itemIcon.centerYAnchor),
                            symbolView.widthAnchor.constraint(equalTo: itemIcon.widthAnchor, multiplier: 0.7),
                            symbolView.heightAnchor.constraint(equalTo: itemIcon.heightAnchor, multiplier: 0.7),
                        ])
                    }
                    
                default:
                    // Fallback for types not handled
                    break
                }
            }
            
            // 2. Make it Draggable (have pan/pinch)
            itemIcon.isUserInteractionEnabled = true
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            itemIcon.addGestureRecognizer(panGesture)
            
            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            itemIcon.addGestureRecognizer(pinchGesture)
            pinchGesture.delegate = self
            panGesture.delegate = self
            
            canvasView.addSubview(itemIcon)
            
            //3. Store the item and refresh the sidebar
            itemIcon.accessibilityLabel = uniqueItemName
            canvasItems[uniqueItemName] = itemIcon
            refreshSidebarContent()
            
            canvasView.bringSubviewToFront(itemIcon)
                if itemType == "Background" || itemType == "Walls" {
                    canvasView.sendSubviewToBack(itemIcon)
                } else {
                    canvasView.bringSubviewToFront(itemIcon)
                }
            
            print("Added draggable item: \(uniqueItemName) of type \(itemType) to canvas.")
            
        } else {
            let uniqueItemName = itemName + " (" + UUID().uuidString.prefix(4) + ")"
            print("Set non-visual property: \(itemName) as \(itemType).")
            
            canvasItems[uniqueItemName] = UIView()
            refreshSidebarContent()
        }
    }
    
    // Function to handle the final share sheet presentation
    func shareExportedFile(data: Data, fileName: String, fileType: String) {
        
        // 1. Save the data to a temporary file URL
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let fileURL = temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
        } catch {
            print("Error writing file to temp directory: \(error)")
            return
        }
        
        // 2. Present the standard iOS Share Sheet (UIActivityViewController)
        let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        
        // Required for iPad presentation
        if let popoverController = activityViewController.popoverPresentationController {
            // Find the export button for popover source
            if let barButton = navigationItem.rightBarButtonItems?.first(where: { $0.action == #selector(didTapExportButton) }) {
                 popoverController.barButtonItem = barButton
            } else {
                popoverController.sourceView = self.view
                popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            }
        }
        
        self.present(activityViewController, animated: true, completion: nil)
    }
    // Helper function to capture image (used by both PDF and high-res image export)
    private func captureCanvasImage(scale: CGFloat) -> UIImage? {
        let bounds = canvasView.bounds
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        // Initialize with only bounds
        let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)

        
        let image = renderer.image { context in
            canvasView.drawHierarchy(in: bounds, afterScreenUpdates: true)
        }
        return image
    }
    
    
   

    func captureCanvasAndShare(format: String, quality: String? = nil) {
        
        // 1. Determine compression quality and scale factor (resolution)
        let compressionQuality: CGFloat = {
            if format == "JPEG" {
                return (quality == "High") ? 0.9 : 0.6
            }
            return 1.0
        }()
        
        let scale: CGFloat = (quality == "High") ? 3.0 : 2.0
        
        // 2. Define the area and renderer
        let renderer = UIGraphicsImageRenderer(bounds: canvasView.bounds)
    

        // 3. Render the view hierarchy into an image
        let image = renderer.image { context in
            canvasView.drawHierarchy(in: canvasView.bounds, afterScreenUpdates: true)
        }
        
        let data: Data?
        let fileExtension: String
        let fileType: String
        
        if format == "PNG" {
            data = image.pngData()
            fileExtension = "png"
            fileType = "image/png"
        } else { // JPEG or default
            data = image.jpegData(compressionQuality: compressionQuality)
            fileExtension = "jpeg"
            fileType = "image/jpeg"
        }
        
        guard let exportData = data else {
            print("Error: Could not generate image data for export.")
            return
        }
        
        // 4. Share the image file data
        shareExportedFile(data: exportData, fileName: "Scene_Canvas_Export.\(fileExtension)", fileType: fileType)
    }
    
    func exportCanvasAsPDF(quality: String) {
        let scale: CGFloat = (quality == "High") ? 3.0 : 2.0
        
        guard let canvasImage = captureCanvasImage(scale: scale) else {
            print("Error: Failed to capture canvas image for PDF export.")
            return
        }
        
        guard let pdfData = createPDFData(from: canvasImage) else {
            print("Error: Failed to create PDF data.")
            return
        }
        
        shareExportedFile(data: pdfData, fileName: "Scene_Canvas_Export.pdf", fileType: "application/pdf")
    }
    
    func createPDFData(from image: UIImage) -> Data? {
        // We choose a standard PDF page size, like A4, defined in points (1 point = 1/72 inch).
        let pageSize = CGRect(x: 0, y: 0, width: 595, height: 842) // Standard A4 points (approx)
        let pdfData = NSMutableData()
        
        // 1. Begin the PDF graphics context, writing to the pdfData buffer.
        UIGraphicsBeginPDFContextToData(pdfData, pageSize, nil)
        
        // 2. Start the first (and in this case, only) page.
        UIGraphicsBeginPDFPage()
        
        // 3. Determine the drawing rectangle to maintain aspect ratio on the PDF page.
        let imageAspectRatio = image.size.width / image.size.height
        let pdfWidth = pageSize.width
        let pdfHeight = pdfWidth / imageAspectRatio
        
        // 4. Draw the captured image onto the page.
        image.draw(in: CGRect(x: 0, y: 0, width: pdfWidth, height: pdfHeight))
        
        // 5. Finalize and close the PDF context.
        UIGraphicsEndPDFContext()
        
        return pdfData as Data
    }
    
    @objc func didTapExportButton() {
        let exportVC = ExportVC()
        
        // FIX IS HERE: Using onExportSelected
        exportVC.onExportSelected = { [weak self] format, quality in
            
            self?.dismiss(animated: true) {
                // Dismissal happens first, then execution
                switch format {
                case "JPEG", "PNG":
                    self?.captureCanvasAndShare(format: format, quality: quality)
                case "PDF":
                    self?.exportCanvasAsPDF(quality: quality)
                default:
                    print("Unsupported export format selected.")
                }
            }
        }
        
        // Set the custom presentation delegates
        exportVC.modalPresentationStyle = .custom
        exportVC.transitioningDelegate = self
        
        self.present(exportVC, animated: true)
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
    
    @objc func handlePinch(_ sender: UIPinchGestureRecognizer) {
            guard let viewToResize = sender.view else { return }
            
            // This is a standard proportional scaling implementation
            if sender.state == .began || sender.state == .changed {
                // Apply the change in scale since the last event
                viewToResize.transform = viewToResize.transform.scaledBy(x: sender.scale, y: sender.scale)
                
                // Reset the scale to 1.0 to accumulate changes, not multiply them infinitely
                sender.scale = 1.0
            }
        }

    // MARK: - Sidebar Refresh Logic
    
  

    func refreshSidebarContent() {
        hierarchyStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // --- 1. Map Canvas Items to their Original Type ---
        var itemsByType: [String: [(name: String, view: UIView)]] = [:]
        
        // Initialize empty arrays for all categories
        for category in hierarchyCategories {
            itemsByType[category] = []
        }
        
        // Iterate through every item currently on the canvas
        for (uniqueName, view) in canvasItems {
            
            var itemType: String? = nil
            
            // Find the base name (e.g., "Man in a suit" from "Man in a suit (ABCD)")
            let baseName: String
            if let range = uniqueName.range(of: " (") {
                baseName = String(uniqueName[..<range.lowerBound])
            } else {
                baseName = uniqueName // Use the whole name if no ID is found
            }
            
            // Determine the item's category
            for category in hierarchyCategories {
                
                // 🚨 CRITICAL FIX: Use the direct mapping dictionary to get the correct key
                guard let toolName = categoryToToolMap[category] else { continue }
                
                let baseItemNames = getItems(for: toolName) // e.g., ["Brick", "Wooden", "Glass"]
                
                // Check if our isolated base name matches any name in the category's source list
                if baseItemNames.contains(baseName) {
                    itemType = category // Found the category (e.g., "Wall")
                    break
                }
            }
            
            // Group the item by its determined type
            if let type = itemType {
                itemsByType[type]?.append((name: uniqueName, view: view))
            } else {
                print("Warning: Item \(uniqueName) (Base: \(baseName)) did not match any hierarchy category.")
            }
        }
        // --- 2. Build the Stack View ---
        for category in hierarchyCategories {
            let items = itemsByType[category] ?? []
            let count = items.count
            
            let header = createHierarchyHeader(title: category, count: count)
            hierarchyStackView.addArrangedSubview(header)
            
            // Add item rows for all items found in this category
            for (name, _) in items {
                // Clean up the unique ID for display in the sidebar (e.g., "Brick (ABCD)" -> "Brick")
                let displayTitle = name.components(separatedBy: " (").first ?? name
                let itemRow = createHierarchyItemRow(title: displayTitle)
                hierarchyStackView.addArrangedSubview(itemRow)
            }
        }
        
        // --- 3. Final Footer ---
        let totalObjects = UILabel()
        totalObjects.text = "\nTotal Objects: \(canvasItems.count)"
        totalObjects.textColor = .systemGray
        totalObjects.font = UIFont.systemFont(ofSize: 12)
        hierarchyStackView.addArrangedSubview(totalObjects)
    }
    
 
    private func createHierarchyHeader(title: String, count: Int, isPlaceholder: Bool = false) -> UIView {
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
            addItemToCanvas(itemName: name, itemType: "Character")
        }
    
    
    // In MyFeatureCanvasVC.swift
        private func createSymbolIcon(for type: String, withName itemName: String, size: CGFloat) -> (UIColor, String, UIImage?) {
            let color: UIColor
            let symbolName: String
            
            switch type {
            case "Camera":
                color = UIColor.systemRed.withAlphaComponent(0.7)
                symbolName = "camera.fill" // SF Symbol for a camera
            case "Lights":
                color = UIColor.systemYellow.withAlphaComponent(0.7)
                symbolName = "light.max" // SF Symbol for a spotlight
            case "Props":
                color = UIColor.systemBlue.withAlphaComponent(0.7)
                symbolName = "cube.fill" // Generic symbol for a prop
            default:
                color = .systemGray
                symbolName = "questionmark.circle.fill"
            }
            
            // Use configuration to create a large symbol image
            let configuration = UIImage.SymbolConfiguration(pointSize: size * 0.5, weight: .bold)
            let symbolImage = UIImage(systemName: symbolName, withConfiguration: configuration)
            
            return (color, type, symbolImage)
        }
}


//Add the extension required to enable multiple gestures (pan and pinch) to work on the same view simultaneously.
// MARK: - UIGestureRecognizerDelegate
extension MyFeatureCanvasVC: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        return true
    }
}
