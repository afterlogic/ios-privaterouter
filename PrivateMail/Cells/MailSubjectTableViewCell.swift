//
//  MailSubjectTableViewCell.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

class MailSubjectTableViewCell: UITableViewCell {

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var textField: UITextField!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        theme_backgroundColor = .surface
        titleLabel.theme_textColor = .onSurfaceMinorText
        textField.theme_textColor = .onSurfaceMajorText
        textField.delegate = self
        titleLabel.text = NSLocalizedString("Subject", comment: "")
        textField.text = ComposeMailModelController.shared.mail.subject
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

    }
    
    @IBAction func textFieldDidChanged(_ sender: Any) {
        ComposeMailModelController.shared.mail.subject = textField.text
    }
    
}


extension MailSubjectTableViewCell: UITableViewCellExtensionProtocol {
    static func cellID() -> String {
        return "MailSubjectTableViewCell"
    }
}


extension MailSubjectTableViewCell: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}
