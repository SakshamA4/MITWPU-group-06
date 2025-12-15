//
//  PropDetailViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 15/12/25.
//

import UIKit

class PropDetailViewController: UIViewController {

    @IBOutlet weak var propTitleLabel: UILabel!
    
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var texture1: UIImageView!
    
    @IBOutlet weak var texture2: UIImageView!
    
    @IBOutlet weak var texture3: UIImageView!
    
    @IBOutlet weak var propName: UILabel!
    
    var prop: Prop?
    var dataStore = DataStore.shared
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateTitle()
        if let prop = prop {
            configure(with: prop)
        }
        // Do any additional setup after loading the view.
    }
    
    private func updateTitle() {
        propTitleLabel.text = prop?.name ?? "Prop"
        propName.text = prop?.name ?? "Prop"
    }

    func configure(with prop: Prop) {
        self.prop = prop
        updateTitle()
        imageView.image = UIImage(named: prop.image)
        texture1.image = UIImage(named: "Glass")
        texture2.image = UIImage(named: "Wooden")
        texture3.image = UIImage(named: "Brick")
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
