//
//  SettingsButtonTableViewCell.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

class SettingsButtonTableViewCell: UITableViewCell {

    @IBOutlet var titleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        titleLabel.layer.cornerRadius = titleLabel.bounds.height / 2.0
        titleLabel.theme_textColor = .onAccent
        titleLabel.theme_backgroundColor = .accent
    }
    
}

extension SettingsButtonTableViewCell: UITableViewCellExtensionProtocol {
    static func cellID() -> String {
        return "SettingsButtonTableViewCell"
    }
}
