//
//  CameraPreviewCell.swift
//  3DCanvas
//
//  Created by SDC-USER on 14/01/26.
//

import UIKit
import RealityKit

class CameraPreviewCell: UICollectionViewCell {

    static let reuseID = "CameraPreviewCell"

    let previewView = ARView(frame: .zero)
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        previewView.environment.background = .color(.black)
        previewView.isUserInteractionEnabled = false

        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textAlignment = .center
        label.textColor = .white

        contentView.addSubview(previewView)
        contentView.addSubview(label)

        previewView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: contentView.topAnchor),
            previewView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            previewView.heightAnchor.constraint(equalToConstant: 90),

            label.topAnchor.constraint(equalTo: previewView.bottomAnchor, constant: 4),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        contentView.backgroundColor = .darkGray
        contentView.layer.cornerRadius = 10
        contentView.clipsToBounds = true
    }
    
    func configure(
        sourceAnchor: AnchorEntity,
        sourceCamera: PerspectiveCamera,
        name: String
    ) {
        label.text = name

        previewView.scene.anchors.removeAll()

        // Clone the entire scene
        let previewAnchor = sourceAnchor.clone(recursive: true)
        previewView.scene.addAnchor(previewAnchor)

        // Disable ALL cameras in preview scene
        previewAnchor.forEachDescendant { entity in
            if let cam = entity as? PerspectiveCamera {
                cam.isEnabled = false
            }
        }

        // Enable ONLY the matching camera
        if let previewCamera = previewAnchor.findEntity(
            named: sourceCamera.name
        ) as? PerspectiveCamera {
            previewCamera.isEnabled = true
        }

        previewView.cameraMode = .nonAR
    }



    required init?(coder: NSCoder) { fatalError() }
}

extension Entity {
    func forEachDescendant(_ body: (Entity) -> Void) {
        body(self)
        for child in children {
            child.forEachDescendant(body)
        }
    }
}
