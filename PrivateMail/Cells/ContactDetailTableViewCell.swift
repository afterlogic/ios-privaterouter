//
//  ContactDetailTableViewswift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

enum ContactDetailTableViewCellStyle {
    case header
    case showButton
    case hideButton
    case uuid
    case group
    case fullName
    case eTag
    case viewEmail
    case personalEmail
    case otherEmail
    case primaryEmail
    case skype
    case facebook
    case personalMobile
    case primaryPhone
    case primaryAddress
    case firstName
    case secondName
    case nickName
    case personalPhone
    case streetAddress
    case city
    case state
    case zipCode
    case country
    case webPage
    case fax
    case phone
    case businessEmail
    case businessCompany
    case businessDepartment
    case businessJobTitle
    case businessOffice
    case businessStreetAddress
    case businessCity
    case businessState
    case businessZip
    case businessCountry
    case businessWeb
    case businessFax
    case businessPhone
    case birthday
    case notes
    
    case groupName
    case groupIsCompany
    case groupEmail
    case groupCompany
    case groupCountry
    case groupState
    case groupCity
    case groupStreet
    case groupZip
    case groupPhone
    case groupFax
    case groupWeb
}

class ContactDetailTableViewCell: UITableViewCell {

    @IBOutlet var desctiptionLabel: UILabel!
    @IBOutlet var contentField: UITextField!
    @IBOutlet var showAdditionalFieldsLabel: UILabel!
    @IBOutlet var groupSwitch: UISwitch!
    
    var currentGroup: ContactsGroupDB?
    
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
        contentField.theme_textColor = .onSurfaceMajorText
        
