//
//  CharacterInfoCollectionViewCell.swift
//  FilmsPage
//
//  Created by SDC-USER on 12/12/25.
//

import UIKit

protocol UpdateCharacterInfoDelegate{
    func updateName(text: String)
    func updateHeight(value: Float)
}

class CharacterInfoCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var imageView: UIImageView!
    var updateDelegate: UpdateCharacterInfoDelegate?
    @IBOutlet weak var view: UIView!
    
    @IBOutlet weak var heightTextField: UITextField!
    
    
        override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        imageView.layer.cornerRadius = 16
        imageView.clipsToBounds = true
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        view.layer.borderWidth = 0.7
        view.layer.borderColor = UIColor.gray.cgColor
            

    }
    
    func configureCell(character: CharacterItem, delegate: UpdateCharacterInfoDelegate?) {
        
        if !character.imageName.isEmpty {
            imageView.image = UIImage(named: character.imageName)
        } else {
            imageView.image = nil // or set a placeholder: UIImage(named: "placeholder")
        }
        updateDelegate = delegate
       
    }
    

    @IBAction func heightChanged(_ sender: Any) {
        
        updateDelegate?.updateHeight(value: (sender as AnyObject).value ?? 0)
    }
    
    @IBAction func onNameChanged(_ sender: UITextField) {
        updateDelegate?.updateName(text: sender.text ?? "")
    }
}
