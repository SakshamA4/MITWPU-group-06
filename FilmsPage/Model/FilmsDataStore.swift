//
//  dataStore.swift
//  FilmsPage
//
//  Created by SDC-USER on 24/11/25.
//

import Foundation

class DataStore {
    static let shared = DataStore()


    private var favFilms: Film? = nil
    
    private var films: [Film] = []
    
    private var sequence: [Sequence] = []
    private var Props: [Prop] = []
    private var Characters: [CharacterItem] = []
    
    private var scenes: [Scene] = []
    private var poses: [CharacterPoseItem] = []
    
    
    private init(films: [Film] = [], favFilms: [Film] = [], Sequence: [Sequence] = [], Props: [Prop] = [], Characters: [CharacterItem] = [], scenes: [Scene] = []) {
        self.films = films
        self.sequence = Sequence
        self.Props = Props
        self.Characters = Characters
        self.scenes = scenes
    }
        
    func loadData() {
        

        let decoder = JSONDecoder()


        if let savedFilms = UserDefaults.standard.data(forKey: "films"),
           let decodedFilms = try? decoder.decode([Film].self, from: savedFilms) {
            self.films = decodedFilms
        }

        if let savedFav = UserDefaults.standard.data(forKey: "favFilm"),
           let decodedFav = try? decoder.decode(Film.self, from: savedFav) {
            self.favFilms = decodedFav
        }

        if favFilms == nil {
            favFilms = Film(
                id: UUID(),
                name: "Favourite Film",
                sequences: 0,
                scenes: 0,
                time: "0",
                characters: 0,
                image: "FilmImage"
            )
        }

        if films.isEmpty {
            films = [
                Film(id: UUID(), name: "Sample Film", sequences: 0, scenes: 0, time: "0", characters: 0, image: "Image"),
                Film(id: UUID(), name: "Templates", sequences: 0, scenes: 0, time: "0", characters: 0, image: "Image")
            ]
        }

        updateFilmCounts()
        
        
        self.films = [
            Film(id: UUID(), name: "Sample Film", sequences: 0, scenes: 0, time: "0", characters: 0, props: 3, image: "Image"),
            Film(id: UUID(), name: "Templates", sequences: 0, scenes: 0, time: "0", characters: 0, image: "Image")
            
        ]
        
        self.favFilms = Film(id: UUID(), name: "Favourite Film", sequences: 0, scenes: 0, time: "0", characters: 0, image: "FilmImage")
        
        self.sequence = [
            Sequence(id: UUID(), name: "Sequence 1", image: "Image", filmId: self.films[0].id),
            Sequence(id: UUID(), name: "Introduction", image: "Image", filmId: self.films[1].id),
            Sequence(id: UUID(), name: "Fight", image: "Image", filmId: self.favFilms!.id)
            
        ]
        let sampleData4: [Prop] = [
            Prop(id: UUID() ,name: "Plant", image: "Plant",filmId: self.films[0].id ),
            Prop(id: UUID() ,name: "Bookshelf", image: "Bookshelf",filmId: self.films[0].id),
            Prop(id: UUID() ,name: "Fridge", image: "Fridge",filmId: self.films[0].id),
            Prop(id: UUID(), name: "Wardrobe", image: "Wardrobe", filmId: nil),
            Prop(id: UUID() ,name: "Handbag", image: "Handbag", filmId: nil),
            Prop(id: UUID() ,name: "Flower Vase", image: "Flower Vase", filmId: nil),
            Prop(id: UUID() ,name: "Bag Pack", image: "Bag Pack", filmId: nil),
            Prop(id: UUID() ,name: "Shoe Rack", image: "Shoe Rack", filmId: nil)
        ]

        
        self.Characters = [

            CharacterItem(
                id: UUID(),
                name: "Character 1",
                imageName: "Woman 1",
                filmId: self.films[0].id,
                pose: [
                    CharacterPoseItem(id: UUID(), name: "Fighting Pose", imageName: "fighting pose"),
                    CharacterPoseItem(id: UUID(), name: "Talking", imageName: "Talking Woman"),
                    CharacterPoseItem(id: UUID(), name: "Sitting", imageName: "Sitting Woman"),
                    CharacterPoseItem(id: UUID(), name: "Sleeping", imageName: "Sleeping"),
                    CharacterPoseItem(id: UUID(), name: "Falling", imageName: "Falling"),
                    CharacterPoseItem(id: UUID(), name: "Buffering", imageName: "Buffering")
                ]
            ),

            CharacterItem(
                id: UUID(),
                name: "Character 2",
                imageName: "Man in a suit",
                filmId: self.films[0].id,
                pose: [
                    CharacterPoseItem(id: UUID(), name: "Arms stretched", imageName: "Arms stretched"),
                    CharacterPoseItem(id: UUID(), name: "Talking", imageName: "Talking Man"),
                    CharacterPoseItem(id: UUID(), name: "Sitting", imageName: "Sitting Man"),
                    CharacterPoseItem(id: UUID(), name: "Laying Down", imageName: "Lying down"),
                    CharacterPoseItem(id: UUID(), name: "Waving", imageName: "Waving Man"),
                    CharacterPoseItem(id: UUID(), name: "Joining Hands", imageName: "Joining hands")
                ]
            ),

            CharacterItem(
                id: UUID(),
                name: "Character 3",
                imageName: "Woman 2",
                filmId: self.films[0].id,
                pose: [
                    CharacterPoseItem(id: UUID(), name: "Arms stretched", imageName: "Arms stretched"),
                    CharacterPoseItem(id: UUID(), name: "Talking", imageName: "Talking Woman"),
                    CharacterPoseItem(id: UUID(), name: "Sitting", imageName: "Sitting Woman"),
                    CharacterPoseItem(id: UUID(), name: "Laying Down", imageName: "Lying down"),
                    CharacterPoseItem(id: UUID(), name: "Waving", imageName: "Waving Woman"),
                    CharacterPoseItem(id: UUID(), name: "Joining Hands", imageName: "Joining hands")
                ]
            ),

            CharacterItem(
                id: UUID(),
                name: "Character 4",
                imageName: "Woman 3",
                filmId: self.films[0].id,
                pose: [
                    CharacterPoseItem(id: UUID(), name: "Fighting Pose", imageName: "fighting pose"),
                    CharacterPoseItem(id: UUID(), name: "Talking", imageName: "Talking Woman"),
                    CharacterPoseItem(id: UUID(), name: "Sitting", imageName: "Sitting Woman"),
                    CharacterPoseItem(id: UUID(), name: "Sleeping", imageName: "Sleeping"),
                    CharacterPoseItem(id: UUID(), name: "Falling", imageName: "Falling"),
                    CharacterPoseItem(id: UUID(), name: "Buffering", imageName: "Buffering")
                ]
            ),

            CharacterItem(
                id: UUID(),
                name: "Character 5",
                imageName: "Asian man",
                filmId: self.films[0].id,
                pose: [
                    CharacterPoseItem(id: UUID(), name: "Arms stretched", imageName: "Arms stretched"),
                    CharacterPoseItem(id: UUID(), name: "Talking", imageName: "Talking Man"),
                    CharacterPoseItem(id: UUID(), name: "Sitting", imageName: "Sitting Man"),
                    CharacterPoseItem(id: UUID(), name: "Laying Down", imageName: "Lying down"),
                    CharacterPoseItem(id: UUID(), name: "Waving", imageName: "Waving Man"),
                    CharacterPoseItem(id: UUID(), name: "Joining Hands", imageName: "Joining hands")
                ]
            ),

            CharacterItem(
                id: UUID(),
                name: "Character 6",
                imageName: "Man in a jersey",
                filmId: self.films[0].id,
                pose: [
                    CharacterPoseItem(id: UUID(), name: "Arms stretched", imageName: "Arms stretched"),
                    CharacterPoseItem(id: UUID(), name: "Talking", imageName: "Talking Man"),
                    CharacterPoseItem(id: UUID(), name: "Sitting", imageName: "Sitting Man"),
                    CharacterPoseItem(id: UUID(), name: "Laying Down", imageName: "Lying down"),
                    CharacterPoseItem(id: UUID(), name: "Waving", imageName: "Waving Man"),
                    CharacterPoseItem(id: UUID(), name: "Joining Hands", imageName: "Joining hands")
                ]
            )

        ]

        

        if let savedScenes = UserDefaults.standard.data(forKey: "scenes") {
            let decoder = JSONDecoder()
            if let decodedScenes = try? decoder.decode([Scene].self, from: savedScenes) {
                self.scenes = decodedScenes
            }
        }

        self.Props = sampleData4
        updateFilmCounts()

    }
    
