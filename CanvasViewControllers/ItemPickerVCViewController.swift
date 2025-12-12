//
// ItemPickerVC.swift
// FilmsPage
//
// Created by [Ritik]
//

import UIKit

// Typealias for the callback function
typealias ItemSelectionCallback = (String) -> Void

class ItemPickerVC: UIViewController {

    // MARK: - Public Properties
    var onItemSelected: ItemSelectionCallback? // Closure to send data back to ViewController
    
    // MARK: - Public Properties for Generic Content
        var itemType: String = "Character" // e.g., "Props", "Camera"
        var itemsToDisplay: [String] = []  // The list of items to show
    
    // Property to set the modal's title from the presenting VC
    var modalTitle: String = "Select Item" {
        didSet {
            titleLabel.text = modalTitle
        }
    }
    
    
    // MARK: - Character Data Sources
    private let filmCharacters: [String] = ["Man in a suit", "Woman 1", "Asian man"]

    // Placeholder for the full library list (add more names here as needed)
    private let libraryCharacters: [String] = ["Man in a suit","Woman 1", "Asian man",  "Woman 2", "Man in a jersey", "Woman 3"]
    
    
    // MARK: - Prop Data Sources
        // The list of props available when 'Film' is selected.
        private let filmProps: [String] = ["Plant", "Bookshelf", "Fridge", "Wardrobe"]

        // Placeholder for the full library list (add more names here as needed)
        private let libraryProps: [String] = ["Plant", "Bookshelf", "Fridge", "Wardrobe","Handbag", "Flower Vase","Bag Pack","Shoe Rack"] // Added more items for demonstration
    
    // MARK: - Wall Texture Data Sources
        private let wallTextures: [String] = ["Brick", "Wooden", "Glass"]
    
    // Single list for backgrounds since there are no tabs.
        private let backgroundItems: [String] = ["Framed sunset", "Stairwell", "Forest Landscape", "Temple", "Dining Area", "Open terrace","Industrial Hall","Backyard"]
    
    
    
    
    
    
    // MARK: - Constraint Properties (To be managed dynamically)
        private var titleCenterYConstraint: NSLayoutConstraint!
        private var titleBottomConstraint: NSLayoutConstraint!
        private var tabBottomConstraint: NSLayoutConstraint!
    
    // MARK: - Views (Private UI Components)
    
    private let dragHandle: UIView = {
        let h = UIView()
        h.backgroundColor = UIColor.systemGray4
        h.layer.cornerRadius = 2.5
        h.translatesAutoresizingMaskIntoConstraints = false
        return h
    }()

