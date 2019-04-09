//
//  MailHeaderTableViewCell.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

class MailHeaderTableViewCell: UITableViewCell {

    @IBOutlet var subjectLabel: UILabel!
    @IBOutlet var senderLabel: UILabel!
    @IBOutlet var dateLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

    }
    
}


extension MailHeaderTableViewCell: UITableViewCellExtensionProtocol {
    static func cellID() -> String {
        return "MailHeaderTableViewCell"
    }
}
