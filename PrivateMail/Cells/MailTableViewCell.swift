//
//  MailTableViewCell.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

protocol MailTableViewCellDelegate {
    func updateFlagsInMail(mail: APIMail?)
}

class MailTableViewCell: UITableViewCell, UITableViewCellExtensionProtocol {

    @IBOutlet var senderLabel: UILabel!
    @IBOutlet var subjectLabel: UILabel!
    @IBOutlet var dateLabel: UILabel!
    @IBOutlet var flagButton: UIButton!
    @IBOutlet var attachmentImageView: UIImageView!
    @IBOutlet var titleLeadingConstraint: NSLayoutConstraint!
    
    var delegate: MailTableViewCellDelegate?
    
    var isFlagged: Bool = false {
        didSet {
            flagButton.isHidden = !isFlagged
            flagButton.tintColor = isFlagged ? UIColor(rgb: 0xF5A623) : UIColor(white: 0.85, alpha: 1.0)
        }
    }
    
    var isSeen: Bool = false {
        didSet {
            senderLabel.font = isSeen ? UIFont.systemFont(ofSize: senderLabel.font.pointSize, weight: .medium) : UIFont.systemFont(ofSize: senderLabel.font.pointSize, weight: .bold)
            subjectLabel.font = isSeen ? UIFont.systemFont(ofSize: subjectLabel.font.pointSize, weight: .regular) : UIFont.systemFont(ofSize: subjectLabel.font.pointSize, weight: .bold)
            dateLabel.font = isSeen ? UIFont.systemFont(ofSize: dateLabel.font.pointSize, weight: .regular) : UIFont.systemFont(ofSize: dateLabel.font.pointSize, weight: .bold)
            
            subjectLabel.textColor = isSeen ? .darkGray : .black
        }
    }
    
    var mail: APIMail? {
        didSet {
            if var senders = mail?.senders {
                if let email = API.shared.currentUser.email, let index = senders.index(of: email) {
                    senders[index] = NSLocalizedString("me", comment: "")
                }
                
                senderLabel.text = senders.joined(separator: ",")
            } else {
                senderLabel.text = ""
            }
            
            subjectLabel.text = mail?.subject
            
            if subjectLabel.text?.count == 0 {
               subjectLabel.text = NSLocalizedString("(no subject)", comment: "")
            }
            
            if let date = mail?.date {
                dateLabel.text = date.getDateString()
            } else {
                dateLabel.text = ""
            }
            
            isFlagged = mail?.isFlagged ?? false
            isSeen = mail?.isSeen ?? true
            
            attachmentImageView.isHidden = !(mail?.hasAttachments ?? false)
            
            titleLeadingConstraint.isActive =  !attachmentImageView.isHidden
        }
    }
    
    static func cellID() -> String {
        return "MailTableViewCell"
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        flagButton.isUserInteractionEnabled = false
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    @IBAction func flagButtonAction(_ sender: UIButton) {
        flagButton.isUserInteractionEnabled = false
        isFlagged = !isFlagged
        
        if var mail = mail {
            StorageProvider.shared.containsMail(mail: mail, completionHandler: { (mailDB) in
                if mailDB != nil {
                    mail.isFlagged = self.isFlagged
                    StorageProvider.shared.saveMail(mail: mail)
                    self.delegate?.updateFlagsInMail(mail: mail)
                }
            })
        }
        
        API.shared.setMailFlagged(mail: mail ?? APIMail(), flagged: isFlagged) { (result, error) in
            let success = result ?? false
            DispatchQueue.main.async {
                if !success {
//                    self.isFlagged = !self.isFlagged
                }
                
                self.mail?.isFlagged = self.isFlagged
                
                self.flagButton.isUserInteractionEnabled = true
            }
        }
    }
    
    override func prepareForReuse() {
        mail = nil
    }
    
}
