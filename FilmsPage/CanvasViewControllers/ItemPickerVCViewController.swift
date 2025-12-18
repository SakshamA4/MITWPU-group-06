//
// ItemPickerVC.swift
// FilmsPage
//
// Created by Ritik
//

import UIKit

// Typealias for the callback function
typealias ItemSelectionCallback = (String) -> Void

class ItemPickerVC: UIViewController {

    // MARK: - Public Properties
    var onItemSelected: ItemSelectionCallback? // Closure to send data back to ViewController
    
    // MARK: - Public Properties for Generic Content
        var itemType: String = "Character"
        var itemsToDisplay: [String] = []
        var modalTitle: String = "Select Item" {
            didSet {
                titleLabel.text = modalTitle
            }
        }
    private var pendingSelectedItem: String?
    // MARK: - Character Data Sources
    private let filmCharacters: [String] = ["Man in a suit", "Woman 1", "Asian man"]

    private let libraryCharacters: [String] = ["Man in a suit","Woman 1", "Asian man",  "Woman 2", "Man in a jersey", "Woman 3"]
    
    // MARK: - Prop Data Sources
    private let filmProps: [String] = ["Plant", "Bookshelf", "Fridge", "Wardrobe"]
    private let libraryProps: [String] = ["Plant", "Bookshelf", "Fridge", "Wardrobe","Handbag", "Flower Vase","Bag Pack","Shoe Rack"]
    
    // MARK: - Wall Texture Data Sources
    private let wallTextures: [String] = ["Brick", "Wooden", "Glass"]
    
    // Single list for backgrounds since there are no tabs.
    private let backgroundItems: [String] = ["Framed sunset", "Stairwell", "Forest Landscape", "Temple", "Dining Area", "Open terrace","Industrial Hall","Backyard"]
    
    // MARK: - Constraint Properties (To be managed dynamically)
        private var titleCenterYConstraint: NSLayoutConstraint!
        private var titleBottomConstraint: NSLayoutConstraint!
        private var tabBottomConstraint: NSLayoutConstraint!
        private var detailStackHalfWidthConstraint: NSLayoutConstraint!
        private var collectionViewHeightConstraint: NSLayoutConstraint!
    
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
        h.backgroundColor = UIColor(red: 14/255, green: 14/255, blue: 24/255, alpha: 1.0)
        h.translatesAutoresizingMaskIntoConstraints = false
        return h
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.font = UIFont.systemFont(ofSize: 30, weight: .bold)
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
    
        private lazy var confirmButton: UIButton = {
            let button = createDeepCarmineConfirmButton()
            return button
        }()

        // MARK: - Horizontal Item Selection Grid (Camera, Props)
        private lazy var itemCollectionView: UICollectionView = {
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .horizontal
            layout.minimumLineSpacing = 16
            layout.minimumInteritemSpacing = 16
            
            let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
            cv.backgroundColor = .clear
            cv.showsHorizontalScrollIndicator = true
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
            stack.spacing = 15
            stack.translatesAutoresizingMaskIntoConstraints = false
            return stack
        }()

        // MARK: - Core Content Stack (Holds everything below the header)
        private let coreContentStack: UIStackView = {
            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 5 // Spacing between the collection view and the detail stack
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
        
       private func createInputField(label: String, placeholder: String) -> UIView {
            let container = UIStackView()
            container.axis = .vertical
            container.spacing = 4
            
            let labelView = UILabel()
            labelView.text = label
            labelView.textColor = .white
            labelView.font = UIFont.systemFont(ofSize: 14)
            
            let textField = UITextField()
            textField.placeholder = placeholder
            textField.textColor = .white
            textField.borderStyle = .none
            // Added a line underneath
            let separator = UIView()
            separator.backgroundColor = .systemGray
            separator.heightAnchor.constraint(equalToConstant: 2).isActive = true
            
            container.addArrangedSubview(labelView)
            container.addArrangedSubview(textField)
            container.addArrangedSubview(separator)
            return container
        }


    private func createSystemColorPicker(title: String) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 16

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 16)
        titleLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true

