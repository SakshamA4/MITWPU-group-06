//
//  spawnItem.swift
//  3DCanvas
//
//  Created by SDC-USER on 12/01/26.
//

import UIKit

struct SpawnItem {
    var title: String
    let imageName: String      // for UI
    let modelFileName: String  // for RealityKit
    var isBackground: Bool = false
    var UUId: UUID = UUID()
    
    var poses: [String]? = nil
    var detailText: String? = nil
}

class BackgroundStore {
    static let shared = BackgroundStore()
    

        var images: [UIImage] = []

        var currentSelectedImage: UIImage?
        var onImageSelected: ((UIImage) -> Void)?

        func selectImage(_ image: UIImage) {
            onImageSelected?(image)
        }
}
