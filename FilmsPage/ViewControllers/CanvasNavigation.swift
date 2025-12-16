//
//  CanvasNavigation.swift
//  FilmsPage
//
//  Created by SDC-USER on 16/12/25.
//

import UIKit

class CanvasNavigation: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let canvasVC = MyFeatureCanvasVC()
        self.setViewControllers([canvasVC], animated: false)
        // Do any additional setup after loading the view.
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