        // The Native iOS Color Well
        let colorWell = UIColorWell()
        colorWell.selectedColor = .white
        colorWell.title = title
        colorWell.supportsAlpha = true
        colorWell.addTarget(self, action: #selector(colorChanged(_:)), for: .valueChanged)
        colorWell.translatesAutoresizingMaskIntoConstraints = false

        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(colorWell)
        
        // Flexible spacer to keep items left-aligned
        let spacer = UIView()
        row.addArrangedSubview(spacer)

        return row
    }

    @objc private func colorChanged(_ sender: UIColorWell) {
        guard let color = sender.selectedColor else { return }
        print("New color selected from well: \(color)")
    }
    
    
        // Helper function for the Light intensity/temperature/shadow sliders
        private func createSliderRow(title: String, min: Float, max: Float) -> UIView {
            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = 16
            
            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.textColor = .white
            titleLabel.widthAnchor.constraint(equalToConstant: 110).isActive = true
            
            let slider = UISlider()
            slider.minimumValue = min
            slider.maximumValue = max
            slider.value = (min + max) / 2
            slider.tintColor = .systemYellow // Light color for visual style
            
            let valueLabel = UILabel()
            valueLabel.text = String(format: "%.0f", slider.value)
            valueLabel.textColor = .white
            valueLabel.widthAnchor.constraint(equalToConstant: 60).isActive = true
            
            row.addArrangedSubview(titleLabel)
            row.addArrangedSubview(slider)
            row.addArrangedSubview(valueLabel)
            
            return row
        }
    
        // MARK: - Conditional Layout
        private func setupHeaderLayout() {
            titleCenterYConstraint.isActive = false
            titleBottomConstraint.isActive = false
            tabBottomConstraint.isActive = false
            
            // Check if we need the two-line header (Character OR Props)
                    if itemType == "Character" || itemType == "Props" {
                        tabSegmentedControl.isHidden = false
                        confirmButton.isHidden = (itemType == "Character")
                        titleLabel.text = (itemType == "Character") ? "Add Character" : "Add Props"
                        
                      
                        titleBottomConstraint.isActive = true
                        tabBottomConstraint.isActive = true
                        
                    } else {
                tabSegmentedControl.isHidden = true
                confirmButton.isHidden = false
                titleLabel.text = "Add \(itemType)"
                // Activate the single-line header constraint
                titleCenterYConstraint.isActive = true
                        
            }
            itemCollectionView.reloadData()
            headerBar.layoutIfNeeded()
        }
        // MARK: - Conditional Layout Setup (Body)
        private func setupBodyLayout() {
            
            detailStackView.isHidden = true // Hide all detail fields by default
            detailStackHalfWidthConstraint.isActive = false
            
            // Change scroll direction based on type
            if let layout = itemCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                // Default to Vertical for Character, Prop, Background
                layout.scrollDirection = .vertical
            }
            
            let detailFields: [UIView] = []
            
                // Clear any previous detail views
                detailStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
                collectionViewHeightConstraint.constant = 9999
            
            switch itemType {
            case "Camera":
                if let layout = itemCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                    layout.scrollDirection = .horizontal
                }
                detailStackView.isHidden = false
                detailStackHalfWidthConstraint.isActive = true
               
                detailStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
                detailStackView.addArrangedSubview(createInputField(label: "Name", placeholder: "e.g., Wide Shot Camera"))
                detailStackView.addArrangedSubview(createInputField(label: "Notes", placeholder: "e.g., Primary A-Cam"))
                detailStackView.addArrangedSubview(createSystemColorPicker(title: "Color:"))
                collectionViewHeightConstraint.constant = 250
 
