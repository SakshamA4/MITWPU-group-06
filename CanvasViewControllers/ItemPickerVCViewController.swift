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
    
    // Property to set the modal's title from the presenting VC
    var modalTitle: String = "Select Item" {
        didSet {
            titleLabel.text = modalTitle
        }
    }
    
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
        h.backgroundColor = UIColor(red: 62/255, green: 57/255, blue: 98/255, alpha: 1.0)
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

    private let confirmButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("✓", for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        b.tintColor = .white
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

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

    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 16
        sv.alignment = .fill
        sv.distribution = .fill
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    //add the segmented control view and constraints to integrate it into the headerBar immediately after the titleLabel.
    private let tabSegmentedControl: UISegmentedControl = {
            let sc = UISegmentedControl(items: ["Library", "New"])
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
        
        // This view is presented by the custom controller, it must have a background
        view.backgroundColor = .systemBackground
        
        setupViews()
        setupConstraints()
        populateSampleItems()
    }
    
    // MARK: - Setup
    private func setupViews() {
        // Add all subviews to the main view
        view.addSubview(dragHandle)
        view.addSubview(headerBar)
        headerBar.addSubview(titleLabel)
        headerBar.addSubview(closeButton)
        headerBar.addSubview(confirmButton)
        headerBar.addSubview(tabSegmentedControl)

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        
        // Add button actions
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(didTapConfirm), for: .touchUpInside)
    }

    private func setupConstraints() {
        // Drag handle constraints (Top center)
        NSLayoutConstraint.activate([
            dragHandle.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            dragHandle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dragHandle.widthAnchor.constraint(equalToConstant: 36),
            dragHandle.heightAnchor.constraint(equalToConstant: 5)
        ])

        // HeaderBar constraints (Full width, below drag handle)
        NSLayoutConstraint.activate([
            headerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerBar.topAnchor.constraint(equalTo: dragHandle.bottomAnchor, constant: 8),
            headerBar.heightAnchor.constraint(equalToConstant: 56)
        ])

        // Title and buttons (FINAL ADJUSTED CONSTRAINTS)
                NSLayoutConstraint.activate([
                    // Close Button
                    closeButton.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
                    closeButton.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor, constant: 12),
                    closeButton.widthAnchor.constraint(equalToConstant: 44),

                    // Confirm Button
                    confirmButton.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
                    confirmButton.trailingAnchor.constraint(equalTo: headerBar.trailingAnchor, constant: -12),
                    confirmButton.widthAnchor.constraint(equalToConstant: 44),
                    
                    // Tab Segmented Control (Center it vertically in the header bar for maximum space)
                    tabSegmentedControl.centerXAnchor.constraint(equalTo: headerBar.centerXAnchor),
                    tabSegmentedControl.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor, constant: 10), // Push the tabs down slightly
                    tabSegmentedControl.widthAnchor.constraint(equalToConstant: 180),
                    tabSegmentedControl.heightAnchor.constraint(equalToConstant: 28), // Reduce height slightly to save space
                    
                    // Title Label (Pinned right above the tabs)
                    titleLabel.centerXAnchor.constraint(equalTo: headerBar.centerXAnchor),
                    titleLabel.bottomAnchor.constraint(equalTo: tabSegmentedControl.topAnchor, constant: -2) // Tight margin above tabs
                ])
        
        // ScrollView constraints (Fills remaining space below headerBar)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: headerBar.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // IMPORTANT: contentView constraints for vertical scrolling only
        let contentViewWidthConstraint = contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        contentViewWidthConstraint.priority = .defaultHigh // Lower priority to avoid conflicts
        
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentViewWidthConstraint
        ])

        // StackView (fills contentView with padding)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }

    // MARK: - Item Card Creation
    private func populateSampleItems() {
        let items = [
            "Man in a Suit", "Asian man", "Woman 1", "Woman 2",
            "Man in a jersey", "Talking Man", "Lying down", "Waving Man"
        ]
        
        for name in items {
            let itemCard = makeItemView(title: name)
            stackView.addArrangedSubview(itemCard)
        }
    }

    private func makeItemView(title: String) -> UIView {
        let container = UIButton() // Use UIButton for easy tap handling
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor.systemGray6
        container.layer.cornerRadius = 12
        container.clipsToBounds = true
        container.addTarget(self, action: #selector(didTapItem(_:)), for: .touchUpInside)
        container.accessibilityLabel = title // Store item name here

        let label = UILabel()
        label.text = title
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false

        let imageView = UIImageView(image: UIImage(systemName: "person.crop.circle.fill"))
        imageView.tintColor = .systemGray
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(imageView)
        container.addSubview(label)


        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 120), // Card height
            
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            imageView.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            imageView.widthAnchor.constraint(equalToConstant: 60),
            imageView.heightAnchor.constraint(equalToConstant: 60),
            
            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16)
        ])
        return container
    }

    // MARK: - Actions
    @objc private func didTapClose() {
        dismiss(animated: true)
    }

    @objc private func didTapConfirm() {
        dismiss(animated: true)
    }
    
    @objc private func didTapItem(_ sender: UIButton) {
        guard let selectedItemName = sender.accessibilityLabel else { return }
        
        // 1. Trigger the callback with the selected item's name
        onItemSelected?(selectedItemName)
        
        // 2. Dismiss the modal
        dismiss(animated: true)
    }
    
    // MARK: - Tab Handling
        @objc private func handleTabChange(_ sender: UISegmentedControl) {
            // Clear old content
            stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            
            if sender.selectedSegmentIndex == 0 {
                // Library Tab
                modalTitle = "Add Character from Library"
                populateSampleItems()
            } else {
                // New Tab
                modalTitle = "Add New Character"
                // Example: Add placeholder content for the "New" tab
                let placeholder = UILabel()
                placeholder.text = "Design a new character here..."
                placeholder.textColor = .lightGray
                placeholder.textAlignment = .center
                
                // Add custom height constraint for the placeholder
                placeholder.heightAnchor.constraint(equalToConstant: 200).isActive = true
                stackView.addArrangedSubview(placeholder)
            }
        }
}

