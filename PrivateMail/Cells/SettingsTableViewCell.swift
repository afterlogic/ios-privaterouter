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
    case switcher
}

class SettingsTableViewCell: UITableViewCell {
    
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var iconImageView: UIImageView!
    @IBOutlet var leftTextLabel: UILabel!
    @IBOutlet private var valueSwitch: UISwitch!
    
    weak var delegate: SettingsTableViewCellDelegate?
    
    private var isUserMode = true
    
    var isSwitchedOn: Bool {
        set {
            isUserMode = false
            valueSwitch.isOn = newValue
            isUserMode = true
        }
        get {
            valueSwitch.isOn
        }
    }
    
    var style: SettingsTableViewCellStyle = .default {
        didSet {
            updateViewsByStyle()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        updateViewsByStyle()
    }
    
    private func updateViewsByStyle() {
        iconImageView.isHidden = true
        leftTextLabel.isHidden = true
        valueSwitch.isHidden = true
    
        switch self.style {
        case .`default`:
            iconImageView.isHidden = false
            break
    
        case .leftText:
            leftTextLabel.isHidden = false
            break
    
        case .switcher:
            valueSwitch.isHidden = false
            break
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    @IBAction func switchChanged(_ sender: Any) {
        guard isUserMode else { return }
        delegate?.settingsCell(self, switchValueChanged: valueSwitch.isOn)
    }
    
}

protocol SettingsTableViewCellDelegate: NSObjectProtocol {
    
    func settingsCell(_ cell: SettingsTableViewCell, switchValueChanged isOn: Bool)

}

extension SettingsTableViewCell: UITableViewCellExtensionProtocol {
    static func cellID() -> String {
        return "SettingsTableViewCell"
    }
}