            case "Lights":
                if let layout = itemCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                    layout.scrollDirection = .horizontal
                }
                detailStackView.isHidden = false
                
                // 1. DEACTIVATE the half-width constraint to let the two columns use more space
                detailStackHalfWidthConstraint.isActive = false
                
                // 2. Clear any previous detail views
                detailStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
                
                // 3. Create a Horizontal Parent Stack to hold the two columns
                let columnsStack = UIStackView()
                columnsStack.axis = .horizontal
                columnsStack.distribution = .fillEqually
                columnsStack.spacing = 40 // Gap between the left and right side
                
                // 4. Create the Left Column (Intensity & Temperature)
                let leftColumn = UIStackView()
                leftColumn.axis = .vertical
                leftColumn.spacing = 15
                leftColumn.addArrangedSubview(createSliderRow(title: "Intensity:", min: 0, max: 100))
                leftColumn.addArrangedSubview(createSliderRow(title: "Temperature:", min: 2000, max: 8000))
                
                // 5. Create the Right Column (Shadows & Color)
                let rightColumn = UIStackView()
                rightColumn.axis = .vertical
                rightColumn.spacing = 15
                rightColumn.addArrangedSubview(createSliderRow(title: "Shadows:", min: 0, max: 1))
                rightColumn.addArrangedSubview(createSystemColorPicker(title: "Color:"))
                
                // 6. Assemble the columns into the Parent Stack
                columnsStack.addArrangedSubview(leftColumn)
                columnsStack.addArrangedSubview(rightColumn)
                
                // 7. Add the assembled columns to your main detailStackView
                detailStackView.addArrangedSubview(columnsStack)
                
                collectionViewHeightConstraint.constant = 250
            case "Wall":
                    detailStackView.isHidden = false
                    detailStackHalfWidthConstraint.isActive = true
                    detailStackView.addArrangedSubview(createSliderRow(title: "Wall Height:", min: 10, max: 50))
                    detailStackView.addArrangedSubview(createSystemColorPicker(title: "Wall Color:"))
                
            case "Character", "Props", "Background":
                detailStackView.isHidden = true
            default:
                detailStackView.isHidden = true
            }
            
            // Important: Reload data to apply the new scroll direction and sizing
            itemCollectionView.reloadData()
            view.layoutIfNeeded()
        }
    //added the segmented control view and constraints to integrate it into the headerBar immediately after the titleLabel.
    private let tabSegmentedControl: UISegmentedControl = {
            let sc = UISegmentedControl(items: ["Film", "Library"])
            sc.selectedSegmentIndex = 0 // Default to Library
            sc.selectedSegmentTintColor = .white
            sc.backgroundColor = UIColor.black.withAlphaComponent(0.2)
            sc.tintColor = .white

            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
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
            // This ensures the UIScrollView can use the full height of the modal, down to the bottom edge.
                    if #available(iOS 11.0, *) {
                        // Deprecated in iOS 13+, but this is the robust way to handle the modal extending fully
                        self.edgesForExtendedLayout = .bottom
                    }
            
            // --- Set Initial Data Source (Default to Film Tab) ---
                    if itemType == "Character" {
                        itemsToDisplay = filmCharacters
                    }else if itemType == "Props" {
                        itemsToDisplay = filmProps
                    }else if itemType == "Background" {
                        itemsToDisplay = backgroundItems
                    }else if itemType == "Wall" {
                        itemsToDisplay = wallTextures
                    }
            
            view.backgroundColor = UIColor(red: 14/255, green: 14/255, blue: 24/255, alpha: 1.0)
            
            setupViews()
            setupConstraints()
            setupHeaderLayout()
            setupBodyLayout()
        }
    
    // MARK: - Setup
    private func setupViews() {
        
        view.addSubview(dragHandle)
        view.addSubview(headerBar)
        headerBar.addSubview(titleLabel)
        headerBar.addSubview(closeButton)
        headerBar.addSubview(tabSegmentedControl)
        headerBar.addSubview(confirmButton)

                //Added ScrollView Hierarchy
                view.addSubview(scrollView)
                scrollView.addSubview(contentView)
                
                //Added CORE CONTENT STACK TO CONTENT VIEW
                contentView.addSubview(coreContentStack)
                
                //Added COLLECTION VIEW AND DETAIL STACK TO CORE CONTENT STACK
                coreContentStack.addArrangedSubview(itemCollectionView)
                coreContentStack.addArrangedSubview(detailStackView)
        
                //Added input fields to the detail stack
                detailStackView.addArrangedSubview(createInputField(label: "Name", placeholder: "e.g., Default"))
                detailStackView.addArrangedSubview(createInputField(label: "Notes", placeholder: "e.g., Default Camera"))
                detailStackView.addArrangedSubview(createSystemColorPicker(title: "Color:"))
        
                // Add button actions
                closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
                confirmButton.addTarget(self, action: #selector(didTapConfirm), for: .touchUpInside)
                scrollView.delaysContentTouches = false // Add this
                itemCollectionView.delaysContentTouches = false // Add this
    }

    private func setupConstraints() {
  
        NSLayoutConstraint.activate([
            dragHandle.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            dragHandle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dragHandle.widthAnchor.constraint(equalToConstant: 36),
            dragHandle.heightAnchor.constraint(equalToConstant: 5)
        ])

        NSLayoutConstraint.activate([
            headerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerBar.topAnchor.constraint(equalTo: dragHandle.bottomAnchor, constant: 8),
            headerBar.heightAnchor.constraint(equalToConstant: 80)
        ])

                // Title and buttons (STATIC)
                NSLayoutConstraint.activate([
            
                    closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
                    closeButton.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor, constant: 12),
                    closeButton.widthAnchor.constraint(equalToConstant: 44),

                  
                    confirmButton.trailingAnchor.constraint(equalTo: headerBar.trailingAnchor, constant: -16),
                    confirmButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
                    confirmButton.widthAnchor.constraint(equalToConstant: 40),
                    confirmButton.heightAnchor.constraint(equalToConstant: 40),
                    
                    tabSegmentedControl.centerXAnchor.constraint(equalTo: headerBar.centerXAnchor),
                    tabSegmentedControl.widthAnchor.constraint(equalToConstant: 180),
                    tabSegmentedControl.heightAnchor.constraint(equalToConstant: 28),
                    
                    
                    titleLabel.topAnchor.constraint(equalTo: headerBar.topAnchor, constant: 4),
                    titleLabel.centerXAnchor.constraint(equalTo: headerBar.centerXAnchor),
               ])
                    
        
                //DYNAMIC CONSTRAINTS SETUP
                // 1. Centered Title Constraint
                titleCenterYConstraint = titleLabel.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor)

                // 2. Title pinned above Tabs (For Character)
                titleBottomConstraint = titleLabel.bottomAnchor.constraint(equalTo: tabSegmentedControl.topAnchor, constant: -10)
                
                // 3. Tabs pushed down (For Character)
                tabBottomConstraint = tabSegmentedControl.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor, constant: 15)

                detailStackHalfWidthConstraint = detailStackView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5)
        
            //START CONSTRAINTS FOR CONTENT BODY
            
            //1. ScrollView Constraints (Below HeaderBar, Anchored to View Bottom)
            NSLayoutConstraint.activate([
                scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                scrollView.topAnchor.constraint(equalTo: headerBar.bottomAnchor),
                scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])

            //2. ContentView Constraints (Ensuring Vertical Scrolling)

            //Ensuring content view width matches the scroll view's frame width
            let contentViewWidthConstraint = contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
            contentViewWidthConstraint.isActive = true

            NSLayoutConstraint.activate([
                contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            ])
        
                //3. CORE CONTENT STACK Constraints
                let padding: CGFloat = 24
                let bottomPadding: CGFloat = 80
                
                NSLayoutConstraint.activate([
                    coreContentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
                    coreContentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
                    coreContentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: padding),
                    coreContentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -bottomPadding)
                ])
        //4. Enforce Collection View Height inside the Stack
        let horizontalGridHeight: CGFloat = 360
        collectionViewHeightConstraint = itemCollectionView.heightAnchor.constraint(equalToConstant: horizontalGridHeight)
        collectionViewHeightConstraint.isActive = true
        }
       
        
    // MARK: - Actions
    @objc private func didTapClose() {
        dismiss(animated: true)
    }

    @objc private func didTapConfirm() {
        guard let selectedItem = pendingSelectedItem else {
            print("No item selected. Please tap an item before confirming.")
            return
        }
        
        // Capture the callback locally
        let callback = self.onItemSelected
        
        dismiss(animated: true) {
            // Run on main thread to ensure MyFeatureCanvasVC is ready
            DispatchQueue.main.async {
                print("Confirming item: \(selectedItem)")
                callback?(selectedItem)
            }
        }
    }
        // MARK: - Tab Handling
        @objc private func handleTabChange(_ sender: UISegmentedControl) {
            if itemType == "Character" {
                if sender.selectedSegmentIndex == 0 {
                    itemsToDisplay = filmCharacters
                    } else {
                    itemsToDisplay = libraryCharacters
                    }
                
                }else if itemType == "Props" {
                if sender.selectedSegmentIndex == 0 {
                   itemsToDisplay = filmProps
                } else {
                   itemsToDisplay = libraryProps
                }
            }
            itemCollectionView.reloadData()
            setupHeaderLayout()
        }

}

