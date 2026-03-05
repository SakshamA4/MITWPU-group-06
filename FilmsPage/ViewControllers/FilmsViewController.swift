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
    private let filmService = FilmService.shared

    // MARK: - Outlets
    @IBOutlet weak var FilmsPageTitleLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        allFilms = filmService.getFilms().reversed()

        registerCells()
        setupObservers()

        collectionView.dataSource = self
        collectionView.delegate   = self
        collectionView.collectionViewLayout = generateLayout()
        collectionView.alwaysBounceVertical = true

        collectionView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshData()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
        })
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

    @objc private func refreshData() {
        allFilms = filmService.getFilms().reversed() // newest first
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
            let sectionInset: CGFloat = 12
            let itemInset:    CGFloat = 10        // applied per-item (left + right)
            let interGroup:   CGFloat = 50        // vertical gap between rows (your original)

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
    }
}

// MARK: - UICollectionView DataSource & Delegate

extension FilmsViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return allFilms.count + 1  // +1 for placeholder at index 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        // Index 0 → placeholder / add-new cell
        if indexPath.item == 0 {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: placeholderCellId,
                for: indexPath
            ) as? PlaceholderCollectionViewCell else { return UICollectionViewCell() }

            cell.onPlusButtonTapped = { [weak self] in
                self?.performSegue(withIdentifier: "addFilmSegue", sender: nil)
            }
            return cell
        }

        // Index 1+ → newest-first film cells
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: filmCellId,
            for: indexPath
        ) as? OtherFilmCollectionViewCell else { return UICollectionViewCell() }

        cell.configureCell(film: allFilms[indexPath.item - 1])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item != 0 else { return }
        performSegue(withIdentifier: "myFilmSegue", sender: allFilms[indexPath.item - 1])
    }
}

// MARK: - Context Menu

extension FilmsViewController {

    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {

        guard indexPath.item != 0 else { return nil }
        let film = allFilms[indexPath.item - 1]

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