    func saveData() {
        let encoder = JSONEncoder()

        if let encodedFilms = try? encoder.encode(films) {
            UserDefaults.standard.set(encodedFilms, forKey: "films")
        }

        if let fav = favFilms,
           let encodedFav = try? encoder.encode(fav) {
            UserDefaults.standard.set(encodedFav, forKey: "favFilm")
        }

        if let encodedScenes = try? encoder.encode(scenes) {
            UserDefaults.standard.set(encodedScenes, forKey: "scenes")
        }
    }

    



    
    func getOtherFilms() -> [Film] {
        return self.films
    }

    
    func getFavFilms() -> Film? {
        return favFilms
    }
    
    
    func getSequence() -> [Sequence] {
        sequence
    }
    
    func getSequenceByFilmID(filmId: UUID) -> [Sequence] {

        return sequence.filter { $0.filmId == filmId }
    }
    
    func getPropsbyFilmId(filmId: UUID) -> [Prop] {
        return Props.filter { $0.filmId == filmId }
    }
    
    func getProps() -> [Prop] {
        return Props
    }
    
    
    func getCharactersByFilmId(filmId: UUID) -> [CharacterItem] {
        return Characters.filter { $0.filmId == filmId }
    }
    
    func getCharacters() -> [CharacterItem] {
        return self.Characters
    }
    
