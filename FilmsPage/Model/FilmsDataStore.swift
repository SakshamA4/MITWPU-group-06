//
//  dataStore.swift
//  FilmsPage
//
//  Created by SDC-USER on 24/11/25.
//

import Foundation

class DataStore {
//    private var films: [favFilms] = []
    private var favFilms: Film? = nil
    
    private var films: [Film] = []
    
    private var sequence: [Sequence] = []
    private var Props: [Prop] = []
    private var Characters: [Character] = []
    
    private var scenes: [Scene] = []
    
    
    init(films: [Film] = [], favFilms: [Film] = [], Sequence: [Sequence] = [], Props: [Prop] = [], Characters: [Character] = [], scenes: [Scene] = []) {
        self.films = films
        self.sequence = Sequence
        self.Props = Props
        self.Characters = Characters
        self.scenes = scenes
    }
        
    func loadData() {
        
        if let savedData = UserDefaults.standard.data(forKey: "films") {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode([Film].self, from: savedData) {
                self.films = decoded
            }
        }

        if let savedFav = UserDefaults.standard.data(forKey: "favFilm") {
            let decoder = JSONDecoder()
            if let decodedFav = try? decoder.decode(Film.self, from: savedFav) {
                self.favFilms = decodedFav
            }
        }
        
        
        self.films = [
            Film(id: UUID(), name: "Sample Film", sequences: 0, scenes: 0, time: "0", characters: 0, props: 3, image: "Image"),
            Film(id: UUID(), name: "Templates", sequences: 0, scenes: 0, time: "0", characters: 0, image: "Image")
            
        ]
        
        self.favFilms = Film(id: UUID(), name: "My Film 4", sequences: 0, scenes: 0, time: "0", characters: 0, image: "Image")
        
        self.sequence = [
            Sequence(id: UUID(), name: "Sequence 1", image: "Image", filmId: self.films[0].id),
            Sequence(id: UUID(), name: "Introduction", image: "Image", filmId: self.films[1].id),
            Sequence(id: UUID(), name: "Fight", image: "Image", filmId: self.favFilms!.id)
            
        ]
        let sampleData4: [Prop] = [
            Prop(id: UUID() ,name: "Table", image: "Image",filmId: self.films[0].id ),
            Prop(id: UUID() ,name: "Chair", image: "Image",filmId: self.films[0].id),
            Prop(id: UUID() ,name: "Bookshelf", image: "Image",filmId: self.films[0].id)
        ]
        self.Characters = [
            Character(id: UUID() ,name: "Character 1", image: "Image",filmId: self.films[0].id),
            Character(id: UUID() ,name: "Character 2", image: "Image",filmId: self.films[0].id),
            Character(id: UUID(), name: "Character 3", image: "Image"),
            Character(id: UUID(), name: "Character 4", image: "Image"),
            Character(id: UUID(), name: "Character 5", image: "Image"),
            Character(id: UUID(), name: "Character 6", image: "Image")
        ]
        
        self.scenes = [
            Scene(id: UUID(), name: "Scene 1", image: "Image", SequenceId: self.sequence[0].id),
            Scene(id: UUID(), name: "Scene 2", image: "Image", SequenceId: self.sequence[0].id),
            Scene(id: UUID(), name: "Scene 3", image: "Image", SequenceId: self.sequence[0].id),
            Scene(id: UUID(), name: "Scene 4", image: "Image", SequenceId: self.sequence[0].id)
            
        ]

        self.Props = sampleData4
       // self.Characters = sampleData5
    }
    
    func saveData() {
        let encoder = JSONEncoder()

        if let encoded = try? encoder.encode(films) {
            UserDefaults.standard.set(encoded, forKey: "films")
        }

        if let fav = favFilms {
            if let encodedFav = try? encoder.encode(fav) {
                UserDefaults.standard.set(encodedFav, forKey: "favFilm")
            }
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
    
    func getCharactersByFilmId(filmId: UUID) -> [Character] {
        return Characters.filter { $0.filmId == filmId }
    }
    
    func getCharacters() -> [Character] {
        return self.Characters
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
        saveData()
    }

}
