//
//  KeyImportTableViewCell.swift
//  PrivateMail
//
//  Created by Артём Абрамов on 27/07/2019.
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

class KeyImportTableViewCell: UITableViewCell {

    @IBOutlet var emailLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var `switch`: UISwitch!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

    }
    
}


extension KeyImportTableViewCell: UITableViewCellExtensionProtocol {
    static func cellID() -> String {
        return "KeyImportTableViewCell"
    }
}
