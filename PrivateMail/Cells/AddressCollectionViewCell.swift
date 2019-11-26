//
//  AddressCollectionViewCell.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import SwiftTheme

protocol AddressCollectionViewCellProtocol: NSObjectProtocol {
    func deleteAddress(email: String)
}

class AddressCollectionViewCell: UICollectionViewCell {
    @IBOutlet var backView: UIView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var deleteButton: UIButton!
    
    weak open var delegate: AddressCollectionViewCellProtocol?
    
    static let cellHeight = 30.0
    
    var email: String = ""
    
    static func cellID() -> String {
        return "AddressCollectionViewCell"
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        backView.theme_backgroundColor = .secondarySurface
        titleLabel.theme_textColor = .onSurfaceMinorText
    }

    @IBAction func deleteButtonAction(_ sender: Any) {
        delegate?.deleteAddress(email: email)
    }
}
