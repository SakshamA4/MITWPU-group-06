//
//  PropDetailViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 15/12/25.
//

import UIKit

class PropDetailViewController: UIViewController {

    @IBOutlet weak var propDescriptionLabel: UILabel!
    
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var texture1: UIImageView!
    
    @IBOutlet weak var texture2: UIImageView!
    
    @IBOutlet weak var texture3: UIImageView!
    
    @IBOutlet weak var propName: UILabel!
    
    @IBOutlet weak var mainPropView: UIView!
    
    var prop: PropItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateTitle()
        if let prop = prop {
            configure(with: prop)
        
        }
        mainPropView.layer.cornerRadius = 16
        mainPropView.clipsToBounds = true
        
        imageView.layer.cornerRadius = 16
        imageView.clipsToBounds = true
        
        texture1.layer.cornerRadius = 10
        texture1.clipsToBounds = true
        
        texture2.layer.cornerRadius = 10
        texture2.clipsToBounds = true
        
        texture3.layer.cornerRadius = 10
        texture3.clipsToBounds = true

        
        // Do any additional setup after loading the view.
    }
    
    private func updateTitle() {
        propDescriptionLabel.text = prop?.description ?? "Prop"
        propName.text = prop?.name ?? "Prop"
    }

    func configure(with prop: PropItem) {
        self.prop = prop
        updateTitle()
        imageView.image = UIImage(named: prop.imageName)
        texture1.image = UIImage(named: "Glass")
        texture2.image = UIImage(named: "Wooden")
        texture3.image = UIImage(named: "Brick")
    }

}
