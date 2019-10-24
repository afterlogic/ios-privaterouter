//
//  GroupDetailsViewController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import SVProgressHUD

class GroupDetailsViewController: UIViewController {

    @IBOutlet var closeButton: UIBarButtonItem!
    @IBOutlet var saveButton: UIBarButtonItem!
    @IBOutlet var editButton: UIBarButtonItem!
    @IBOutlet var trashButton: UIBarButtonItem!
    @IBOutlet var mailButton: UIBarButtonItem!
    @IBOutlet var menuButton: UIBarButtonItem!
    
    @IBOutlet var tableView: UITableView!
    
    var inEditingMode = true {
        didSet {
        content = ContactDetailsContent(sectionHeader: nil, isHidden: false, cells: [
                .groupName,
                .groupIsCompany,
                .groupEmail,
                .groupCompany,
                .groupCountry,
                .groupState,
                .groupCity,
                .groupStreet,
                .groupZip,
                .groupPhone,
                .groupFax,
                .groupWeb,
            ])
                        
            if !inEditingMode {
                content = ContactDetailsContent(sectionHeader: nil, isHidden: false, cells: [
                    .groupName,
                    .groupEmail,
                    .groupCompany,
                    .groupCountry,
                    .groupState,
                    .groupCity,
                    .groupStreet,
                    .groupZip,
                    .groupPhone,
                    .groupFax,
                    .groupWeb,
                ])
            }
        }
    }
    
    var content =
        ContactDetailsContent(sectionHeader: nil, isHidden: false, cells: [
            .groupName,
            .groupIsCompany,
            .groupEmail,
            .groupCompany,
            .groupCountry,
            .groupState,
            .groupCity,
            .groupStreet,
            .groupZip,
            .groupPhone,
            .groupFax,
            .groupWeb,
        ])
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.register(cellClass: ContactDetailTableViewCell())
        tableView.tableFooterView = UIView(frame: .zero)
        
        updateNavigationBar()
        
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(
        self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isToolbarHidden = true
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func updateNavigationBar() {
        if !inEditingMode {
            title = NSLocalizedString("Group", comment: "")
            navigationItem.rightBarButtonItems = [menuButton, editButton, trashButton, mailButton]
        } else {
            if GroupsModelController.shared.group.uuid == "" {
                title = NSLocalizedString("Create group", comment: "")
            } else {
                title = NSLocalizedString("Edit group", comment: "")
            }
            
            navigationItem.rightBarButtonItems = [saveButton]
        }
    }
    
    @IBAction func closeButtonAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
        navigationController?.popViewController(animated: true)
    }
    
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
    
    @IBAction func saveButtonAction(_ sender: Any) {
        SVProgressHUD.show()
        
        API.shared.saveGroup(group: GroupsModelController.shared.group, edit: GroupsModelController.shared.group.uuid != "") { (result, error) in
            DispatchQueue.main.async {
                if error == nil {
                    SVProgressHUD.dismiss()
                    self.closeButtonAction(sender)
                } else {
                    SVProgressHUD.showError(withStatus: error?.localizedDescription)
                }
            }
        }
    }
    
    @IBAction func editButtonAction(_ sender: Any) {
        inEditingMode = true
        updateNavigationBar()
        tableView.reloadData()
    }
    
    @IBAction func deleteButtonAction(_ sender: Any) {
        SVProgressHUD.show()
        
        API.shared.deleteGroup(group: GroupsModelController.shared.group) { (result, error) in
            DispatchQueue.main.async {
                if error == nil {
                    SVProgressHUD.dismiss()
                    self.closeButtonAction(sender)
                    GroupsModelController.shared.selectedItem = ContactsGroupDB()
                    NotificationCenter.default.post(name: .contactsViewShouldUpdate, object: nil)
                } else {
                    SVProgressHUD.showError(withStatus: error?.localizedDescription)
                }
            }
        }
    }
    
    @IBAction func mailButtonAction(_ sender: Any) {
        var mail = APIMail()
        let contacts = StorageProvider.shared.getContacts(GroupsModelController.shared.group.uuid)
        mail.to = []
        
        for contact in contacts {
            mail.to?.append(contact.viewEmail ?? "")
        }
        
        ComposeMailModelController.shared.mail = mail
        
        performSegue(withIdentifier: "ComposeMessage", sender: nil)
    }
    
}

extension GroupDetailsViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if inEditingMode {
            return !GroupsModelController.shared.group.isOrganization ? 2 : content.cells.count
        } else {
            return content.cells.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ContactDetailTableViewCell.cellID(), for: indexPath) as! ContactDetailTableViewCell
        
        cell.isEditable = inEditingMode
        
        let style = content.cells[indexPath.row]
        cell.style = style
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if content.cells[indexPath.row] == .groupIsCompany && inEditingMode {
            GroupsModelController.shared.group.isOrganization.toggle()
            tableView.reloadData()
        }
    }
}


extension GroupDetailsViewController {
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
