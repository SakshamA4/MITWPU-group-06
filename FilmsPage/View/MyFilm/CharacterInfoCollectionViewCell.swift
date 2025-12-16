//
//  CharacterInfoCollectionViewCell.swift
//  FilmsPage
//
//  Created by SDC-USER on 12/12/25.
//

import UIKit

protocol UpdateCharacterInfoDelegate{
    func updateName(text: String)
}

class CharacterInfoCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var imageView: UIImageView!
    var updateDelegate: UpdateCharacterInfoDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    func configureCell(character: CharacterItem, delegate: UpdateCharacterInfoDelegate?) {
        
        if !character.imageName.isEmpty {
            imageView.image = UIImage(named: character.imageName)
        } else {
            imageView.image = nil // or set a placeholder: UIImage(named: "placeholder")
        }
        updateDelegate = delegate
    }

    
    @IBAction func onNameChanged(_ sender: UITextField) {
        updateDelegate?.updateName(text: sender.text ?? "")
    }
}
