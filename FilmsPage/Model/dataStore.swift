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
    
    private var Sequence: [Sequence] = []
    private var Props: [Prop] = []
    private var Characters: [Character] = []
    
    
    init(films: [Film] = [], favFilms: [Film] = [], Sequence: [Sequence] = [], Props: [Prop] = [], Characters: [Character] = []) {
        self.films = films
        self.Sequence = Sequence
        self.Props = Props
        self.Characters = Characters
    }
        
    func loadData() {
        let films: [Film] = [
            Film(id:0, name: "My Film", sequences: 0, scenes: 0, time: "0", characters: 0, image: ["Image"]),
            Film(id: 1, name: "My Film 2", sequences: 0, scenes: 0, time: "0", characters: 0, image: ["Image"]),
            Film(id: 3, name: "My Film 3", sequences: 0, scenes: 0, time: "0", characters: 0, image: ["Image"])
        ]
        
        let sampleData3: [Sequence] = [
            FilmsPage.Sequence(name: "Sequence 1", image: ["Image"])
        ]
        let sampleData4: [Prop] = [
            FilmsPage.Prop(name: "Table", image: ["Image"]),
            FilmsPage.Prop(name: "Chair", image: ["Image"]),
            FilmsPage.Prop(name: "Bookshelf", image: ["Image"])
        ]
        let sampleData5: [Character] = [
            FilmsPage.Character(name: "Character 1", image: ["Image"]),
            FilmsPage.Character(name: "Character 2", image: ["Image"])
        ]
            
        self.films = films
        self.favFilms = Film(id:4, name: "My Film 4", sequences: 0, scenes: 0, time: "0", characters: 0, image: ["Image"])
        
        self.Sequence = sampleData3
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
        Sequence
    }
    func getProps() -> [Prop] {
        Props
    }
    func getCharacters() -> [Character] {
        Characters
    }

}
