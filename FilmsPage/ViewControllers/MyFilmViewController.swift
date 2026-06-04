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
    @IBOutlet weak var searchButton: UIBarButtonItem!

    private let sequenceCellId    = "sequence_cell"
    private let placeholderCellId = "placeholder_cell"

    // MARK: - Tutorial Target View

    /// The placeholder (+) cell spotlighted in Step 4 of the onboarding.
    var tutorialTargetView: UIView? {
        collectionView.cellForItem(at: IndexPath(item: 0, section: 0))
    }

    // MARK: - Data & Search State
    var sequence: [Sequence] = []
    private var filteredSequences: [Sequence] = []
    private var currentSearchText: String = ""
    private var savedSearchButton: UIBarButtonItem?

    // Computed property to determine active data source
    private var isSearching: Bool { !currentSearchText.isEmpty }
    private var currentSequences: [Sequence] { isSearching ? filteredSequences : sequence }

    private let sequenceService = SequenceService.shared

    // Search controller
    private let searchController = UISearchController(searchResultsController: nil)

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
        setupSearchController()

        // Save the search button and ensure it's visible initially
        savedSearchButton = searchButton
        navigationItem.rightBarButtonItem = searchButton

        filmName.text = film?.name ?? "My Film"
        setupReportButton()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshData()
        // Always hide search bar and restore both nav buttons when view appears
        navigationItem.searchController = nil
        setupReportButton()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if TutorialManager.shared.currentStep == .createSequence,
           let target = tutorialTargetView {
            TutorialManager.shared.showSpotlightIfNeeded(targeting: target, for: .createSequence)
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }, completion: nil)
    }

    // MARK: - Setup

    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.searchBar.delegate = self
        searchController.delegate = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search Sequences"
        // Don't set navigationItem.searchController initially (search bar hidden)
        definesPresentationContext = true
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshData),
            name: NSNotification.Name(NotificationNames.sequencesUpdated),
            object: nil
        )
        // Tutorial: navigate to the tutorial sequence's SequenceViewController
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTutorialNavigateToSequence(_:)),
            name: NSNotification.Name(NotificationNames.tutorialNavigateToSequence),
            object: nil
        )
        // Tutorial: step changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTutorialStepChanged(_:)),
            name: NSNotification.Name(NotificationNames.tutorialStepChanged),
            object: nil
        )
    }

    @objc private func refreshData() {
        guard let film = film else { return }
        sequence = sequenceService.getSequences(forFilmId: film.id)
        // Clear search state when data refreshes
        currentSearchText = ""
        filteredSequences = []
        searchController.isActive = false
        collectionView?.reloadData()
    }

    @IBAction func searchAction(_ sender: Any) {
        // Show search controller in navigation bar
        navigationItem.searchController = searchController

        // Hide the search button by removing it from nav bar
        navigationItem.rightBarButtonItem = nil

        // Animate the search bar appearance
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }

        // Activate and focus the search bar
        searchController.isActive = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.searchController.searchBar.becomeFirstResponder()
        }
    }

    // MARK: - Report

    private func setupReportButton() {
        let cfg = UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        let reportBtn = UIBarButtonItem(
            image: UIImage(systemName: "doc.text.magnifyingglass", withConfiguration: cfg),
            style: .plain,
            target: self,
            action: #selector(showFilmReport)
        )
        // Keep the existing search button alongside the new report button
        navigationItem.rightBarButtonItems = [searchButton, reportBtn]
        savedSearchButton = navigationItem.rightBarButtonItem
    }

    @objc private func showFilmReport() {
        let reportVC = FilmReportViewController()
        reportVC.film = film
        reportVC.modalPresentationStyle = .pageSheet
        if let sheet = reportVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        present(reportVC, animated: true)
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

    // MARK: - Filter Logic

    private func filterSequences(for query: String) {
        currentSearchText = query.trimmingCharacters(in: .whitespaces)
        if currentSearchText.isEmpty {
            filteredSequences = []
        } else {
            filteredSequences = sequence.filter {
                $0.name.localizedCaseInsensitiveContains(currentSearchText)
            }
        }
        collectionView.reloadData()
    }

    // MARK: - Tutorial Handlers

    @objc private func handleTutorialNavigateToSequence(_ notification: Notification) {
        guard TutorialManager.shared.currentStep == .createSceneInSequence,
              let seqIDStr  = notification.userInfo?["sequenceID"] as? String,
              let seqID     = UUID(uuidString: seqIDStr),
              let targetSeq = sequence.first(where: { $0.id == seqID }) else { return }
        performSegue(withIdentifier: "sequenceSegue", sender: targetSeq)
    }

    @objc private func handleTutorialStepChanged(_ notification: Notification) {
        guard let raw  = notification.userInfo?["step"] as? Int,
              let step = TutorialStep(rawValue: raw),
              step == .createSequence else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, let target = self.tutorialTargetView else { return }
            TutorialManager.shared.showSpotlightIfNeeded(targeting: target, for: .createSequence)
        }
    }
}

