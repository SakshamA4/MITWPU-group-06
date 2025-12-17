//
//  FilmsViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 24/11/25.
//

import UIKit

class FilmsViewController: UIViewController {

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private let favCellId = "film_cell"
    private let otherCellId = "otherFilm_cell"

    @IBOutlet weak var FilmsPageTitleLabel: UILabel!
    var favouriteFilm: Film!
    var allFilms: [Film] = []
    
    // Services
    private let filmService = FilmService.shared


    @IBOutlet weak var collectionView: UICollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()

        favouriteFilm = filmService.getFavFilm()!
        allFilms = filmService.getFilms()

        registerCells()
        setupObservers()

        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.collectionViewLayout = generateLayout()

        collectionView.reloadData()
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
        favouriteFilm = filmService.getFavFilm()
        allFilms = filmService.getFilms()
        collectionView.reloadData()
    }

    func registerCells() {

        collectionView.register(
            UINib(nibName: "FavFilmCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "film_cell"
        )

        collectionView.register(
            UINib(nibName: "OtherFilmCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "otherFilm_cell"
        )

    

    }

    func generateLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout {
            section,
            env in

            if section == 0 {
                //set item size
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .fractionalHeight(1.0)
                )
                //create item
                let item = NSCollectionLayoutItem(layoutSize: itemSize)

                //create the group
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(0.90),
                    heightDimension: .estimated(235)
                )
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: groupSize,
                    subitems: [item]
                )

                group.interItemSpacing = .fixed(10)
                //create the section
                let section = NSCollectionLayoutSection(group: group)
                //scrolling
                section.orthogonalScrollingBehavior = .groupPagingCentered

                item.contentInsets = NSDirectionalEdgeInsets(
                    top: 0,
                    leading: 8,
                    bottom: 0,
                    trailing: 8
                )
                //spacing between next block
                //section.interGroupSpacing = 10
                section.contentInsets = NSDirectionalEdgeInsets(
                    top: 16,
                    leading: 12,
                    bottom: 48,
                    trailing: 12
                )
                // section.boundarySupplementaryItems = [headerItem]

                return section
            } else {
                //set item size
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(0.25),
                    heightDimension: .absolute(280)
                )
                //create item
                let item = NSCollectionLayoutItem(layoutSize: itemSize)

                item.contentInsets = NSDirectionalEdgeInsets(
                    top: 0,
                    leading: 10,
                    bottom: 0,
                    trailing: 10
                )

                //create the group
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(0.9),
                    heightDimension: .estimated(280)
                )

                //                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: groupSize,
                    repeatingSubitem: item,
                    count: 5
                    
                    
                )

                //create the section
                let section = NSCollectionLayoutSection(group: group)
                section.orthogonalScrollingBehavior = .groupPagingCentered

                group.interItemSpacing = .fixed(20)
                //spacing between next block
                section.interGroupSpacing = 50
                section.contentInsets = NSDirectionalEdgeInsets(
                    top: 16,
                    leading: 12,
                    bottom: 16,
                    trailing: 12
                )

                //add header

                return section
            }

        }
        return layout
    }

}

extension FilmsViewController: UICollectionViewDataSource,
    UICollectionViewDelegate, OtherFilmDelegate
{
    func setFavFilm(film: Film) {
        self.allFilms.append(self.favouriteFilm)
        self.favouriteFilm = film
        self.allFilms.removeAll { $0.id == film.id }

        collectionView.reloadData()
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        2
    }

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        if section == 0 {
            return 1
        } else {
            return allFilms.count
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {

        if indexPath.section == 0 {
            guard
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: favCellId,
                    for: indexPath
                ) as? FavFilmCollectionViewCell
            else {
                return UICollectionViewCell()
            }
            let film = favouriteFilm
            cell.configureCell(film: film!)
            return cell
        } else {
            guard
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: otherCellId,
                    for: indexPath
                ) as? OtherFilmCollectionViewCell
            else {
                return UICollectionViewCell()
            }
            let film = allFilms[indexPath.item]
            cell.configureCell(film: film)
            cell.delegate = self
            return cell
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        var selectedFilm: Film?
        if indexPath.section == 0 {
            selectedFilm = favouriteFilm
        } else {
            selectedFilm = allFilms[indexPath.item]
        }
        performSegue(withIdentifier: "myFilmSegue", sender: selectedFilm)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if(segue.identifier == "myFilmSegue"){
            let film = sender as! Film
            let vc = segue.destination as! MyFilmViewController
            vc.film = film
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshData()
    }


}

