//
//  SettingsTableViewCell.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

enum SettingsTableViewCellStyle {
    case `default`
    case leftText
}

class SettingsTableViewCell: UITableViewCell {
    
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var iconImageView: UIImageView!
    @IBOutlet var leftTextLabel: UILabel!
    
    var style: SettingsTableViewCellStyle = .default {
        didSet {
            iconImageView.isHidden = true
            leftTextLabel.isHidden = true
            
            switch self.style {
            case .`default`:
                iconImageView.isHidden = false
                break
                
            case .leftText:
                leftTextLabel.isHidden = false
                break
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}

extension SettingsTableViewCell: UITableViewCellExtensionProtocol {
    static func cellID() -> String {
        return "SettingsTableViewCell"
    }
}