    private let headerBar: UIView = {
        let h = UIView()
        // Custom Purple color: #3E3962
        h.backgroundColor = UIColor(red: 14/255, green: 14/255, blue: 24/255, alpha: 1.0)
        h.translatesAutoresizingMaskIntoConstraints = false
        return h
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        l.textColor = .white
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let closeButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("✕", for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .regular)
        b.tintColor = .white
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: - Custom Button Factory
        private func createDeepCarmineConfirmButton() -> UIButton {
            let b = UIButton(type: .system)
            b.setImage(UIImage(systemName: "checkmark"), for: .normal)
            b.setTitle(nil, for: .normal)
            b.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
            
            // --- Deep Carmine Styling (#A9203E) ---
            b.backgroundColor = UIColor(red: 169/255, green: 32/255, blue: 62/255, alpha: 1.0)
            b.layer.cornerRadius = 20
            b.clipsToBounds = true
            b.tintColor = .white
            // -------------------------------------
            
            b.translatesAutoresizingMaskIntoConstraints = false
            return b
        }
        
        // REDEFINE the confirm button property using the factory
        private lazy var confirmButton: UIButton = {
            let button = createDeepCarmineConfirmButton()
            return button
        }()

    // MARK: - Views (Private UI Components)
        // ... (dragHandle, headerBar, titleLabel, closeButton, confirmButton are unchanged) ...

    // MARK: - Horizontal Item Selection Grid (Camera, Props)
        private lazy var itemCollectionView: UICollectionView = { // Renamed for clarity
            let layout = UICollectionViewFlowLayout()
            // *** KEY CHANGE: Scroll direction is horizontal ***
            layout.scrollDirection = .horizontal
            layout.minimumLineSpacing = 16
            layout.minimumInteritemSpacing = 16
            
            let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
            cv.backgroundColor = .clear
            cv.showsHorizontalScrollIndicator = true // Show scroll indicator
            cv.translatesAutoresizingMaskIntoConstraints = false
            cv.register(ItemCardCell.self, forCellWithReuseIdentifier: ItemCardCell.reuseID)
            cv.dataSource = self
            cv.delegate = self
            return cv
        }()
        
        // MARK: - Detail/Input Fields (Camera, Lights)
        private let detailStackView: UIStackView = {
            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 24
            stack.translatesAutoresizingMaskIntoConstraints = false
            return stack
        }()

    
    
    
    // MARK: - Core Content Stack (Holds everything below the header)
        private let coreContentStack: UIStackView = {
            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 24 // Spacing between the collection view and the detail stack
            stack.translatesAutoresizingMaskIntoConstraints = false
            return stack
        }()
        
       
    
    
    // MARK: - Body Content Scroll Views
        private let scrollView: UIScrollView = {
            let sv = UIScrollView()
            sv.translatesAutoresizingMaskIntoConstraints = false
            sv.alwaysBounceVertical = true
            return sv
        }()

        private let contentView: UIView = {
            let v = UIView()
            v.translatesAutoresizingMaskIntoConstraints = false
            return v
        }()
        
        // NOTE: The 'itemCollectionView' property defined previously will remain and be placed inside the contentView.
        // The 'detailStackView' will also remain.
    
    
    
    
        private func createInputField(label: String, placeholder: String) -> UIView {
            let container = UIStackView()
            container.axis = .vertical
            container.spacing = 4
            
            let labelView = UILabel()
            labelView.text = label
            labelView.textColor = .systemGray
            labelView.font = UIFont.systemFont(ofSize: 14)
            
            let textField = UITextField()
            textField.placeholder = placeholder
            textField.textColor = .white
            textField.borderStyle = .none
            // Add a line underneath
            let separator = UIView()
            separator.backgroundColor = .systemGray5
            separator.heightAnchor.constraint(equalToConstant: 2).isActive = true
            
            container.addArrangedSubview(labelView)
            container.addArrangedSubview(textField)
            container.addArrangedSubview(separator)
            return container
        }

        // Reuse the custom color picker from EditCharacterVC (if you copied it to the canvas VC)
        private func createDetailColorPicker() -> UIView {
            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = 16

            let titleLabel = UILabel()
            titleLabel.text = "Color:"
            titleLabel.textColor = .systemGray
            titleLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true
            
            // Swatch
            let colorSwatch = UIView()
            colorSwatch.backgroundColor = .white
            colorSwatch.layer.cornerRadius = 4
            colorSwatch.widthAnchor.constraint(equalToConstant: 32).isActive = true
            colorSwatch.heightAnchor.constraint(equalToConstant: 32).isActive = true
            colorSwatch.layer.borderWidth = 1
            colorSwatch.layer.borderColor = UIColor.systemGray.cgColor

            // Color Wheel (reusing the logic from the EditCharacterVC)
            let colorWheel = ColorWheelView() // Assumes ColorWheelView class is available
            colorWheel.widthAnchor.constraint(equalToConstant: 40).isActive = true
            colorWheel.heightAnchor.constraint(equalToConstant: 40).isActive = true

            row.addArrangedSubview(titleLabel)
            row.addArrangedSubview(colorSwatch)
            row.addArrangedSubview(colorWheel)
            
            return row
        }
    
    // Helper function for the Light intensity/temperature/shadow sliders
        private func createSliderRow(title: String, min: Float, max: Float) -> UIView {
            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = 16
            
            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.textColor = .systemGray
            titleLabel.widthAnchor.constraint(equalToConstant: 100).isActive = true
            
            let slider = UISlider()
            slider.minimumValue = min
            slider.maximumValue = max
            slider.value = (min + max) / 2
            slider.tintColor = .systemYellow // Light color for visual style
            
            let valueLabel = UILabel()
            valueLabel.text = String(format: "%.0f", slider.value)
            valueLabel.textColor = .white
            valueLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true
            
            row.addArrangedSubview(titleLabel)
            row.addArrangedSubview(slider)
            row.addArrangedSubview(valueLabel)
            
            // You will need to add a target action to update the valueLabel in the future
            
            return row
        }
    // MARK: - Conditional Layout
        private func setupHeaderLayout() {
            // Deactivate the dynamic constraints related to the two-line layout
            titleBottomConstraint.isActive = false
            tabBottomConstraint.isActive = false
            
            // Check if we need the two-line header (Character OR Props)
                    if itemType == "Character" || itemType == "Props" {
                        // --- CHARACTER/PROPS LAYOUT (Requires Tabs) ---
                        tabSegmentedControl.isHidden = false // <<< SHOW TABS FOR PROPS
                        confirmButton.isHidden = (itemType == "Character") // Hide CONFIRM for Character, show for Props
                        
                        titleLabel.text = (itemType == "Character") ? "Add Character" : "Add Props"
                        
                        // Activate the two-line header constraints
                        titleBottomConstraint.isActive = true
                        tabBottomConstraint.isActive = true
                        
                    } else {
                // --- GENERIC LAYOUT (Title centered vertically using Top/Bottom alignment) ---
                tabSegmentedControl.isHidden = true
                confirmButton.isHidden = false // <<< SHOW CONFIRM
                titleLabel.text = "Add \(itemType)"
                
                // For single-line titles, we deactivate the bottom constraint to let the STATIC top constraint work alone.
                // This centers the single line visually as it fights no other constraint.
                        
                        // Activate the single-line header constraint
                                    titleCenterYConstraint.isActive = true
                        
            }
            
        
            itemCollectionView.reloadData()
            // Force layout update
            headerBar.layoutIfNeeded()
        }
    
    
    
    // MARK: - Conditional Layout Setup (Body)
        private func setupBodyLayout() {
            // Reset visibility for all changeable views
            detailStackView.isHidden = true // Hide all detail fields by default
            
            // Change scroll direction based on type
            if let layout = itemCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                // Default to Vertical for Character, Prop, Background
                layout.scrollDirection = .vertical
            }
            
            let detailFields: [UIView] = []
            
            switch itemType {
            case "Camera":
                // Horizontal Scroll, Details visible (Name, Notes, Color)
                if let layout = itemCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                    layout.scrollDirection = .horizontal
                }
                detailStackView.isHidden = false
                
                // Rebuild detail stack for Camera
                detailStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
                detailStackView.addArrangedSubview(createInputField(label: "Name", placeholder: "e.g., Wide Shot Camera"))
                detailStackView.addArrangedSubview(createInputField(label: "Notes", placeholder: "e.g., Primary A-Cam"))
                detailStackView.addArrangedSubview(createDetailColorPicker()) // Color picker row
                
            case "Lights":
                // Horizontal Scroll, Details visible (Intensity, Temperature, Shadows, Color)
                if let layout = itemCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                    layout.scrollDirection = .horizontal
                }
                detailStackView.isHidden = false
                
