//
//  cameraData.swift
//  FilmsPage
//
//  Created by SDC-USER on 10/12/25.
//
enum CameraLibraryDataStore {

    static let sections: [CameraLibrarySection] = [
        // 1. Cameras
        .init(
            type: .cameras,
            items: [
                .init(name: "DSLR",      imageName: "DSLR_img",    description: "Digital single-lens reflex camera with interchangeable lenses.", modelFileName: "cam1")
//                .init(name: "Default",   imageName: "Default", description: "Standard camera setup for general shooting."),
//                .init(name: "Sony",      imageName: "Sony",    description: "Sony camera, great for video with strong autofocus."),
//                .init(name: "Canon",     imageName: "Canon",   description: "Canon camera, popular for both photo and video."),
//                .init(name: "iPhone",    imageName: "iPhone",  description: "Mobile shooting with an iPhone or similar smartphone."),
//                .init(name: "GoPro",     imageName: "GoPro",   description: "Action camera for POV and extreme situations."),
//                .init(name: "Drone",     imageName: "Drone",   description: "Aerial camera for high and moving shots."),
//                .init(name: "Arri",      imageName: "Arri",    description: "Professional cinema camera used on film sets.")
            ]
        ),

        // 2. Camera Movements
        .init(
            type: .movements,
            items: [
                .init(name: "Pan",        imageName: "Pan",        description: "Camera rotates left or right from a fixed position."),
                .init(name: "Tilt",       imageName: "Tilt",       description: "Camera tilts up or down from a fixed position."),
                .init(name: "Dolly-in",   imageName: "Dolly-in",   description: "Camera physically moves closer to the subject."),
                .init(name: "Dolly-out",  imageName: "Dolly-out",  description: "Camera physically moves away from the subject."),
                .init(name: "Crane", imageName: "Crane", description: "Camera moves up, down or across on a crane/boom.")
            ]
        ),

        // 3. Static Shots
        .init(
            type: .staticShots,
            items: [
                .init(name: "Establishing Shot", imageName: "Establishing Shot", description: "Wide shot that sets up location and context."),
                .init(name: "Zoom-in Shot",         imageName: "Zoom-in Shot",         description: "The camera gradually moves closer to the subject to highlight details or increase focus/intensity."),
                .init(name: "Zoom-out Shot",       imageName: "Zoom-out Shot",       description: "The camera pulls away from the subject to reveal more surroundings or reduce focus.")
//                .init(name: "Close-up",          imageName: "Close-up",      description: "Tight framing on the subject’s face or detail."),
//                .init(name: "Insert/Cutaway",    imageName: "insert",       description: "Cut to a detail that supports the main action.")
            ]
        ),
    ]
}
