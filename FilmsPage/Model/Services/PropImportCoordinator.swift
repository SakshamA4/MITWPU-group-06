//
//  PropImportCoordinator.swift
//  FilmsPage
//

import UIKit
import UniformTypeIdentifiers

class PropImportCoordinator: NSObject, UIDocumentPickerDelegate {
    private weak var presentingViewController: UIViewController?
    
    func start(presentingViewController: UIViewController) {
        self.presentingViewController = presentingViewController
        
        let supportedTypes: [UTType] = [UTType(filenameExtension: "usdz")].compactMap { $0 }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        presentingViewController.present(picker, animated: true)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        guard url.pathExtension.lowercased() == "usdz" else {
            let alert = UIAlertController(title: "Invalid File", message: "Only .usdz files are supported.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            presentingViewController?.present(alert, animated: true)
            return
        }
        
        do {
            let customPropURL = try PropService.shared.copyToCustomProps(sourceURL: url)
            let defaultName = url.deletingPathExtension().lastPathComponent
            
            let alert = UIAlertController(title: "Name your Prop", message: "Enter a name for the custom prop.", preferredStyle: .alert)
            alert.addTextField { textField in
                textField.text = defaultName
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { _ in
                let name = alert.textFields?.first?.text ?? defaultName
                
                let newProp = PropItem(
                    id: UUID(),
                    name: name,
                    imageName: "cube.box", // Placeholder
                    filmId: nil,
                    description: "Custom user-imported prop",
                    modelFileName: customPropURL.lastPathComponent,
                    localModelURL: customPropURL,
                    isCustom: true
                )
                
                PropService.shared.addProp(newProp)
            }))
            
            presentingViewController?.present(alert, animated: true)
            
        } catch {
            let alert = UIAlertController(title: "Error", message: "Could not import prop: \(error.localizedDescription)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            presentingViewController?.present(alert, animated: true)
        }
    }
}
