//
//  CanvasViewController+EntityAnnotation.swift
//  FilmsPage
//
//  Extension that provides rename and notes editing UI for entities.
//  Triggered from the long-press action menu via .rename / .notes actions.
//

import UIKit
import RealityKit

// MARK: - Rename & Notes UI

extension CanvasViewController {
    
    // MARK: - Rename Alert
    
    /// Presents an alert with a text field to rename the selected entity.
    func presentRenameAlert(for entity: Entity) {
        let annotation = entity.components[EntityAnnotationComponent.self]
        let currentName = annotation?.customName ?? ""
        let fallbackName = entity.name.isEmpty ? "Untitled" : entity.name
        
        let alert = UIAlertController(
            title: "Rename",
            message: "Enter a new name for this object.",
            preferredStyle: .alert
        )
        
        alert.addTextField { tf in
            tf.placeholder = fallbackName
            tf.text = currentName.isEmpty ? nil : currentName
            tf.autocapitalizationType = .words
            tf.returnKeyType = .done
            tf.clearButtonMode = .whileEditing
        }
        
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let newName = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            var comp = entity.components[EntityAnnotationComponent.self] ?? EntityAnnotationComponent()
            comp.customName = newName
            comp.lastModified = Date()
            entity.components.set(comp)
            
            // Show a brief confirmation toast
            self.showAnnotationToast(newName.isEmpty ? "Name cleared" : "Renamed to \"\(newName)\"")
            
            // Refresh sidebar if visible
            self.refreshSidebarContent()
        })
        
        alert.addAction(UIAlertAction(title: "Clear Name", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            if var comp = entity.components[EntityAnnotationComponent.self] {
                comp.customName = ""
                comp.lastModified = Date()
                entity.components.set(comp)
            }
            self.showAnnotationToast("Name cleared")
            self.refreshSidebarContent()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - Notes Editor
    
    /// Presents a sheet with a text view for editing entity notes.
    func presentNotesEditor(for entity: Entity) {
        let annotation = entity.components[EntityAnnotationComponent.self]
        let currentNotes = annotation?.notes ?? ""
        let entityName = annotation?.displayName ?? entity.name
        
        let vc = EntityNotesViewController(entityName: entityName, notes: currentNotes)
        vc.onSave = { [weak self] newNotes in
            guard let self = self else { return }
            var comp = entity.components[EntityAnnotationComponent.self] ?? EntityAnnotationComponent()
            comp.notes = newNotes
            comp.lastModified = Date()
            entity.components.set(comp)
            self.showAnnotationToast(newNotes.isEmpty ? "Notes cleared" : "Notes saved")
        }
        
        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        present(vc, animated: true)
    }
    
    // MARK: - Toast
    
    /// Brief toast for annotation actions.
    private func showAnnotationToast(_ message: String) {
        let toast = UILabel()
        toast.text = "  \(message)  "
        toast.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        toast.textColor = .white
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.78)
        toast.layer.cornerRadius = 16
        toast.clipsToBounds = true
        toast.textAlignment = .center
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            toast.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        toast.alpha = 0
        toast.transform = CGAffineTransform(translationX: 0, y: 12)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            toast.alpha = 1
            toast.transform = .identity
        }
        UIView.animate(withDuration: 0.25, delay: 1.8, options: .curveEaseIn) {
            toast.alpha = 0
            toast.transform = CGAffineTransform(translationX: 0, y: 12)
        } completion: { _ in
            toast.removeFromSuperview()
        }
    }
}

// MARK: - EntityNotesViewController

/// Simple sheet view controller with a text view for editing notes.
final class EntityNotesViewController: UIViewController {
    
    var onSave: ((_ notes: String) -> Void)?
    
    private let entityName: String
    private let initialNotes: String
    private let textView = UITextView()
    
    init(entityName: String, notes: String) {
        self.entityName = entityName
        self.initialNotes = notes
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        // ── Header ──────────────────────────────────────────────────────────
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerStack)
        
        let titleLabel = UILabel()
        titleLabel.text = "Notes — \(entityName)"
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = .label
        headerStack.addArrangedSubview(titleLabel)
        
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerStack.addArrangedSubview(spacer)
        
        let saveButton = UIButton(type: .system)
        saveButton.setTitle("Save", for: .normal)
        saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        headerStack.addArrangedSubview(saveButton)
        
        // ── Character count ─────────────────────────────────────────────────
        let charCount = UILabel()
        charCount.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        charCount.textColor = .secondaryLabel
        charCount.textAlignment = .right
        charCount.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(charCount)
        
        // ── Text View ───────────────────────────────────────────────────────
        textView.text = initialNotes
        textView.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        textView.textColor = .label
        textView.backgroundColor = UIColor.secondarySystemBackground
        textView.layer.cornerRadius = 12
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.keyboardDismissMode = .interactiveWithAccessory
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        
        let updateCount = { [weak charCount, weak self] in
            charCount?.text = "\(self?.textView.text.count ?? 0) chars"
        }
        updateCount()
        
        NotificationCenter.default.addObserver(forName: UITextView.textDidChangeNotification, object: textView, queue: .main) { _ in
            updateCount()
        }
        
        // ── Layout ──────────────────────────────────────────────────────────
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            headerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            textView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 16),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -12),
            
            charCount.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            charCount.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 2),
        ])
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.becomeFirstResponder()
    }
    
    @objc private func saveTapped() {
        let notes = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave?(notes)
        dismiss(animated: true)
    }
}
