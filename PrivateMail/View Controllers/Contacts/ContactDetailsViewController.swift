//
//  ContactDetailsViewController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import SVProgressHUD
import Contacts

struct ContactDetailsContent {
    var sectionHeader: String?
    var isHidden: Bool
    var cells: [ContactDetailTableViewCellStyle] = []
}

class ContactDetailsViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    
    @IBOutlet var editButton: UIBarButtonItem!
    @IBOutlet var composeButton: UIBarButtonItem!
    @IBOutlet var searchButton: UIBarButtonItem!
    @IBOutlet var addToMailButton: UIBarButtonItem!
    @IBOutlet var datePickerField: UITextField!
    @IBOutlet var menuButton: UIBarButtonItem!
    
    let datePicker = UIDatePicker()
    
    var isAdding: Bool = false
    
    var showAdditionalFields = false {
        didSet {
            if showAdditionalFields {
                content[0] = ContactDetailsContent(sectionHeader: nil, isHidden: false, cells: [
                    .fullName,
                    .primaryEmail,
                    .primaryPhone,
                    .primaryAddress,
                    .skype,
                    .facebook,
                    .showButton
                ])
            } else {
                content[0] = ContactDetailsContent(sectionHeader: nil, isHidden: false, cells: [
                    .fullName,
                    .personalEmail,
                    .personalMobile,
                    .streetAddress,
                    .skype,
                    .facebook,
                    .showButton
                ])
            }
            
            tableView.reloadData()
        }
    }
    
    var inEditMode: Bool = false {
        didSet {
            tableView.reloadData()
        }
    }
    
    let refreshControl = UIRefreshControl()
    
    var content = [
        ContactDetailsContent(sectionHeader: nil, isHidden: false, cells: [
            .fullName,
            .personalEmail,
            .personalMobile,
            .streetAddress,
            .skype,
            .facebook,
            .showButton
        ]),
        ContactDetailsContent(sectionHeader: nil, isHidden: false, cells: [
            .firstName,
            .secondName,
            .nickName
        ]),
        ContactDetailsContent(sectionHeader: NSLocalizedString("Home", comment: ""), isHidden: false, cells: [
            .header,
            .personalEmail,
            .streetAddress,
            .city,
            .state,
            .zipCode,
            .country,
            .webPage,
            .fax,
            .personalPhone,
            .personalMobile,
        ]),
        ContactDetailsContent(sectionHeader: NSLocalizedString("Business", comment: ""), isHidden: false, cells: [
            .header,
            .businessEmail,
            .businessCompany,
            .businessDepartment,
            .businessJobTitle,
            .businessOffice,
            .businessStreetAddress,
            .businessCity,
            .businessState,
            .businessZip,
            .businessCountry,
            .businessWeb,
            .businessFax,
            .businessPhone,
        ]),
        ContactDetailsContent(sectionHeader: NSLocalizedString("Other", comment: ""), isHidden: false, cells: [
            .header,
            .birthday,
            .otherEmail,
            .notes,
        ]),
        ContactDetailsContent(sectionHeader: NSLocalizedString("Groups", comment: ""), isHidden: false, cells: [
            .header
        ]),
        ] as [ContactDetailsContent]
    
    var groups: [ContactsGroupDB] = [] {
        didSet {
            var cells: [ContactDetailTableViewCellStyle] = [.header]
            
    
            for _ in groups {
                cells.append(.group)
            }
            
            content[5].cells = cells
        }
    }
    
    var oldTitle: String?
    var oldButtons: [UIBarButtonItem]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if isAdding {
            title = NSLocalizedString("Create contact", comment: "")
            editButton.title = NSLocalizedString("Save", comment: "")
            editButton.tag = 2
            navigationItem.rightBarButtonItems = [editButton]
        } else {
            title = NSLocalizedString("Contact", comment: "")
        }
        
        hidesBottomBarWhenPushed = true
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.contentInset.bottom = 60.0
        
        tableView.register(cellClass: ContactDetailTableViewCell())
        tableView.tableFooterView = UIView(frame: .zero)
        
        refreshControl.addTarget(self, action: #selector(refreshControlAction), for: .valueChanged)
        
        if #available(iOS 10.0, *) {
            tableView.refreshControl = refreshControl
        } else {
            tableView.addSubview(refreshControl)
        }
        
        reloadData()
        
        API.shared.getContactGroups { (result, error) in
            if let result = result {
                self.groups = result
                self.reloadData()
            }
        }
        
        
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isToolbarHidden = true
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func refreshControlAction() {
        if !tableView.isDragging {
            reloadData()
        }
    }
    
    func reloadData() {
        DispatchQueue.main.async {
            self.refreshControl.endRefreshing()
            self.tableView.reloadData()
        }
    }
    
    
    // MARK: - Button Actions
    
    @IBAction func menuButtonAction(_ sender: Any) {
        let actionSheet = UIAlertController.init(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let mailButton = UIAlertAction.init(title: NSLocalizedString("Mails", comment: ""), style: .default) { (alert: UIAlertAction!) in
            self.dismiss(animated: false, completion: nil)
            self.navigationController?.popToRootViewController(animated: true)
        }
        
        let contactsButton = UIAlertAction.init(title: NSLocalizedString("Contacts", comment: ""), style: .default) { (alert: UIAlertAction!) in
            self.dismiss(animated: false, completion: nil)
            self.navigationController?.popViewController(animated: true)
        }
        
        let settingsButton = UIAlertAction.init(title: NSLocalizedString("Settings", comment: ""), style: .default) { (alert: UIAlertAction!) in
            self.performSegue(withIdentifier: "SettingsSegue", sender: nil)
        }
        
        let logOutButton = UIAlertAction.init(title: NSLocalizedString("Log Out", comment: ""), style: .default) { (alert: UIAlertAction!) in
            SVProgressHUD.show()
            
            API.shared.logout(completionHandler: { (result, error) in
                if let error = error {
                    SVProgressHUD.showError(withStatus: error.localizedDescription)
                } else {
                    SVProgressHUD.dismiss()
                    NotificationCenter.default.post(name: .failedToLogin, object: nil)
                }
            })
        }
        
        let cancelButton = UIAlertAction.init(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { (alert: UIAlertAction!) in
            
        }
        
        actionSheet.addAction(mailButton)
        actionSheet.addAction(contactsButton)
        actionSheet.addAction(settingsButton)
        actionSheet.addAction(logOutButton)
        actionSheet.addAction(cancelButton)
        
        present(actionSheet, animated: true, completion: nil)
    }
    
    @IBAction func editButtonAction(_ sender: Any) {
        if editButton.tag < 2 {
            if editButton.tag == 0 {
                oldTitle = title
                title = NSLocalizedString("Edit contact", comment: "")
                
                oldButtons = navigationItem.rightBarButtonItems
                navigationItem.rightBarButtonItems = [editButton]
                
                editButton.tag = 1
                inEditMode = editButton.tag == 1
                editButton.title = inEditMode ? NSLocalizedString("Done", comment: "") : NSLocalizedString("Edit", comment: "")
            } else {
                editButton.isEnabled = false
                
                SVProgressHUD.show()
                
                API.shared.saveContact(contact: ContactsModelController.shared.contact, edit: true) { (result, error) in
                    DispatchQueue.main.async {
                        self.editButton.isEnabled = true
                        SVProgressHUD.dismiss()
                        
                        if result != nil {
                            self.title = self.oldTitle
                            self.navigationItem.rightBarButtonItems = self.oldButtons
                            self.editButton.tag = 0
                            self.inEditMode = self.editButton.tag == 1
                            self.editButton.title = self.inEditMode ? NSLocalizedString("Done", comment: "") : NSLocalizedString("Edit", comment: "")
                        } else if let error = error {
                            SVProgressHUD.showError(withStatus: error.localizedDescription)
                        } else {
                            SVProgressHUD.showError(withStatus: Strings.failedToEditContact)
                        }
                    }
                }
            }
        } else if editButton.tag == 2 {
            editButton.isEnabled = false
            
            SVProgressHUD.show()
            
            API.shared.saveContact(contact: ContactsModelController.shared.contact, edit: false) { (result, error) in
                DispatchQueue.main.async {
                    self.editButton.isEnabled = true
                    SVProgressHUD.dismiss()
                    
                    if result != nil {
                        self.dismiss(animated: true, completion: nil)
                    } else if let error = error {
                        SVProgressHUD.showError(withStatus: error.localizedDescription)
                    } else {
                        SVProgressHUD.showError(withStatus: Strings.failedToSaveContact)
                    }
                }
            }
        }
        
    }
    
    @IBAction func composeButtonAction(_ sender: Any) {
        let emails = ContactsModelController.shared.contact.emails
        
        if emails.count > 0 {
            var mail = APIMail()
            mail.to = emails
            
            ComposeMailModelController.shared.mail = mail
            
            performSegue(withIdentifier: "ComposeSegue", sender: nil)
        } else {
            SVProgressHUD.showError(withStatus: NSLocalizedString("Empty email", comment: ""))
        }
    }
    
    @IBAction func searchButtonAction(_ sender: Any) {
        navigationController?.popToRootViewController(animated: true)
        NotificationCenter.default.post(name: .mainViewControllerShouldMakeSearch, object: "email: \(ContactsModelController.shared.contact.emails.joined(separator: ", "))")
    }
    
    @IBAction func addToMailButtonAction(_ sender: Any) {
        if #available(iOS 9.0, *) {
            let mail = APIMail()
            ComposeMailModelController.shared.mail = mail
            
            let contactItem = ContactsModelController.shared.contact
            
            let contact = CNMutableContact()
            contact.givenName = contactItem.fullName ?? ""
            contact.emailAddresses = [
                CNLabeledValue(label: CNLabelHome, value: (contactItem.personalEmail ?? "") as NSString),
                CNLabeledValue(label: CNLabelWork, value: (contactItem.businessEmail ?? "") as NSString),
                CNLabeledValue(label: CNLabelOther, value: (contactItem.otherEmail ?? "") as NSString),
            ]
            
            do {
                let data = try CNContactVCardSerialization.data(with: [contact])
                let directory = NSTemporaryDirectory()
                let fileName = (contactItem.viewEmail ?? "contact") + ".vcf"
                
                let url = URL(fileURLWithPath: directory + fileName)
                try data.write(to: url)
                
                ComposeMailModelController.shared.attachmentFileURL = url
                
                performSegue(withIdentifier: "ComposeSegue", sender: nil)
            } catch {
                SVProgressHUD.showError(withStatus: "Can't share contact")
            }
        } else {
            SVProgressHUD.showError(withStatus: "This feature is available for iOS 9 and above")
        }
    }
    
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
    }
    
}