    func getPoses(forCharacter characterId: UUID) -> [CharacterPoseItem]? {
        return Characters.first(where: { $0.id == characterId })?.pose
    }

    
    func getScenes(sequenceId: UUID) -> [Scene] {
        return scenes.filter{ $0.SequenceId == sequenceId }
    }

    func createNewFilm(newFilm: Film) {
        films.append(newFilm)
        saveData()
    }
    
    func createNewSequence(newSequence: Sequence) {
        sequence.append(newSequence)
        updateFilmCounts()
        saveData()
    }
    
    func createNewScene(newScene: Scene) {
        scenes.append(newScene)
        updateFilmCounts()
        saveData()
    }
    func attachPropToFilm(propId: UUID, filmId: UUID) {

        guard let index = Props.firstIndex(where: { $0.id == propId }) else {
            return
        }
        if Props[index].filmId == filmId {
            return
        }

        Props[index].filmId = filmId
        saveData()
    }
    
    private func saveFavouriteFilm(_ film: Film) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(film) {
            UserDefaults.standard.set(encoded, forKey: "favFilm")
        }
    }



    func addCharacter(newCharacter: CharacterItem) {
        Characters.append(newCharacter)
        updateFilmCounts()
        saveData()
    }
    

    
    func updateFilmCounts() {

        for i in 0..<films.count {
            let filmId = films[i].id

            let seqCount = sequence.filter { $0.filmId == filmId }.count
            let charCount = Characters.filter { $0.filmId == filmId }.count

            let seqIds = sequence
                .filter { $0.filmId == filmId }
                .map { $0.id }

            let sceneCount = scenes.filter { seqIds.contains($0.SequenceId) }.count

            films[i].sequences = seqCount
            films[i].characters = charCount
            films[i].scenes = sceneCount
        }

        if var fav = favFilms {
            let filmId = fav.id

            let seqCount = sequence.filter { $0.filmId == filmId }.count
            let charCount = Characters.filter { $0.filmId == filmId }.count

            let seqIds = sequence
                .filter { $0.filmId == filmId }
                .map { $0.id }

            let sceneCount = scenes.filter { seqIds.contains($0.SequenceId) }.count

            fav.sequences = seqCount
            fav.characters = charCount
            fav.scenes = sceneCount

            favFilms = fav
        }
    }
    



}



