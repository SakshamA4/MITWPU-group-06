//
//  dataStore.swift
//  FilmsPage
//
//  Created by SDC-USER on 24/11/25.
//

import Foundation

class DataStore {
    static let shared = DataStore()

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
        
        let fixedPoses = [
            Pose(id: UUID(), name: "Idle", image: "pose_idle"),
            Pose(id: UUID(), name: "Run", image: "pose_run"),
            Pose(id: UUID(), name: "Jump", image: "pose_jump"),
            Pose(id: UUID(), name: "Attack", image: "pose_attack"),
            Pose(id: UUID(), name: "Defend", image: "pose_defend"),
            Pose(id: UUID(), name: "Sit", image: "pose_sit")
        ]
        
        self.Characters = [
            Character(id: UUID() ,name: "Character 1", image: "Image",filmId: self.films[0].id, pose: fixedPoses),
            Character(id: UUID() ,name: "Character 2", image: "Image",filmId: self.films[0].id, pose: fixedPoses),
            Character(id: UUID(), name: "Character 3", image: "Image", pose: fixedPoses),
            Character(id: UUID(), name: "Character 4", image: "Image", pose: fixedPoses),
            Character(id: UUID(), name: "Character 5", image: "Image", pose: fixedPoses),
            Character(id: UUID(), name: "Character 6", image: "Image", pose: fixedPoses)
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
    
    func getPoses(forCharacter characterId: UUID) -> [Pose]? {
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
        saveData()
    }
    
    func createNewProp(newProp: Prop) {
        Props.append(newProp)
        saveData()
    }
    func addCharacter(_ character: Character) {
        Characters.append(character)
        saveData()  // optional, if you want to persist
    }


}

extension DataStore {
    func getFixedPoses() -> [Pose] {
        return [
            Pose(id: UUID(), name: "Idle", image: "Image"),
            Pose(id: UUID(), name: "Run", image: "Image"),
            Pose(id: UUID(), name: "Jump", image: "Image"),
            Pose(id: UUID(), name: "Attack", image: "Image"),
            Pose(id: UUID(), name: "Defend", image: "Image"),
            Pose(id: UUID(), name: "Sit", image: "Image")
        ]
    }
}

