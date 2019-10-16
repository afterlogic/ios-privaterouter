//
//  AddressFieldCollectionViewCell.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

protocol AddressFieldCollectionViewCellProtocol: NSObjectProtocol {
    func addressTextFieldBeginEditing()
    
    func addAddress(email: String?)
}

class AddressFieldCollectionViewCell: UICollectionViewCell {

    @IBOutlet var textField: UITextField!
    
    weak open var delegate: AddressFieldCollectionViewCellProtocol?
    
    static func cellID() -> String {
        return "AddressFieldCollectionViewCell"
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        textField.delegate = self
    }
}


extension AddressFieldCollectionViewCell: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        delegate?.addressTextFieldBeginEditing()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        delegate?.addAddress(email: textField.text)
        textField.text = nil

        return false
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.text != nil {
            delegate?.addAddress(email: textField.text)
            textField.text = nil
        }
    }
}
