//
//  CharacterInfoCollectionViewCell.swift
//  FilmsPage
//
//  Created by SDC-USER on 12/12/25.
//

import UIKit

protocol CharacterNameCellDelegate: AnyObject {
    func nameDidChange(_ name: String)
}

class CharacterInfoCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var imageView: UIImageView!
    
    weak var delegate: CharacterNameCellDelegate?

    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        nameTextField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
    }
    
    @objc func textChanged() {
        delegate?.nameDidChange(nameTextField.text ?? "")
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