        contentField.delegate = self
    }

    func updateCell() {
        var description: String?
        var content: String?
        let contact = ContactsModelController.shared.contact
        let group = GroupsModelController.shared.group
        
        showAdditionalFieldsLabel.isHidden = true
        contentField.isHidden = false
        groupSwitch.isHidden = true
        contentField.tag = 0
    
        if case .header = style {
            theme_backgroundColor = .secondarySurface
        } else {
            theme_backgroundColor = .surface
        }
        
        switch style {
        case .header:
            contentField.isHidden = true
            content = nil
            break
            
        case .primaryPhone:
            description = NSLocalizedString("Primary Phone:", comment: "")
            
            let primaryPhone = contact.primaryPhone ?? 0
            contentField.tag = primaryPhone
            
            if primaryPhone == 0 {
                content = contact.personalPhone
            } else if primaryPhone == 1 {
                content = contact.personalMobile
            } else {
                content = contact.businessPhone
            }
            
            break
            
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
            description = NSLocalizedString("Primary Address:", comment: "")
            
            let primaryAddress = contact.primaryAddress ?? 0
            contentField.tag = primaryAddress
            
            if primaryAddress == 0 {
                content = contact.personalAddress
            } else if primaryAddress == 1 {
                content = contact.businessAddress
            } else {
                content = ""
            }
            
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
            
        case .group:
            description = currentGroup?.name ?? ("(no name)")
            groupSwitch.isOn = ContactsModelController.shared.contact.groupUUIDs?.contains(currentGroup?.uuid ?? "") ?? false
            
            if isEditable {
                groupSwitch.isHidden = false
            } else {
                groupSwitch.isHidden = !groupSwitch.isOn
            }
            
            contentField.isHidden = true
            
            break
            
        case .groupName:
            description = NSLocalizedString("Name:", comment: "")
            content = group.name
            break
            
        case .groupIsCompany:
            description = NSLocalizedString("This group is a Company", comment: "")
            groupSwitch.isHidden = false
            groupSwitch.isOn = group.isOrganization
            contentField.isHidden = true
            break
            
        case .groupEmail:
            description = NSLocalizedString("Email:", comment: "")
            content = group.email
            break
            
        case .groupCompany:
            description = NSLocalizedString("Company:", comment: "")
            content = group.company
            break
        
        case .groupCountry:
            description = NSLocalizedString("Country:", comment: "")
            content = group.county
            break
            
        case .groupState:
            description = NSLocalizedString("State:", comment: "")
            content = group.state
            break
            
        case .groupCity:
            description = NSLocalizedString("City:", comment: "")
            content = group.city
            break
            
        case .groupStreet:
            description = NSLocalizedString("Street:", comment: "")
            content = group.street
            break
            
        case .groupZip:
            description = NSLocalizedString("Zip:", comment: "")
            content = group.zip
            break
            
        case .groupPhone:
            description = NSLocalizedString("Phone:", comment: "")
            content = group.phone
            break
            
        case .groupFax:
            description = NSLocalizedString("Fax:", comment: "")
            content = group.fax
            break
            
        case .groupWeb:
            description = NSLocalizedString("Web:", comment: "")
            content = group.web
            break
 
        case .personalEmail:
            description = NSLocalizedString("Email:", comment: "")
            content = contact.personalEmail
            break
            
        case .otherEmail:
            description = NSLocalizedString("Email:", comment: "")
            content = contact.otherEmail
            break
            
        case .primaryEmail:
            description = NSLocalizedString("Primary Email:", comment: "")
            let primaryEmail = contact.primaryEmail ?? 0
            contentField.tag = primaryEmail
            
            if primaryEmail == 0 {
                content = contact.personalEmail
            } else if primaryEmail == 1 {
                content = contact.businessEmail
            } else {
                content = contact.otherEmail
            }
            
            break
                        
        case .streetAddress:
            description = NSLocalizedString("Street:", comment: "")
            content = contact.personalAddress
            break
            
        case .city:
            description = NSLocalizedString("City:", comment: "")
            content = contact.city
            break
            
        case .state:
            description = NSLocalizedString("State/Province:", comment: "")
            content = contact.state
            break
            
        case .zipCode:
            description = NSLocalizedString("Zip code:", comment: "")
            content = contact.zip
            break
            
        case .country:
            description = NSLocalizedString("Country/Region:", comment: "")
            content = contact.country
            break
            
        case .webPage:
            description = NSLocalizedString("Web page:", comment: "")
            content = contact.web
            break
            
        case .fax:
            description = NSLocalizedString("Fax:", comment: "")
            content = contact.fax
            break
            
        case .phone:
            description = NSLocalizedString("Phone:", comment: "")
            content = contact.personalPhone
            break
            
        case .businessEmail:
            description = NSLocalizedString("Email:", comment: "")
            content = contact.businessEmail
            break
            
        case .businessCompany:
            description = NSLocalizedString("Company:", comment: "")
            content = contact.businessCompany
            break
            
        case .businessDepartment:
            description = NSLocalizedString("Department:", comment: "")
            content = contact.businessDepartment
            break
            
        case .businessJobTitle:
            description = NSLocalizedString("Job Title:", comment: "")
            content = contact.businessJobTitle
            break
            
        case .businessOffice:
            description = NSLocalizedString("Office:", comment: "")
            content = contact.businessOffice
            break
            
        case .businessStreetAddress:
            description = NSLocalizedString("Street:", comment: "")
            content = contact.businessAddress
            break
            
        case .businessCity:
            description = NSLocalizedString("City:", comment: "")
            content = contact.businessCity
            break
            
        case .businessState:
            description = NSLocalizedString("State/Province:", comment: "")
            content = contact.businessState
            break
            
        case .businessZip:
            description = NSLocalizedString("Zip:", comment: "")
            content = contact.businessZip
            break
            
        case .businessCountry:
            description = NSLocalizedString("Country/Region:", comment: "")
            content = contact.businessCountry
            break
            
        case .businessWeb:
            description = NSLocalizedString("Web:", comment: "")
            content = contact.businessWeb
            break
            
        case .businessFax:
            description = NSLocalizedString("Fax:", comment: "")
            content = contact.businessFax
            break
            
        case .businessPhone:
            description = NSLocalizedString("Phone:", comment: "")
            content = contact.businessPhone
            break
            
        case .birthday:
            description = NSLocalizedString("Birthday:", comment: "")
            content = ""
            
            if contact.birthDay ?? 0 > 0 && contact.birthMonth ?? 0 > 0 && contact.birthYear ?? 0 > 0 {
                content = "\(contact.birthDay!).\(contact.birthMonth!).\(contact.birthYear!)"
            }
            
            break
            
        case .notes:
            description = NSLocalizedString("Notes:", comment: "")
            content = contact.notes
            break
 
        default:
            break
        }
        
        desctiptionLabel.text = description
        contentField.text = content
    }
    
    @IBAction func contentFieldChanged(_ sender: UITextField) {        
        var contact = ContactsModelController.shared.contact
        let group = GroupsModelController.shared.group
        
        let senderText = sender.text ?? ""
        
        switch style {
        case .fullName:
            contact.fullName = sender.text
            break
           
        case .primaryPhone:
            contact.primaryPhone = contentField.tag
            break
            
        case .viewEmail:
            contact.viewEmail = sender.text
            break
            
        case .personalMobile:
            contact.personalMobile = sender.text
            break
            
        case .primaryAddress:
            contact.primaryEmail = contentField.tag
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
            
        case .groupName:
            group.name = senderText
            break
            
        case .groupEmail:
            group.email = senderText
            break
            
        case .groupCompany:
            group.company = senderText
            break
            
        case .groupCountry:
            group.county = senderText
            break
            
        case .groupState:
            group.state = senderText
            break
            
        case .groupCity:
            group.city = senderText
            break
            
        case .groupStreet:
            group.street = senderText
            break
            
        case .groupZip:
            group.zip = senderText
            break
            
        case .groupPhone:
            group.phone = senderText
            break
            
        case .groupFax:
            group.fax = senderText
            break
            
        case .groupWeb:
            group.web = senderText
            break
            
        case .personalEmail:
            contact.personalEmail = sender.text
            break
            
        case .otherEmail:
            contact.otherEmail = sender.text
            break
            
        case .primaryEmail:
            contact.primaryEmail = contentField.tag
            break
            
        case .streetAddress:
            contact.personalAddress = sender.text
            break
            
        case .city:
            contact.city = sender.text
            break
            
        case .state:
            contact.state = sender.text
            break
            
        case .zipCode:
            contact.zip = sender.text
            break
            
        case .country:
            contact.country = sender.text
            break
            
        case .webPage:
            contact.web = sender.text
            break
            
        case .fax:
            contact.fax = sender.text
            break
            
        case .phone:
            contact.personalPhone = sender.text
            break
            
        case .businessEmail:
            contact.businessEmail = sender.text
            break
            
        case .businessCompany:
            contact.businessCompany = sender.text
            break
            
        case .businessDepartment:
            contact.businessDepartment = sender.text
            break
            
        case .businessJobTitle:
            contact.businessJobTitle = sender.text
            break
            
        case .businessOffice:
            contact.businessOffice = sender.text
            break
            
        case .businessStreetAddress:
            contact.businessAddress = sender.text
            break
            
        case .businessCity:
            contact.businessCity = sender.text
            break
            
        case .businessState:
            contact.businessState = sender.text
            break
            
        case .businessZip:
            contact.businessZip = sender.text
            break
            
        case .businessCountry:
            contact.businessCountry = sender.text
            break
            
        case .businessWeb:
            contact.businessWeb = sender.text
            break
            
        case .businessFax:
            contact.businessFax = sender.text
            break
            
        case .businessPhone:
            contact.businessPhone = sender.text
            break
            
        case .notes:
            contact.notes = sender.text
            break
            
        default:
            break
        }
        
        GroupsModelController.shared.group = group
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
