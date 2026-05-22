//
//  PoseTitleCollectionReusableView.swift
//  FilmsPage
//
//  Created by SDC-USER on 17/12/25.
//

import UIKit

class PoseTitleCollectionReusableView: UICollectionReusableView {

    // swiftlint:disable:next identifier_name
    @IBOutlet weak var HeaderLabel: UILabel!

    func configureCell() {
        HeaderLabel.text = "Character Poses"
    }

}