// MARK: - UICollectionViewDataSource & Delegate
extension ItemPickerVC: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return itemsToDisplay.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ItemCardCell.reuseID, for: indexPath) as? ItemCardCell else {
            return UICollectionViewCell()
        }
        let itemName = itemsToDisplay[indexPath.row]
        cell.itemName = itemName
        // Manually set the selection state based on your 'pending' variable
        cell.isCurrentlySelected = (itemName == pendingSelectedItem)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            
            if itemType == "Camera" || itemType == "Lights" {
                let width: CGFloat = 232
                let height: CGFloat = 232
                return CGSize(width: width, height: height)
                
            } else if itemType == "Character"{
                let numColumns: CGFloat = 3
                let spacing: CGFloat = 16
                // 5 paddings: 2 edges (16*2) + 3 spaces between cards (16*3)
                let totalPadding = (spacing * (numColumns + 1))
                
                // Calculate width for 4 columns
                let availableWidth = collectionView.bounds.width - totalPadding
                let width = availableWidth / numColumns
                
                // Maintain a square size, approximating the 232 height/width requested
                let height: CGFloat = 250
                return CGSize(width: width, height: height)
}else {
                            let numColumns: CGFloat = 4
                            let spacing: CGFloat = 16
                            // 5 paddings: 2 edges (16*2) + 3 spaces between cards (16*3)
                            let totalPadding = (spacing * (numColumns + 1))
                            
                            // Calculate width for 4 columns
                            let availableWidth = collectionView.bounds.width - totalPadding
                            let width = availableWidth / numColumns
                            
                            // Maintain a square size, approximating the 232 height/width requested
                            let height: CGFloat = width
                            return CGSize(width: width, height: height)
            }
        }
    
    
    
    // 4. Handle item tap/selection
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        //        let selectedItemName = itemsToDisplay[indexPath.row]
        //
        //        // NEW: Dismiss the current modal and launch the Edit modal
        //        dismiss(animated: true) { [weak self] in
        //            // The presenting VC (MyFeatureCanvasVC) needs to launch the second modal
        //            self?.onItemSelected?(selectedItemName)
        //        }
        //    }
        let selectedItemName = itemsToDisplay[indexPath.row]
        
        if itemType == "Character" {
            dismiss(animated: true) { [weak self] in
                self?.onItemSelected?(selectedItemName)
            }
        } else {
            // For Camera, Props, Lights, etc., just SAVE the name and wait for confirmButton
            self.pendingSelectedItem = selectedItemName
            collectionView.reloadData()
            
        }
    }
}
