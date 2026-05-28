//
//  FilmsViewController.swift
//  FilmsPage
//

import UIKit

class FilmsViewController: UIViewController {

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Cell Identifiers
    private let placeholderCellId = "placeholder_cell"
    private let filmCellId        = "otherFilm_cell"

    // MARK: - State
    var allFilms: [Film] = []
    private var filteredFilms: [Film] = []
    private var currentSearchText: String = ""
    private var savedSearchButton: UIBarButtonItem?
    private let filmService = FilmService.shared

    // Computed properties for search
    private var isSearching: Bool { !currentSearchText.isEmpty }
    private var currentFilms: [Film] { isSearching ? filteredFilms : allFilms }

    // Search controller
    private let searchController = UISearchController(searchResultsController: nil)

    // MARK: - Outlets
    // swiftlint:disable:next identifier_name
    @IBOutlet weak var FilmsPageTitleLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var searchButton: UIBarButtonItem!

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

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        allFilms = filmService.getFilms().reversed()

        registerCells()
        setupObservers()
        setupSearchController()

        // Save the search button and ensure it's visible initially
        savedSearchButton = searchButton
        navigationItem.rightBarButtonItem = searchButton

        collectionView.dataSource = self
        collectionView.delegate   = self
        collectionView.collectionViewLayout = generateLayout()
        collectionView.alwaysBounceVertical = true

        collectionView.reloadData()

        // Tag the Films tab item so the onboarding spotlight can find it (Step 2)
        tabBarItem.accessibilityIdentifier = "onb_filmsTabItem"
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshData()

        // Always hide search bar and show search button when view appears
        navigationItem.searchController = nil
        navigationItem.rightBarButtonItem = savedSearchButton ?? searchButton
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Notify the onboarding manager that the Films screen is visible.
        NotificationCenter.default.post(
            name: .onboardingVCAppeared,
            object: self,
            userInfo: ["vcType": "films"]
        )
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }, completion: nil)
    }

    // MARK: - Setup

    private func registerCells() {
        collectionView.register(
            UINib(nibName: "PlaceholderCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: placeholderCellId
        )
        collectionView.register(
            UINib(nibName: "OtherFilmCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: filmCellId
        )
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshData),
            name: NSNotification.Name(NotificationNames.filmsUpdated),
            object: nil
        )
    }

    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.searchBar.delegate = self
        searchController.delegate = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search Films"
        // Don't set navigationItem.searchController initially (search bar hidden)
        definesPresentationContext = true
    }

    @objc private func refreshData() {
        allFilms = filmService.getFilms().reversed() // newest first
        // Clear search state when data refreshes
        currentSearchText = ""
        filteredFilms = []
        searchController.isActive = false
        collectionView.reloadData()
    }

    // MARK: - Filter Logic

    private func filterFilms(for query: String) {
        currentSearchText = query.trimmingCharacters(in: .whitespaces)
        if currentSearchText.isEmpty {
            filteredFilms = []
        } else {
            filteredFilms = allFilms.filter {
                $0.name.localizedCaseInsensitiveContains(currentSearchText)
            }
        }
        collectionView.reloadData()
    }

    // MARK: - Layout
    // 4-column vertical grid. Item width is calculated from available width so
    // cells are perfectly sized with consistent spacing on any iPad screen size.

    private func generateLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { _, environment in
            let totalWidth  = environment.container.effectiveContentSize.width
            let totalHeight = environment.container.effectiveContentSize.height
            let isLandscape = totalWidth > totalHeight

            // 4 columns landscape, 3 columns portrait
            let columns: CGFloat = isLandscape ? 4 : 3

            // Outer side inset (matches your original 12pt leading/trailing section inset)
            // plus 10pt item content inset on each side = visually ~22pt from screen edge

            let labelLeading: CGFloat = self.FilmsPageTitleLabel.convert(CGPoint.zero, to: self.view).x
            let sectionInset: CGFloat = max(labelLeading, 10)
            // let sectionInset: CGFloat = 12
            let itemInset: CGFloat = 10        // applied per-item (left + right)
            let interGroup: CGFloat = 50        // vertical gap between rows (your original)

            // Available width after section insets, then divide by columns
            let availableWidth = totalWidth - (sectionInset * 2)
            let itemWidth      = availableWidth / columns

            // Fixed height matching your original xib design (280pt)
            let itemHeight: CGFloat = 280

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0 / columns),
                heightDimension: .absolute(itemHeight)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            // Per-item insets give the horizontal breathing room between cards
            item.contentInsets = NSDirectionalEdgeInsets(
                top: 0, leading: itemInset, bottom: 0, trailing: itemInset
            )

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(itemHeight)
            )
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                repeatingSubitem: item,
                count: Int(columns)
            )

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = interGroup
            section.contentInsets = NSDirectionalEdgeInsets(
                top: 16, leading: sectionInset, bottom: 16, trailing: sectionInset
            )
            return section
        }
    }

    // MARK: - Film Actions

    private func showFilmInfo(_ film: Film) {
        let alert = UIAlertController(
            title: film.name,
            message: film.notes.isEmpty ? "No notes." : film.notes,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func editFilm(_ film: Film) {
        let alert = UIAlertController(
            title: "Rename Film",
            message: "Enter a new name for this film",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.text = film.name
            textField.placeholder = "Film Name"
            textField.autocapitalizationType = .words
        }
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self,
                  let newName = alert.textFields?.first?.text,
                  !newName.isEmpty else { return }
            var updatedFilm = film
            updatedFilm.name = newName
            self.filmService.updateFilm(updatedFilm)
        }
        alert.addAction(saveAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func presentDeleteAlert(for film: Film) {
        let alert = UIAlertController(
            title: "Delete Film",
            message: "Are you sure you want to delete '\(film.name)'?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.filmService.deleteFilm(film)
        })
        present(alert, animated: true)
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "myFilmSegue",
           let film = sender as? Film,
           let vc = segue.destination as? MyFilmViewController {
            vc.film = film
        }
        if segue.identifier == "displayNotesSegue",
           let film = sender as? Film,
           let vc = segue.destination as? FilmNotesViewController {
            vc.film = film
        }
    }
}

// MARK: - UICollectionView DataSource & Delegate

extension FilmsViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // When searching, no placeholder cell
        if isSearching {
            return currentFilms.count
        }
        // When not searching, include placeholder at index 0
        return currentFilms.count + 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        // Index 0 → placeholder / add-new cell (only when not searching)
        if !isSearching && indexPath.item == 0 {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: placeholderCellId,
                for: indexPath
            ) as? PlaceholderCollectionViewCell else { return UICollectionViewCell() }

            cell.onPlusButtonTapped = { [weak self] in
                self?.performSegue(withIdentifier: "addFilmSegue", sender: nil)
            }
            // Tag for onboarding spotlight (Step 3 — Add Film button)
            cell.accessibilityIdentifier = "onb_addFilmButton"
            return cell
        }

        // Index 1+ → newest-first film cells (or index 0+ when searching)
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: filmCellId,
            for: indexPath
        ) as? OtherFilmCollectionViewCell else { return UICollectionViewCell() }

        // Adjust index based on whether search is active
        let itemIndex = isSearching ? indexPath.item : indexPath.item - 1
        let film = currentFilms[itemIndex]

        cell.configureCell(film: film)
        cell.onSeeNotesTapped = { [weak self] in
            self?.performSegue(withIdentifier: "displayNotesSegue", sender: film)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // When not searching, index 0 is placeholder (ignore it)
        guard !(!isSearching && indexPath.item == 0) else { return }

        // Adjust index based on whether search is active
        let itemIndex = isSearching ? indexPath.item : indexPath.item - 1
        performSegue(withIdentifier: "myFilmSegue", sender: currentFilms[itemIndex])
    }
}

