//
//  ContactDetailTableViewswift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

enum ContactDetailTableViewCellStyle {
    case showButton
    case hideButton
    case uuid
    case group
    case fullName
    case eTag
    case viewEmail
    case personalEmail
    case businessEmail
    case otherEmail
    case primaryEmail
    case skype
    case facebook
    case personalMobile
    case primaryAddress
    case firstName
    case secondName
    case nickName
    case personalPhone
}

class ContactDetailTableViewCell: UITableViewCell {

    @IBOutlet var desctiptionLabel: UILabel!
    @IBOutlet var contentField: UITextField!
    @IBOutlet var showAdditionalFieldsLabel: UILabel!
    
    var style: ContactDetailTableViewCellStyle = .fullName {
        didSet {
            updateCell()
        }
    }
    
    var isEditable = true {
        didSet {
            contentField.isUserInteractionEnabled = isEditable
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        
        contentField.delegate = self
    }

    func updateCell() {
        var description: String?
        var content: String?
        let contact = ContactsModelController.shared.contact
        
        showAdditionalFieldsLabel.isHidden = true
        
        switch style {
        case .fullName:
            description = NSLocalizedString("Display name:", comment: "")
            content = contact.fullName
            break
            
        case .viewEmail:
            description = NSLocalizedString("Email:", comment: "")
            content = contact.viewEmail
            break
            
        case .personalMobile:
            description = NSLocalizedString("Mobile:", comment: "")
            content = contact.personalMobile
            break
            
        case .primaryAddress:
            description = NSLocalizedString("Address:", comment: "")
            content = contact.personalAddress
            break
            
        case .skype:
            description = NSLocalizedString("Skype:", comment: "")
            content = contact.skype
            break
            
        case .facebook:
            description = NSLocalizedString("Facebook:", comment: "")
            content = contact.facebook
            break
            
        case .firstName:
            description = NSLocalizedString("First name:", comment: "")
            content = contact.firstName
            break
            
        case .secondName:
            description = NSLocalizedString("Last name:", comment: "")
            content = contact.lastName
            break
            
        case .nickName:
            description = NSLocalizedString("Nickname:", comment: "")
            content = contact.nickName
            break
            
        case .personalPhone:
            description = NSLocalizedString("Phone:", comment: "")
            content = contact.personalPhone
            break
            
        case .showButton:
            showAdditionalFieldsLabel.isHidden = false
            showAdditionalFieldsLabel.text = NSLocalizedString("Show additional fields", comment: "")
            break
            
        case .hideButton:
            showAdditionalFieldsLabel.isHidden = false
            showAdditionalFieldsLabel.text = NSLocalizedString("Hide additional fields", comment: "")
            break
            
        default:
            break
        }
        
        desctiptionLabel.text = description
        contentField.text = content
    }
    
    @IBAction func contentFieldChanged(_ sender: UITextField) {
        var contact = ContactsModelController.shared.contact
        
        switch style {
        case .fullName:
            contact.fullName = sender.text
            break
            
        case .viewEmail:
            contact.viewEmail = sender.text
            break
            
        case .personalMobile:
            contact.personalMobile = sender.text
            break
            
        case .primaryAddress:
            contact.personalAddress = sender.text
            break
            
        case .skype:
            contact.skype = sender.text
            break
            
        case .facebook:
            contact.facebook = sender.text
            break
            
        case .firstName:
            contact.firstName = sender.text
            break
            
        case .secondName:
            contact.lastName = sender.text
            break
            
        case .nickName:
            contact.nickName = sender.text
            break
            
        case .personalPhone:
            contact.personalPhone = sender.text
            break
            
        default:
            break
        }
        
        ContactsModelController.shared.contact = contact
    }
    
}


extension ContactDetailTableViewCell: UITableViewCellExtensionProtocol {
    static func cellID() -> String {
        return "ContactDetailTableViewCell"
    }
}


extension ContactDetailTableViewCell: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}