// MARK: - UICollectionViewDataSource

extension MyFilmViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // When searching, no placeholder cell
        if isSearching {
            return currentSequences.count
        }
        // When not searching, include placeholder at index 0
        return currentSequences.count + 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        // Placeholder cell only shown when not searching
        if !isSearching && indexPath.item == 0 {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: placeholderCellId,
                for: indexPath
            ) as? PlaceholderCollectionViewCell else { return UICollectionViewCell() }

            cell.addNew.text = "New Sequence"
            cell.onPlusButtonTapped = { [weak self] in
                self?.performSegue(withIdentifier: "AddNewSequenceSegue", sender: nil)
            }
            return cell
        }

        // Sequence cells
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: sequenceCellId,
            for: indexPath
        ) as? SequencesCollectionViewCell else { return UICollectionViewCell() }

        // Adjust index based on whether search is active
        let itemIndex = isSearching ? indexPath.item : indexPath.item - 1
        let sequenceToDisplay = currentSequences[itemIndex]
        cell.configureCell(sequence: sequenceToDisplay)
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
        // When not searching, index 0 is placeholder (ignore it)
        // When searching, no placeholder, so all indices are valid
        guard !(!isSearching && indexPath.item == 0) else { return }

        let itemIndex = isSearching ? indexPath.item : indexPath.item - 1
        let selectedSequence = currentSequences[itemIndex]
        performSegue(withIdentifier: "sequenceSegue", sender: selectedSequence)
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
        // When not searching, index 0 is placeholder (ignore it)
        guard !(!isSearching && indexPath.item == 0) else { return nil }

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
        let itemIndex = isSearching ? indexPath.item : indexPath.item - 1
        let sequenceToDelete = currentSequences[itemIndex]
        sequenceService.deleteSequence(by: sequenceToDelete.id)
        // Observer on sequencesUpdated will call refreshData() automatically
    }

    private func presentRenameSequenceAlert(at indexPath: IndexPath) {
        let itemIndex = isSearching ? indexPath.item : indexPath.item - 1
        let currentSequence = currentSequences[itemIndex]

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

// MARK: - UISearchResultsUpdating

extension MyFilmViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        filterSequences(for: searchText)
    }
}

// MARK: - UISearchBarDelegate

extension MyFilmViewController: UISearchBarDelegate {
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        currentSearchText = ""
        filteredSequences = []
        collectionView.reloadData()

        // Hide the search controller and remove from nav bar
        searchController.isActive = false
        navigationItem.searchController = nil

        // Restore both search + report buttons
        setupReportButton()
    }
}

// MARK: - UISearchControllerDelegate

extension MyFilmViewController: UISearchControllerDelegate {
    func willDismissSearchController(_ searchController: UISearchController) {
        // Clear search state before dismissing
        currentSearchText = ""
        filteredSequences = []
        collectionView.reloadData()
    }

    func didDismissSearchController(_ searchController: UISearchController) {
        // Restore both search + report buttons when search is dismissed
        navigationItem.searchController = nil
        setupReportButton()
    }
}
