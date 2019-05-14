//
//  MailAttachmentTableViewCell.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

protocol MailAttachmentTableViewCellDelegate: NSObjectProtocol {
    func shouldPreviewAttachment(url: URL?, fileName: String)
}

class MailAttachmentTableViewCell: UITableViewCell {

    @IBOutlet var titleLabel: UILabel!
    var downloadLink: String?
    var delegate: MailAttachmentTableViewCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

    }
    
    @IBAction func downloadButtonAction(_ sender: Any) {
        if let downloadLink = downloadLink {
            let url = URL(string: "\(API.shared.getServerURL())\(downloadLink)")
            delegate?.shouldPreviewAttachment(url: url, fileName: titleLabel.text ?? "file.txt")
        }
    }
    
    
}


extension MailAttachmentTableViewCell: UITableViewCellExtensionProtocol {
    static func cellID() -> String {
        return "MailAttachmentTableViewCell"
    }
}
