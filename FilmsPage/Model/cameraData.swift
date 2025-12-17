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
                .init(name: "Default",   imageName: "Image", description: "Standard camera setup for general shooting."),
                .init(name: "DSLR",      imageName: "DSLR",    description: "Digital single-lens reflex camera with interchangeable lenses."),
                .init(name: "Sony",      imageName: "Image",    description: "Sony camera, great for video with strong autofocus."),
                .init(name: "Canon",     imageName: "Image",   description: "Canon camera, popular for both photo and video."),
                .init(name: "iPhone",    imageName: "Image",  description: "Mobile shooting with an iPhone or similar smartphone."),
                .init(name: "GoPro",     imageName: "Image",   description: "Action camera for POV and extreme situations."),
                .init(name: "Drone",     imageName: "Image",   description: "Aerial camera for high and moving shots."),
                .init(name: "Arri",      imageName: "Image",    description: "Professional cinema camera used on film sets.")
            ]
        ),

        // 2. Camera Movements
        .init(
            type: .movements,
            items: [
                .init(name: "Pan",        imageName: "Image",        description: "Camera rotates left or right from a fixed position."),
                .init(name: "Tilt",       imageName: "Image",       description: "Camera tilts up or down from a fixed position."),
                .init(name: "Dolly-in",   imageName: "Image",   description: "Camera physically moves closer to the subject."),
                .init(name: "Dolly-out",  imageName: "Image",  description: "Camera physically moves away from the subject."),
                .init(name: "Crane/Boom", imageName: "Image", description: "Camera moves up, down or across on a crane/boom.")
            ]
        ),

        // 3. Static Shots
        .init(
            type: .staticShots,
            items: [
                .init(name: "Establishing Shot", imageName: "Image", description: "Wide shot that sets up location and context."),
                .init(name: "Wide Shot",         imageName: "Image",         description: "Shows the subject in their full environment."),
                .init(name: "Medium Shot",       imageName: "Image",       description: "Frames the subject from waist up."),
                .init(name: "Close-up",          imageName: "Image",      description: "Tight framing on the subject’s face or detail."),
                .init(name: "Insert/Cutaway",    imageName: "Image",       description: "Cut to a detail that supports the main action.")
            ]
        ),
    ]
}
