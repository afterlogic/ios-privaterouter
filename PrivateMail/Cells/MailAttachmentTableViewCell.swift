//
//  MailAttachmentTableViewCell.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

class MailAttachmentTableViewCell: UITableViewCell {

    @IBOutlet var titleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

    }
    
}


extension MailAttachmentTableViewCell: UITableViewCellExtensionProtocol {
    static func cellID() -> String {
        return "MailAttachmentTableViewCell"
    }
}