// MARK: - Context Menu

extension FilmsViewController {

    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {

        // When not searching, index 0 is placeholder (ignore it)
        guard !(!isSearching && indexPath.item == 0) else { return nil }

        // Adjust index based on whether search is active
        let itemIndex = isSearching ? indexPath.item : indexPath.item - 1
        let film = currentFilms[itemIndex]

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let editAction = UIAction(title: "Edit", image: UIImage(systemName: "pencil")) { [weak self] _ in
                self?.editFilm(film)
            }
            let infoAction = UIAction(title: "Get Info", image: UIImage(systemName: "info.circle")) { [weak self] _ in
                self?.showFilmInfo(film)
            }
            let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.presentDeleteAlert(for: film)
            }
            return UIMenu(title: film.name, children: [editAction, infoAction, deleteAction])
        }
    }
}

// MARK: - UISearchResultsUpdating

extension FilmsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        filterFilms(for: searchText)
    }
}

// MARK: - UISearchBarDelegate

extension FilmsViewController: UISearchBarDelegate {
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        currentSearchText = ""
        filteredFilms = []
        collectionView.reloadData()

        // Hide the search controller and remove from nav bar
        searchController.isActive = false
        navigationItem.searchController = nil

        // Restore the search button to nav bar
        navigationItem.rightBarButtonItem = savedSearchButton ?? searchButton
    }
}

// MARK: - UISearchControllerDelegate

extension FilmsViewController: UISearchControllerDelegate {
    func willDismissSearchController(_ searchController: UISearchController) {
        // Clear search state before dismissing
        currentSearchText = ""
        filteredFilms = []
        collectionView.reloadData()
    }

    func didDismissSearchController(_ searchController: UISearchController) {
        // Restore the search button when search controller is dismissed
        navigationItem.searchController = nil
        navigationItem.rightBarButtonItem = savedSearchButton ?? searchButton
    }
}
