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
    
    private var Scenes: [Scenes] = []
    private var Props: [Props] = []
    private var Characters: [Characters] = []
    
    
    init(films: [Film] = [], favFilms: [Film] = [], Scenes: [Scenes] = [], Props: [Props] = [], Characters: [Characters] = []) {
        self.films = films
        self.Scenes = Scenes
        self.Props = Props
        self.Characters = Characters
    }
        
    func loadData() {
        let films: [Film] = [
            Film(id:0, name: "My Film", sequences: 0, scenes: 0, time: "0", characters: 0, image: ["Image"]),
            Film(id: 1, name: "My Film 2", sequences: 0, scenes: 0, time: "0", characters: 0, image: ["Image"]),
            Film(id: 3, name: "My Film 3", sequences: 0, scenes: 0, time: "0", characters: 0, image: ["Image"])
        ]
        
        let sampleData3: [Scenes] = [
            FilmsPage.Scenes(name: "Scene 1", image: ["Image"])
        ]
        let sampleData4: [Props] = [
            FilmsPage.Props(name: "Table", image: ["Image"]),
            FilmsPage.Props(name: "Chair", image: ["Image"]),
            FilmsPage.Props(name: "Bookshelf", image: ["Image"])
        ]
        let sampleData5: [Characters] = [
            FilmsPage.Characters(name: "Character 1", image: ["Image"]),
            FilmsPage.Characters(name: "Character 2", image: ["Image"])
        ]
            
        self.films = films
        self.favFilms = Film(id:4, name: "My Film 4", sequences: 0, scenes: 0, time: "0", characters: 0, image: ["Image"])
        
        self.Scenes = sampleData3
        self.Props = sampleData4
        self.Characters = sampleData5
    }
    
    func getOtherFilms() -> [Film] {
        return self.films
    }
    
    func getFavFilms() -> Film? {
        return favFilms
    }
    
    
    func getScenes() -> [Scenes] {
        Scenes
    }
    func getProps() -> [Props] {
        Props
    }
    func getCharacters() -> [Characters] {
        Characters
    }

}
