//
//  MailBodyTableViewCell.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

class MailBodyTableViewCell: UITableViewCell {

    @IBOutlet var textView: UITextView!
    @IBOutlet var placeholderLabel: UILabel!
    @IBOutlet var heightConstraint: NSLayoutConstraint!
    
    weak open var delegate: (UITableViewDelegateExtensionProtocol & UITextViewDelegateExtensionProtocol)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        textView.isScrollEnabled = false
        textView.delegate = self
        placeholderLabel.text = NSLocalizedString("Enter message", comment: "")
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

    }
    
    func updateHeight(withAction: Bool) {
        textView.isScrollEnabled = true
        let height = max(400.0, textView.contentSize.height + 25.0);
        textView.isScrollEnabled = false
        
        heightConstraint.constant = height
        
        if withAction {
            delegate?.cellSizeDidChanged()
        }
    }
}


extension MailBodyTableViewCell: UITableViewCellExtensionProtocol {
    static func cellID() -> String {
        return "MailBodyTableViewCell"
    }
}


extension MailBodyTableViewCell: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = textView.text.count > 0
        ComposeMailModelController.shared.mail.plainBody = textView.text
        updateHeight(withAction: true)
        delegate?.textViewDidChanged(textView: textView)
    }
}
