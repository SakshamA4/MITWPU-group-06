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
        self.films = [
            Film(id: UUID(), name: "Sample Film", sequences: 0, scenes: 0, time: "0", characters: 0, image: "Image"),
            Film(id: UUID(), name: "Templates", sequences: 0, scenes: 0, time: "0", characters: 0, image: "Image")
            
        ]
        
        self.favFilms = Film(id: UUID(), name: "My Film 4", sequences: 0, scenes: 0, time: "0", characters: 0, image: "Image")
        
        self.sequence = [
            Sequence(id: UUID(), name: "Sequence 1", image: "Image", filmId: self.films[0].id),
            Sequence(id: UUID(), name: "Introduction", image: "Image", filmId: self.films[1].id),
            Sequence(id: UUID(), name: "Fight", image: "Image", filmId: self.favFilms!.id)
            
        ]
        let sampleData4: [Prop] = [
            FilmsPage.Prop(id: UUID() ,name: "Table", image: "Image"),
            FilmsPage.Prop(id: UUID() ,name: "Chair", image: "Image"),
            FilmsPage.Prop(id: UUID() ,name: "Bookshelf", image: "Image")
        ]
        let sampleData5: [Character] = [
            FilmsPage.Character(id: UUID() ,name: "Character 1", image: "Image"),
            FilmsPage.Character(id: UUID() ,name: "Character 2", image: "Image")
        ]
        
        self.scenes = [
            Scene(id: self.sequence[0].id, name: "Scene 1", image: "Image", SequenceId: UUID()),
            Scene(id: self.sequence[0].id, name: "Scene 2", image: "Image", SequenceId: UUID()),
            Scene(id: self.sequence[0].id, name: "Scene 3", image: "Image", SequenceId: UUID())
            
        ]

        self.Props = sampleData4
        self.Characters = sampleData5
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
    func getProps() -> [Prop] {
        Props
    }
    func getCharacters() -> [Character] {
        Characters
    }
    
    func createNewFilm(newFilm: Film){
        films.append(newFilm)
    }
    
    func getScenes(sequenceId: UUID) -> [Scene] {
        return scenes.filter{ $0.SequenceId == sequenceId }
    }

}
