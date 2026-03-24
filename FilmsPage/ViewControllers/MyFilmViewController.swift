//
//  MyFilmViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit

class MyFilmViewController: UIViewController {

    var film: Film?

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var filmName: UILabel!

    private let sequenceCellId = "sequence_cell"
    var sequence: [Sequence] = []

    private let sequenceService = SequenceService.shared

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        refreshData()

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 30
        layout.minimumInteritemSpacing = 8
        collectionView.setCollectionViewLayout(layout, animated: false)

        collectionView.dataSource = self
        collectionView.delegate = self

        registerCells()
        setupObservers()

        filmName.text = film?.name ?? "My Film"
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshData()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        })
    }

    // MARK: - Setup

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshData),
            name: NSNotification.Name(NotificationNames.sequencesUpdated),
            object: nil
        )
    }

    @objc private func refreshData() {
        guard let film = film else { return }
        sequence = sequenceService.getSequences(forFilmId: film.id)
        collectionView?.reloadData()
    }

    func registerCells() {
        collectionView.register(
            UINib(nibName: "SequencesCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "sequence_cell"
        )
        collectionView.register(
            UINib(nibName: "PlaceholderCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "placeholder_cell"
        )
    }
}

// MARK: - UICollectionViewDataSource

extension MyFilmViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sequence.count + 1  // +1 for the placeholder cell at index 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        // Index 0 → placeholder cell
        if indexPath.item == 0 {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "placeholder_cell",
                for: indexPath
            ) as? PlaceholderCollectionViewCell else { return UICollectionViewCell() }

            cell.addNew.text = "New Sequence"
            cell.onPlusButtonTapped = { [weak self] in
                self?.performSegue(withIdentifier: "AddNewSequenceSegue", sender: nil)
            }
            return cell
        }

        // Index 1+ → sequence cells
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: sequenceCellId,
            for: indexPath
        ) as? SequencesCollectionViewCell else { return UICollectionViewCell() }

        cell.configureCell(sequence: sequence[indexPath.item - 1])  // -1 to offset placeholder
        return cell
    }
}

// MARK: - UICollectionViewDelegate & FlowLayout

extension MyFilmViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let inset: CGFloat = 40
        let interItem: CGFloat = 40
        let columns: CGFloat = 4
        let totalSpacing = inset * 2 + interItem * (columns - 1)
        let width = (collectionView.bounds.width - totalSpacing) / columns
        return CGSize(width: width, height: width)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        return UIEdgeInsets(top: 16, left: 52, bottom: 16, right: 52)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item != 0 else { return }  // ignore placeholder tap
        performSegue(withIdentifier: "sequenceSegue", sender: sequence[indexPath.item - 1])
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "sequenceSegue" {
            if let vc = segue.destination as? SequenceViewController {
                vc.sequence = sender as? Sequence
                vc.filmName = self.film?.name
            }
        }
        if segue.identifier == "AddNewSequenceSegue" {
            if let vc = segue.destination as? AddSequenceViewController {
                vc.film = self.film
            }
        }
    }
}

// MARK: - Context Menu (Long Press)

extension MyFilmViewController {

    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard indexPath.item != 0 else { return nil }  // ignore placeholder

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in

            let renameAction = UIAction(title: "Rename Sequence", image: UIImage(systemName: "pencil")) { [weak self] _ in
                self?.presentRenameSequenceAlert(at: indexPath)
            }

            let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.deleteSequence(at: indexPath)
            }

            return UIMenu(title: "", children: [renameAction, deleteAction])
        }
    }

    // MARK: - Helpers

    private func deleteSequence(at indexPath: IndexPath) {
        let seq = sequence[indexPath.item - 1]  // -1 to offset placeholder
        sequenceService.deleteSequence(by: seq.id)
        // Observer on sequencesUpdated will call refreshData() automatically
    }

    private func presentRenameSequenceAlert(at indexPath: IndexPath) {
        let currentSequence = sequence[indexPath.item - 1]

        let alert = UIAlertController(title: "Rename Sequence", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = currentSequence.name
            tf.placeholder = "Sequence Name"
        }

        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self,
                  let newName = alert.textFields?.first?.text,
                  !newName.isEmpty else { return }

            var updatedSequence = currentSequence
            updatedSequence.name = newName
            self.sequenceService.updateSequence(updatedSequence)
        }

        alert.addAction(saveAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}