                // Rebuild detail stack for Lights
                detailStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
                detailStackView.addArrangedSubview(createSliderRow(title: "Intensity:", min: 0, max: 100))
                detailStackView.addArrangedSubview(createSliderRow(title: "Temperature:", min: 2000, max: 8000))
                detailStackView.addArrangedSubview(createSliderRow(title: "Shadows:", min: 0, max: 1))
                detailStackView.addArrangedSubview(createDetailColorPicker())
            
                
                
                
            case "Character", "Props", "Background":
                // Vertical Scroll, NO Details visible
                detailStackView.isHidden = true
                // Scroll direction defaults to vertical above
                
            default:
                detailStackView.isHidden = true
            }
            
            // Important: Reload data to apply the new scroll direction and sizing
            itemCollectionView.reloadData()
            view.layoutIfNeeded()
        }
    
    
    //add the segmented control view and constraints to integrate it into the headerBar immediately after the titleLabel.
    private let tabSegmentedControl: UISegmentedControl = {
            let sc = UISegmentedControl(items: ["Film", "Library"])
            sc.selectedSegmentIndex = 0 // Default to Library
            sc.selectedSegmentTintColor = .white
            sc.backgroundColor = UIColor.black.withAlphaComponent(0.2) // Dark background for contrast
            sc.tintColor = .white
            
            // Customize text attributes for contrast against purple header
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold)
            ]
            sc.setTitleTextAttributes(attributes, for: .normal)
            
            let selectedAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.black, // Selected text color
            ]
            sc.setTitleTextAttributes(selectedAttributes, for: .selected)
            
            sc.translatesAutoresizingMaskIntoConstraints = false
            sc.addTarget(self, action: #selector(handleTabChange), for: .valueChanged)
            return sc
        }()
    
    
    
    
    // MARK: - Lifecycle
        override func viewDidLoad() {
            super.viewDidLoad()
            
            // CRITICAL FIX: Tell the view controller to extend its layout edges underneath the safe area.
                    // This ensures the UIScrollView can use the full height of the modal, down to the bottom edge.
                    if #available(iOS 11.0, *) {
                        // Deprecated in iOS 13+, but this is the robust way to handle the modal extending fully
                        self.edgesForExtendedLayout = .bottom
                    }
            
            // --- Set Initial Data Source (Default to Film Tab) ---
                    if itemType == "Character" {
                        // Segmented control defaults to index 0 ("Film")
                        itemsToDisplay = filmCharacters
                    }else if itemType == "Props" {
                        // Segmented control defaults to index 0 ("Film")
                        itemsToDisplay = filmProps
                    }else if itemType == "Background" {
                        itemsToDisplay = backgroundItems // Use the single list
                    }else if itemType == "Wall" { // <<< ADDED WALL INITIALIZATION
                        itemsToDisplay = wallTextures
                    }
            
            
            view.backgroundColor = UIColor(red: 14/255, green: 14/255, blue: 24/255, alpha: 1.0)
            setupViews()
            setupConstraints()
            setupHeaderLayout()
            setupBodyLayout()// <<< CALL THE NEW CONDITIONAL SETUP
        }
    
    
    
    
    // MARK: - Setup
    private func setupViews() {
        // Add all subviews to the main view
        view.addSubview(dragHandle)
        view.addSubview(headerBar)
        headerBar.addSubview(titleLabel)
        headerBar.addSubview(closeButton)
        headerBar.addSubview(tabSegmentedControl)
        headerBar.addSubview(confirmButton)

        // --- NEW: Add ScrollView Hierarchy ---
                view.addSubview(scrollView)
                scrollView.addSubview(contentView)
                
        // --- ADD CORE CONTENT STACK TO CONTENT VIEW ---
                contentView.addSubview(coreContentStack)
                
                // --- ADD COLLECTION VIEW AND DETAIL STACK TO CORE CONTENT STACK ---
                coreContentStack.addArrangedSubview(itemCollectionView)
                coreContentStack.addArrangedSubview(detailStackView)
        
        // Add input fields to the detail stack
                detailStackView.addArrangedSubview(createInputField(label: "Name", placeholder: "e.g., Default"))
                detailStackView.addArrangedSubview(createInputField(label: "Notes", placeholder: "e.g., Default Camera"))
                detailStackView.addArrangedSubview(createDetailColorPicker())
        
        // Add button actions
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
    }

    private func setupConstraints() {
        // Drag handle constraints (STATIC)
        NSLayoutConstraint.activate([
            dragHandle.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            dragHandle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dragHandle.widthAnchor.constraint(equalToConstant: 36),
            dragHandle.heightAnchor.constraint(equalToConstant: 5)
        ])

        // HeaderBar constraints (STATIC)
        NSLayoutConstraint.activate([
            headerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerBar.topAnchor.constraint(equalTo: dragHandle.bottomAnchor, constant: 8),
            headerBar.heightAnchor.constraint(equalToConstant: 56)
        ])

        // Title and buttons (STATIC)
                NSLayoutConstraint.activate([
                    // Close Button
                    closeButton.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
                    closeButton.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor, constant: 12),
                    closeButton.widthAnchor.constraint(equalToConstant: 44),

                    // Confirm Button Constraints
                            confirmButton.trailingAnchor.constraint(equalTo: headerBar.trailingAnchor, constant: -16),
                            confirmButton.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
                            confirmButton.widthAnchor.constraint(equalToConstant: 40),
                            confirmButton.heightAnchor.constraint(equalToConstant: 40),
                    
                    // Tab Segmented Control (Center it vertically in the header bar for maximum space)
                    tabSegmentedControl.centerXAnchor.constraint(equalTo: headerBar.centerXAnchor),
                    tabSegmentedControl.widthAnchor.constraint(equalToConstant: 180),
                    tabSegmentedControl.heightAnchor.constraint(equalToConstant: 28), // Reduce height slightly to save space
                    
                    // --- ADD THIS NEW STATIC CONSTRAINT FOR TITLE VERTICAL POSITION ---
                                titleLabel.topAnchor.constraint(equalTo: headerBar.topAnchor, constant: 4),
                                titleLabel.centerXAnchor.constraint(equalTo: headerBar.centerXAnchor), // Ensure it is centered horizontally
               ])
                    
        
        // --- DYNAMIC CONSTRAINTS SETUP (Define but DO NOT activate here) ---
                // 1. Centered Title Constraint (For Props, Lights, etc.)
                titleCenterYConstraint = titleLabel.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor)

                // 2. Title pinned above Tabs (For Character)
                titleBottomConstraint = titleLabel.bottomAnchor.constraint(equalTo: tabSegmentedControl.topAnchor, constant: -2)
                
                // 3. Tabs pushed down (For Character)
                tabBottomConstraint = tabSegmentedControl.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor, constant: 10)

        
        // --- START CONSTRAINTS FOR CONTENT BODY ---
            
        // --- 1. ScrollView Constraints (Below HeaderBar, Anchored to View Bottom) ---
            NSLayoutConstraint.activate([
                scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                scrollView.topAnchor.constraint(equalTo: headerBar.bottomAnchor),

                // CRITICAL FIX: Anchor scroll view to the absolute bottom of the view's frame.
                scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])

            // --- 2. ContentView Constraints (Ensuring Vertical Scrolling) ---

            // CRITICAL FIX 2: Ensure content view width matches the scroll view's frame width
            let contentViewWidthConstraint = contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
            contentViewWidthConstraint.isActive = true

            NSLayoutConstraint.activate([
                contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),

                // This bottom anchor drives the overall scrollable content size:
                contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            ])
        
        // --- 3. CORE CONTENT STACK Constraints ---
                let padding: CGFloat = 24
                let bottomPadding: CGFloat = 80 // Ensures scrolling is active
                
                NSLayoutConstraint.activate([
                    // Pin stack view horizontally and vertically inside the contentView
                    coreContentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
                    coreContentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
                    coreContentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: padding),
                    
                    // CRITICAL FIX: Pin stack view bottom to contentView bottom. This forces scrolling.
                    coreContentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -bottomPadding)
                ])

                // --- 4. Enforce Collection View Height inside the Stack ---
                let horizontalGridHeight: CGFloat = 360
                NSLayoutConstraint.activate([
                    // Ensure the item collection view has a fixed height within the stack
                    itemCollectionView.heightAnchor.constraint(equalToConstant: horizontalGridHeight),
                ])

            // --- END CONSTRAINTS FOR CONTENT BODY ---
        }
       
        
        
        
    
        
    

    

    // MARK: - Actions
    @objc private func didTapClose() {
        dismiss(animated: true)
    }