extension ContactDetailsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if content[indexPath.section].cells[indexPath.row] == .header {
            return 33.0
        } else {
            return 44.0
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return showAdditionalFields ? content.count : 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if content[section].isHidden {
            return 1
        } else {
            return content[section].cells.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ContactDetailTableViewCell.cellID(), for: indexPath) as! ContactDetailTableViewCell
        
        cell.isEditable = inEditMode || isAdding
        
        let content = self.content[indexPath.section]
        let style = content.cells[indexPath.row]
        
        if style == .group {
            let groupsId = ContactsModelController.shared.contact.groupUUIDs!
            let group = groups[indexPath.row - 1]
            if(groupsId.contains(group.uuid) || cell.isEditable){
                cell.isHidden=false
                cell.currentGroup = group
            }else{
                cell.isHidden=true
                cell.currentGroup = nil
            }
            
        }
        
        cell.style = style
        
        if style == .header {
            cell.desctiptionLabel.text = content.sectionHeader
        }
        
        if style == .showButton {
            cell.style = showAdditionalFields ? .hideButton : .showButton
        }
        
        if style == .primaryAddress || style == .primaryEmail || style == .primaryPhone || style == .birthday {
            cell.isEditable = false
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let style = content[indexPath.section].cells[indexPath.row]
        
        if style == .birthday {
            showDatePicker()
        } else if (style == .primaryAddress || style == .primaryEmail || style == .primaryPhone) && (inEditMode || isAdding) {
            let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            
            var first = UIAlertAction()
            var second = UIAlertAction()
            var third = UIAlertAction()
            
            switch style {
            case .primaryPhone:
                first = UIAlertAction(title: "Personal Phone", style: .default, handler: { (action) in
                    ContactsModelController.shared.contact.primaryPhone = 0
                    self.tableView.reloadData()
                })
                second = UIAlertAction(title: "Personal Mobile", style: .default, handler: { (action) in
                    ContactsModelController.shared.contact.primaryPhone = 1
                    self.tableView.reloadData()
                })
                third = UIAlertAction(title: "Business Phone", style: .default, handler: { (action) in
                    ContactsModelController.shared.contact.primaryPhone = 2
                    self.tableView.reloadData()
                })
                break
                
            case .primaryAddress:
                first = UIAlertAction(title: "Personal Address", style: .default, handler: { (action) in
                    ContactsModelController.shared.contact.primaryAddress = 0
                    self.tableView.reloadData()
                })
                second = UIAlertAction(title: "Business Address", style: .default, handler: { (action) in
                    ContactsModelController.shared.contact.primaryAddress = 1
                    self.tableView.reloadData()
                })
                break
                
            case .primaryEmail:
                first = UIAlertAction(title: "Personal E-mail", style: .default, handler: { (action) in
                    ContactsModelController.shared.contact.primaryEmail = 0
                    self.tableView.reloadData()
                })
                second = UIAlertAction(title: "Business E-mail", style: .default, handler: { (action) in
                    ContactsModelController.shared.contact.primaryEmail = 1
                    self.tableView.reloadData()
                })
                third = UIAlertAction(title: "Other E-mail", style: .default, handler: { (action) in
                    ContactsModelController.shared.contact.primaryEmail = 2
                    self.tableView.reloadData()
                })
                break
                
            default:
                return
            }
            
            let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            
            actionSheet.addAction(first)
            actionSheet.addAction(second)
            
            if style != .primaryAddress {
                actionSheet.addAction(third)
            }
            
            actionSheet.addAction(cancel)
            
            present(actionSheet, animated: true, completion: nil)
        } else if style == .header {
            content[indexPath.section].isHidden.toggle()
            tableView.reloadSections(IndexSet([indexPath.section]), with: .automatic)
        } else if style == .showButton {
            showAdditionalFields = !showAdditionalFields
        } else if style == .group && (inEditMode || isAdding) {
            let groupUUID = groups[indexPath.row - 1].uuid
            
            if ContactsModelController.shared.contact.groupUUIDs == nil {
                ContactsModelController.shared.contact.groupUUIDs = []
            }
            
            if ContactsModelController.shared.contact.groupUUIDs?.contains(groupUUID) ?? false {
                ContactsModelController.shared.contact.groupUUIDs?.removeAll(where: { (item) -> Bool in
                    return item == groupUUID
                })
            } else {
                ContactsModelController.shared.contact.groupUUIDs?.append(groupUUID)
            }
            
            reloadData()
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if refreshControl.isRefreshing {
            refreshControlAction()
        }
    }
}


extension ContactDetailsViewController {
    func showDatePicker() {
        datePicker.datePickerMode = .date
        
        let toolbar = UIToolbar();
        toolbar.sizeToFit()
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(doneDatePicker));
        let spaceButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
        let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelDatePicker));
        
        toolbar.setItems([doneButton, spaceButton, cancelButton], animated: false)
        
        datePickerField.inputAccessoryView = toolbar
        datePickerField.inputView = datePicker
        datePickerField.becomeFirstResponder()
    }
    
    @objc func doneDatePicker() {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        ContactsModelController.shared.contact.birthDay = Int(formatter.string(from: datePicker.date)) ?? 0
        
        formatter.dateFormat = "MM"
        ContactsModelController.shared.contact.birthMonth = Int(formatter.string(from: datePicker.date)) ?? 0
        
        formatter.dateFormat = "yyyy"
        ContactsModelController.shared.contact.birthYear = Int(formatter.string(from: datePicker.date)) ?? 0
        
        datePickerField.resignFirstResponder()
        tableView.reloadData()
    }
    
    @objc func cancelDatePicker(){
        datePickerField.resignFirstResponder()
    }
}


extension ContactDetailsViewController {
    @objc func keyboardWillShow(_ notification: Notification) {
        if let keyboardFrame: NSValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let keyboardRectangle = keyboardFrame.cgRectValue
            let keyboardHeight = keyboardRectangle.height
            
            UIView.animate(withDuration: 0.25) {
                self.tableView.contentInset.bottom = keyboardHeight
            }
        }
    }
    
    @objc func keyboardWillHide(_ notification: Notification) {
        UIView.animate(withDuration: 0.25) {
            self.tableView.contentInset.bottom = 0.0
        }
    }
}
