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
    @IBOutlet var detailsView: UIView!
    @IBOutlet var heightConstraint: NSLayoutConstraint!
    
    @IBOutlet var detailedSenderLabel: UILabel!
    @IBOutlet var detailedToLabel: UILabel!
    @IBOutlet var detailedDateLabel: UILabel!
    
    @IBOutlet var fromTitleLabel: UILabel!
    @IBOutlet var toTitleLabel: UILabel!
    @IBOutlet var dateTitleLabel: UILabel!
    
    
    weak open var delegate: UITableViewDelegateExtensionProtocol?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        fromTitleLabel.text = NSLocalizedString("From", comment: "")
        toTitleLabel.text = NSLocalizedString("To", comment: "")
        dateTitleLabel.text = NSLocalizedString("Date", comment: "")
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

    }
    
    @IBAction func showHideButtonAction(_ sender: Any) {
        heightConstraint.isActive = !heightConstraint.isActive
        
        detailsView.isHidden = heightConstraint.isActive
        
        delegate?.cellSizeDidChanged()
    }
}


extension MailHeaderTableViewCell: UITableViewCellExtensionProtocol {
    static func cellID() -> String {
        return "MailHeaderTableViewCell"
    }
}
