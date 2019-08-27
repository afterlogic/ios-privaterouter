//
//  MailAttachmentTableViewCell.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

protocol MailAttachmentTableViewCellDelegate: NSObjectProtocol {
    func shouldOpenImportScreen(url: URL?, fileName: String)
    
    func shouldPreviewAttachment(url: URL?, fileName: String)

    func reloadData()
}

class MailAttachmentTableViewCell: UITableViewCell {

    @IBOutlet var importKeyButton: UIButton!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var importConstraint: NSLayoutConstraint!
    @IBOutlet var downloadButton: UIButton!
    
    var downloadLink: String?
    var delegate: MailAttachmentTableViewCellDelegate?
    
    var isComposer = false {
        didSet {
            if isComposer {
                downloadButton.setImage(UIImage(named: "cross"), for: .normal)
            } else {
                downloadButton.setImage(UIImage(named: "download"), for: .normal)
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

    }
    
    @IBAction func downloadButtonAction(_ sender: Any) {
        if let downloadLink = downloadLink {
            if isComposer {
                ComposeMailModelController.shared.mail.attachmentsToSend?[downloadLink] = nil
                delegate?.reloadData()
            } else {
                let url = URL(string: "\(API.shared.getServerURL())\(downloadLink)")
                delegate?.shouldPreviewAttachment(url: url, fileName: titleLabel.text ?? "file.txt")
            }
        }
    }
    
    @IBAction func importKeyButtonAction(_ sender: Any) {
        if let downloadLink = downloadLink {
            let url = URL(string: "\(API.shared.getServerURL())\(downloadLink)")
            delegate?.shouldOpenImportScreen(url: url, fileName: titleLabel.text ?? "file.txt")
        }
    }
    
}


extension MailAttachmentTableViewCell: UITableViewCellExtensionProtocol {
    static func cellID() -> String {
        return "MailAttachmentTableViewCell"
    }
}
