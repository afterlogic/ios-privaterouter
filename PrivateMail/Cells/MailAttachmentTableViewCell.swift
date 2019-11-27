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

    @IBOutlet var iconImage: UIImageView!
    @IBOutlet var importKeyButton: UIButton!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var importConstraint: NSLayoutConstraint!
    @IBOutlet var downloadButton: UIButton!
    
    var downloadLink: String?
    var delegate: MailAttachmentTableViewCellDelegate?
    
    var isComposer = false {
        didSet {
            let imageName = isComposer ? "cross" : "download"
            downloadButton.setImage(UIImage(named: imageName)?.withRenderingMode(.alwaysTemplate), for: .normal)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        theme_backgroundColor = .surface
        iconImage.theme_tintColor = .onSurfaceMinorText
        titleLabel.theme_textColor = .onSurfaceMajorText
        importKeyButton.theme_tintColor = .onSurfaceMinorText
        downloadButton.theme_tintColor = .onSurfaceMinorText
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

    }
    
    @IBAction func downloadButtonAction(_ sender: Any) {
        if let downloadLink = downloadLink {
            if isComposer {
                ComposeMailModelController.shared.mail.attachmentsToSend?[downloadLink] = nil
                delegate?.reloadData()
            } else if let baseUrl = UrlsManager.shared.baseUrl {
                let url = URL(string: "\(baseUrl)\(downloadLink)")
                delegate?.shouldPreviewAttachment(url: url, fileName: titleLabel.text ?? "file.txt")
            }
        }
    }
    
    @IBAction func importKeyButtonAction(_ sender: Any) {
        if let baseUrl = UrlsManager.shared.baseUrl, let downloadLink = downloadLink {
            let url = URL(string: "\(baseUrl)\(downloadLink)")
            delegate?.shouldOpenImportScreen(url: url, fileName: titleLabel.text ?? "file.txt")
        }
    }
    
}


extension MailAttachmentTableViewCell: UITableViewCellExtensionProtocol {
    static func cellID() -> String {
        return "MailAttachmentTableViewCell"
    }
}
