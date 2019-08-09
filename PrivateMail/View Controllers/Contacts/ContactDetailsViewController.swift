//
//  ContactDetailsViewController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import SVProgressHUD

struct ContactDetailsContent {
    var sectionHeader: String?
    var cells: [ContactDetailTableViewCellStyle] = []
}

class ContactDetailsViewController: UIViewController {

    @IBOutlet var tableView: UITableView!
    
    @IBOutlet var editButton: UIBarButtonItem!
    @IBOutlet var composeButton: UIBarButtonItem!
    
    var isAdding: Bool = false
    
    var showAdditionalFields = false {
        didSet {
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
        ContactDetailsContent(sectionHeader: nil, cells: [
            .fullName,
            .viewEmail,
            .personalMobile,
            .primaryAddress,
            .skype,
            .facebook,
            .showButton
        ]),
        ContactDetailsContent(sectionHeader: nil, cells: [
            .firstName,
            .secondName,
            .personalPhone,
            .nickName
        ]),
        ContactDetailsContent(sectionHeader: NSLocalizedString("Home", comment: ""), cells: [
            .primaryAddress,
            ])
    ] as [ContactDetailsContent]
    
    var oldTitle: String?
    var oldButtons: [UIBarButtonItem]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if isAdding {
            title = NSLocalizedString("Add contact", comment: "")
            editButton.title = NSLocalizedString("Save", comment: "")
            editButton.tag = 2
            navigationItem.rightBarButtonItems = [editButton]
        } else {
            title = NSLocalizedString("Contact", comment: "")
        }
        
        hidesBottomBarWhenPushed = true
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.register(cellClass: ContactDetailTableViewCell())
        tableView.tableFooterView = UIView(frame: .zero)
        
        refreshControl.addTarget(self, action: #selector(refreshControlAction), for: .valueChanged)
        
        if #available(iOS 10.0, *) {
            tableView.refreshControl = refreshControl
        } else {
            tableView.addSubview(refreshControl)
        }
        
        reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isToolbarHidden = true
    }
    
    @objc func refreshControlAction() {
        if !tableView.isDragging {
            reloadData()
        }
    }
    
    func reloadData() {
        refreshControl.endRefreshing()
        tableView.reloadData()
    }
    
    
    // MARK: - Button Actions
    
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
                            SVProgressHUD.showError(withStatus: NSLocalizedString("Failed to edit contact", comment: ""))
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
                        SVProgressHUD.showError(withStatus: NSLocalizedString("Failed to save contact", comment: ""))
                    }
                }
            }
        }
        
    }
    
    @IBAction func composeButtonAction(_ sender: Any) {
        var email = ContactsModelController.shared.contact.viewEmail ?? ""
        email = email.replacingOccurrences(of: " ", with: "")
        
        if email.count > 0 {
            if email.isEmail {
                var mail = APIMail()
                mail.to = [email]
                
                ComposeMailModelController.shared.mail = mail
                
                performSegue(withIdentifier: "ComposeSegue", sender: nil)
            } else {
                SVProgressHUD.showError(withStatus: NSLocalizedString("Invalid email", comment: ""))
            }
        } else {
            SVProgressHUD.showError(withStatus: NSLocalizedString("Empty email", comment: ""))
        }
    }
    
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
    }
    
}


extension ContactDetailsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return showAdditionalFields ? content.count : 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return content[section].cells.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ContactDetailTableViewCell.cellID(), for: indexPath) as! ContactDetailTableViewCell
        
        cell.isEditable = inEditMode || isAdding
        
        cell.style = content[indexPath.section].cells[indexPath.row]
        
        if cell.style == .showButton {
            cell.style = showAdditionalFields ? .hideButton : .showButton
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return content[section].sectionHeader
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if content[indexPath.section].cells[indexPath.row] == .showButton {
            showAdditionalFields = !showAdditionalFields
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if refreshControl.isRefreshing {
            refreshControlAction()
        }
    }
}
