//
//  ContactTableViewCell.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

class ContactTableViewCell: UITableViewCell {
    
    @IBOutlet var fullNameLabel: UILabel!
    @IBOutlet var emailLabel: UILabel!
    @IBOutlet var `switch`: UISwitch!
    
    var contact: APIContact? {
        didSet {
            fullNameLabel.text = contact?.fullName
            emailLabel.text = contact?.viewEmail
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
    }
    
}


extension ContactTableViewCell: UITableViewCellExtensionProtocol {
    static func cellID() -> String {
        return "ContactTableViewCell"
    }
}
