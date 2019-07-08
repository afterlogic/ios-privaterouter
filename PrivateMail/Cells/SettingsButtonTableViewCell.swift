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
        titleLabel.backgroundColor = ColorScheme.accentColor
    }
    
}

extension SettingsButtonTableViewCell: UITableViewCellExtensionProtocol {
    static func cellID() -> String {
        return "SettingsButtonTableViewCell"
    }
}