// Restore the missing confirm action (required by constraints/targets)
    @objc private func didTapConfirm() {
        // Find the selected item in the collection view if needed, or simply pass a default value.
        // For simplicity now, we just dismiss, as the Confirm button is for non-Character modals.
        dismiss(animated: true)
    }
    

 
    // MARK: - Tab Handling
        @objc private func handleTabChange(_ sender: UISegmentedControl) {
            if itemType == "Character" {
                // Only handle data change if the modal is for "Character"
                if sender.selectedSegmentIndex == 0 {
                    // --- Film Tab Selected ---
                    itemsToDisplay = filmCharacters // Set to the limited list
                    
                } else {
                    // --- Library Tab Selected ---
                    itemsToDisplay = libraryCharacters // Set to the full list
                    
                }
                
                
            }else if itemType == "Props" {
                if sender.selectedSegmentIndex == 0 {
                    // --- Props Film Tab Selected ---
                    itemsToDisplay = filmProps // Use the limited list for Film
                } else {
                    // --- Props Library Tab Selected ---
                    itemsToDisplay = libraryProps // Use the full list for Library
                }
            }
            
            
            // Reload the Collection View to show the new set of items
            itemCollectionView.reloadData()
            // Re-run header layout just in case of any title/tab dependency
            setupHeaderLayout()
        }

}






