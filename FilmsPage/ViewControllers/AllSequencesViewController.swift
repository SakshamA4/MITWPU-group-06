//
//  AllSequencesViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 08/12/25.
//

import UIKit

class AllSequencesViewController: UIViewController , UICollectionViewDataSource {
    
    var film: [Film] = []
    var sequence: [Sequence] = []
    var selectedSequence: Sequence?
  

    
    @IBOutlet weak var collectionView: UICollectionView!
    
    private let sequenceCellId = "sequence_cell"
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
        collectionView.register(UINib(nibName: "SequencesCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "sequence_cell")
        

        collectionView.dataSource = self
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        collectionView.setCollectionViewLayout(layout, animated: false)
        collectionView.dataSource = self
        collectionView.delegate = self
        // Do any additional setup after loading the view.
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
        })
    }

    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sequence.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "sequence_cell",
            for: indexPath
        ) as! SequencesCollectionViewCell

        cell.configureCell(sequence: sequence[indexPath.row])
        return cell
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension AllSequencesViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let inset: CGFloat = 40
        let interItem: CGFloat = 40
        let columns: CGFloat = 4
        let totalSpacing = inset * 2 + interItem * (columns - 1)
        let width = (collectionView.bounds.width - totalSpacing) / columns
        return CGSize(width: width, height: width)
    }
    


    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 16, left: 52, bottom: 16, right: 52)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let sequence = sequence[indexPath.row]
        selectedSequence = sequence
        performSegue(withIdentifier: "sequence2Segue", sender: self)
    }

    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "sequence2Segue",
           let vc = segue.destination as? SequenceViewController {
            vc.sequence = selectedSequence
        }
    }


}

// Add this extension to AllSequencesViewController.swift

extension AllSequencesViewController {
    
    // MARK: - Context Menu (Long Press)
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            
            let sequence = self.sequence[indexPath.item]
            
            // 1. Rename Action
            let renameAction = UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { [weak self] _ in
                self?.presentRenameAlert(for: sequence)
            }
            
            // 2. Delete Action
            let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.deleteSequence(sequence)
            }
            
            return UIMenu(title: sequence.name, children: [renameAction, deleteAction])
        }
    }
    
    // MARK: - Helper Functions
    
    private func deleteSequence(_ seq: Sequence) {
        // Delete via Service (matches MyFilmViewController logic)
        SequenceService.shared.deleteSequence(by: seq.id)
        
        // Note: Ensure you have added the observer in viewDidLoad to reload data!
        // If not, add this to viewDidLoad:
        // NotificationCenter.default.addObserver(self, selector: #selector(refreshData), name: NSNotification.Name(NotificationNames.sequencesUpdated), object: nil)
    }
    
    private func presentRenameAlert(for seq: Sequence) {
        let alert = UIAlertController(title: "Rename Sequence", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = seq.name
            tf.placeholder = "Sequence Name"
        }
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let newName = alert.textFields?.first?.text, !newName.isEmpty else { return }
            
            var updatedSeq = seq
            updatedSeq.name = newName
            
            // Call update on service
            SequenceService.shared.updateSequence(updatedSeq)
        }
        
        alert.addAction(saveAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}
