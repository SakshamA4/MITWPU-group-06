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
    
    private var Scenes: [scenes] = []
    private var Props: [props] = []
    private var Characters: [characters] = []
    
    
    init(films: [Film] = [], favFilms: [Film] = [], Scenes: [scenes] = [], Props: [props] = [], Characters: [characters] = []) {
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
        
        let sampleData3: [scenes] = [
            FilmsPage.scenes(name: "Scene 1", image: ["Image"])
        ]
        let sampleData4: [props] = [
            FilmsPage.props(name: "Table", image: ["Image"]),
            FilmsPage.props(name: "Chair", image: ["Image"]),
            FilmsPage.props(name: "Bookshelf", image: ["Image"])
        ]
        let sampleData5: [characters] = [
            FilmsPage.characters(name: "Character 1", image: ["Image"]),
            FilmsPage.characters(name: "Character 2", image: ["Image"])
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
    
    
    func getScenes() -> [scenes] {
        Scenes
    }
    func getProps() -> [props] {
        Props
    }
    func getCharacters() -> [characters] {
        Characters
    }

}