// MARK: - UICollectionViewDataSource & Delegate
extension ItemPickerVC: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    // 1. Number of items
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return itemsToDisplay.count
    }
    
    // 2. Cell for item
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ItemCardCell.reuseID, for: indexPath) as? ItemCardCell else {
            return UICollectionViewCell()
        }
        let itemName = itemsToDisplay[indexPath.row]
        cell.itemName = itemName
        
        // This is where you would load the actual image asset:
        // cell.imageView.image = UIImage(named: itemName)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            
            if itemType == "Camera" || itemType == "Lights" {
                // Horizontal scroll cards (Tall and narrow)
                let width: CGFloat = 280
                let height: CGFloat = 300
                return CGSize(width: width, height: height)
                
            } else {
                // Vertical scroll grid (Character/Props/Background 3-column block layout)
                let totalPadding: CGFloat = 16 * 4 // Padding on left/right edges + between items (two 16px margins)
                
                // Calculate width for 3 columns
                let width = (collectionView.bounds.width - totalPadding) / 3
                let height: CGFloat = 1.3 * width // Maintain card aspect ratio (e.g., 130%)
                
                return CGSize(width: width, height: height)
            }
        }
    
    
    
    // 4. Handle item tap/selection
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedItemName = itemsToDisplay[indexPath.row]
        
        // NEW: Dismiss the current modal and launch the Edit modal
        dismiss(animated: true) { [weak self] in
            // The presenting VC (MyFeatureCanvasVC) needs to launch the second modal
            self?.onItemSelected?(selectedItemName)
        }
    }
    
}
