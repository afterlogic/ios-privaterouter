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

    func unfoldThreadWith(id: Int)
    
}

class MailTableViewCell: UITableViewCell, UITableViewCellExtensionProtocol {

    @IBOutlet var senderLabel: UILabel!
    @IBOutlet var subjectLabel: UILabel!
    @IBOutlet var dateLabel: UILabel!
    @IBOutlet var flagButton: UIButton!
    @IBOutlet var attachmentImageView: UIImageView!
    @IBOutlet var titleTrailingConstraint: NSLayoutConstraint!
    
    @IBOutlet var threadConstraint: NSLayoutConstraint!
    @IBOutlet var threadBackground: UIView!
    @IBOutlet var unfoldButton: UIButton!
    @IBOutlet var unfoldLayoutConstraint: NSLayoutConstraint!

    @IBOutlet var answeredImageView: UIImageView!
    @IBOutlet var forwardedImageView: UIImageView!
    @IBOutlet var flagConstraint: NSLayoutConstraint!
    @IBOutlet var forwardedConstraint: NSLayoutConstraint!
    
    @IBOutlet var selectionSwitch: UISwitch!
    @IBOutlet var switchTrailingContstraint: NSLayoutConstraint!
    
    var longPressGestureRecognizer = UILongPressGestureRecognizer()
    
    var delegate: MailTableViewCellDelegate?
    
    var isFlagged: Bool = false {
        didSet {
            flagButton.isHidden = !isFlagged
            flagButton.tintColor = isFlagged ? UIColor(rgb: 0xF5A623) : UIColor(white: 0.85, alpha: 1.0)
            flagConstraint.isActive = isFlagged
            layoutSubviews()
        }
    }
    
    var isSelection = true {
        didSet {
            selectionSwitch.isHidden = !isSelection
            switchTrailingContstraint.isActive = isSelection
        }
    }
    
    var isAnswered: Bool = false {
        didSet {
            answeredImageView.isHidden = !isAnswered
        }
    }
    
    var isForwarded: Bool = false {
        didSet {
            forwardedImageView.isHidden = !isForwarded
            forwardedConstraint.isActive = isForwarded
            layoutSubviews()
        }
    }
    
    var isSeen: Bool = false {
        didSet {
            if #available(iOS 8.2, *) {
                senderLabel.font = isSeen ? UIFont.systemFont(ofSize: senderLabel.font.pointSize, weight: .medium) : UIFont.systemFont(ofSize: senderLabel.font.pointSize, weight: .bold)
                subjectLabel.font = isSeen ? UIFont.systemFont(ofSize: subjectLabel.font.pointSize, weight: .regular) : UIFont.systemFont(ofSize: subjectLabel.font.pointSize, weight: .bold)
                dateLabel.font = isSeen ? UIFont.systemFont(ofSize: dateLabel.font.pointSize, weight: .regular) : UIFont.systemFont(ofSize: dateLabel.font.pointSize, weight: .bold)
            } else {
                senderLabel.font = isSeen ? UIFont.systemFont(ofSize: senderLabel.font.pointSize) : UIFont.boldSystemFont(ofSize: senderLabel.font.pointSize)
                subjectLabel.font = isSeen ? UIFont.systemFont(ofSize: subjectLabel.font.pointSize) : UIFont.boldSystemFont(ofSize: subjectLabel.font.pointSize)
                dateLabel.font = isSeen ? UIFont.systemFont(ofSize: dateLabel.font.pointSize) : UIFont.boldSystemFont(ofSize: dateLabel.font.pointSize)
            }
            
            subjectLabel.textColor = isSeen ? .darkGray : .black
        }
    }
    
    var mail: APIMail? {
        didSet {
            if var senders = mail?.senders {
                if let email = API.shared.currentUser.email, let index = senders.firstIndex(of: email) {
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
            isAnswered = mail?.isAnswered ?? false
            isForwarded = mail?.isForwarded ?? false
            
            attachmentImageView.isHidden = !(mail?.hasAttachments ?? false)
            
            titleTrailingConstraint.isActive =  !attachmentImageView.isHidden
            
            threadConstraint.isActive = false
            threadBackground.isHidden = true
            unfoldButton.isHidden = true
            unfoldLayoutConstraint.isActive = false
            
            if let threadUID = mail?.threadUID {
                if threadUID != mail?.uid {
                    threadConstraint.isActive = true
                    threadBackground.isHidden = false
                } else if mail?.thread.count ?? 0 > 0 {
                    unfoldButton.isHidden = false
                    unfoldLayoutConstraint.isActive = true
                }
            }
        }
    }
    
    static func cellID() -> String {
        return "MailTableViewCell"
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        flagButton.isUserInteractionEnabled = false
        
        longPressGestureRecognizer.addTarget(self, action: #selector(self.longPressGestureAction(_:)))
        longPressGestureRecognizer.delegate = self
        contentView.addGestureRecognizer(longPressGestureRecognizer)
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
    
    @IBAction func unfoldButtonAction(_ sender: Any) {
        if let threadUID = mail?.threadUID {
            delegate?.unfoldThreadWith(id: threadUID)
        }
    }
    
    override func prepareForReuse() {
        mail = nil
    }
    
    @objc func longPressGestureAction(_ sender: UILongPressGestureRecognizer) {
        if !isSelection && sender.state == .began {
            NotificationCenter.default.post(name: .mainViewControllerShouldGoToSelectionMode, object: nil)
            
            if #available(iOS 10.0, *) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }
    
    
}
