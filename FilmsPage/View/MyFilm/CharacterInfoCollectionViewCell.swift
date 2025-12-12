//
//  CharacterInfoCollectionViewCell.swift
//  FilmsPage
//
//  Created by SDC-USER on 12/12/25.
//

import UIKit

class CharacterInfoCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var imageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    func configureCell(character: Character) {
        
        if !character.image.isEmpty {
            imageView.image = UIImage(named: character.image)
        } else {
            imageView.image = nil // or set a placeholder: UIImage(named: "placeholder")
        }
    }
    
    @IBAction func nameTextChanged(_ sender: UITextField) {
        nameTextField.text = sender.text
    }


}
