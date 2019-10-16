//
//  ContactsViewController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import SVProgressHUD
import SideMenu

extension Notification.Name {
    static let contactsViewShouldUpdate = Notification.Name(rawValue: "contactsViewShouldUpdate")
}

class ContactsViewController: UIViewController {

    @IBOutlet var tableView: UITableView!
    
    @IBOutlet var searchButton: UIBarButtonItem!
    @IBOutlet var addButton: UIBarButtonItem!
    @IBOutlet var menuButton: UIBarButtonItem!
    @IBOutlet var sideMenuAction: UIBarButtonItem!
    @IBOutlet var showGroupButton: UIBarButtonItem!
    @IBOutlet var addGroupButton: UIButton!
    @IBOutlet var addContactButton: UIButton!
    
    var contacts: [APIContact] = [] {
        didSet {
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    let refreshControl = UIRefreshControl()
    let searchBar = UISearchBar()
    
    var searchTimer: Timer?
    
    var isSelection: Bool = false
    var selectionStyle: AddressTableViewCellStyle? = nil
    
    var selectedCells: [APIContact] = [
        ] {
        didSet {
            if selectedCells.count > 0 {
                title = NSLocalizedString("Selected: \(selectedCells.count)", comment: "")
            } else if isSelection {
                title = NSLocalizedString("Choose contacts", comment: "")
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("Contacts", comment: "")
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.register(cellClass: ContactTableViewCell())
        tableView.tableFooterView = UIView(frame: .zero)
        
        refreshControl.addTarget(self, action: #selector(refreshControlAction), for: .valueChanged)
        
        if #available(iOS 10.0, *) {
            tableView.refreshControl = refreshControl
        } else {
            tableView.addSubview(refreshControl)
        }
            
        addContactButton.layer.cornerRadius = addContactButton.frame.width / 2.0
        addGroupButton.layer.cornerRadius = addGroupButton.frame.width / 2.0
        
        NotificationCenter.default.addObserver(self, selector: #selector(shouldUpdateTitle), name: .contactsViewShouldUpdate, object: nil)
        
        shouldUpdateTitle()
        
        setupSearchBar()
        reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isToolbarHidden = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let sideVC = (self.storyboard?.instantiateViewController(withIdentifier: "GroupsViewController"))!
        SideMenuManager.default.menuLeftNavigationController = UISideMenuNavigationController(rootViewController: sideVC) 
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func shouldUpdateTitle() {
        if isSelection {
            title = NSLocalizedString("Choose contacts", comment: "")
            navigationItem.leftBarButtonItems = nil
            navigationItem.rightBarButtonItems = [addButton, searchButton]
        } else {
            navigationItem.titleView = setTitle(title: NSLocalizedString("Contacts", comment: ""), subtitle: GroupsModelController.shared.selectedItem.name)
            
            navigationItem.hidesBackButton = true
            navigationItem.leftBarButtonItem = sideMenuAction
            navigationItem.rightBarButtonItems = [menuButton, searchButton]
            
            NotificationCenter.default.addObserver(self, selector: #selector(didSelectFolder), name: .didSelectFolder, object: nil)
            
            if GroupsModelController.shared.selectedItem.uuid != "" {
                navigationItem.rightBarButtonItems?.append(showGroupButton)
            }
        }
        
        addContactButton.isHidden = isSelection
        addGroupButton.isHidden = isSelection
        
        reloadData()
    }
    
    func setTitle(title:String, subtitle:String) -> UIView {
        let titleLabel = UILabel(frame: CGRect(x: 0, y: -2, width: 0, height: 0))
        titleLabel.textColor = .white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 17)
        titleLabel.text = title
        titleLabel.sizeToFit()

        let subtitleLabel = UILabel(frame: CGRect(x: 0, y: 18, width: 0, height: 0))
        subtitleLabel.textColor = .init(white: 1.0, alpha: 0.9)
        subtitleLabel.font = UIFont.systemFont(ofSize: 12)
        subtitleLabel.text = subtitle
        subtitleLabel.sizeToFit()

        let titleView = UIView(frame: CGRect(x: 0, y: 0, width: max(titleLabel.frame.size.width, subtitleLabel.frame.size.width), height: 30))
        titleView.addSubview(titleLabel)
        titleView.addSubview(subtitleLabel)

        let widthDiff = subtitleLabel.frame.size.width - titleLabel.frame.size.width

        if widthDiff < 0 {
            let newX = widthDiff / 2
            subtitleLabel.frame.origin.x = abs(newX)
        } else {
            let newX = widthDiff / 2
            titleLabel.frame.origin.x = newX
        }

        return titleView
    }
    
    @objc func didSelectFolder() {
        navigationController?.popViewController(animated: false)
    }
    
    @objc func refreshControlAction() {
        if !tableView.isDragging {
            reloadData()
        }
    }
    
    func reloadData() {
        DispatchQueue.main.async {
            self.refreshControl.beginRefreshing(in: self.tableView)
            
            let oldCTag = StorageProvider.shared.getContactsGroup()?.cTag ?? -1
            
            let selectedGroup = GroupsModelController.shared.selectedItem
            self.contacts = StorageProvider.shared.getContacts(selectedGroup.uuid)
            
            API.shared.getContactsInfo(group: selectedGroup.uuid) { (result, group, error) in
                if let contacts = result,
                    oldCTag != group?.cTag {
                    DispatchQueue.main.async {
                        API.shared.getContacts(contacts: contacts, group: selectedGroup, completionHandler: { (result, error) in
                            DispatchQueue.main.async {
                                if let contacts = result {
                                    StorageProvider.shared.deleteAllContacts()
                                    StorageProvider.shared.saveContacts(contacts: contacts)
                                    
                                    //                            if let group = group {
                                    //                                StorageProvider.shared.saveContactsGroups(groups: [group])
                                    //                            }
                                    
                                    self.contacts = StorageProvider.shared.getContacts(selectedGroup.uuid)
                                }
                                
                                self.refreshControl.endRefreshing()
                            }
                        })
                    }
                } else {
                    DispatchQueue.main.async {
                        self.refreshControl.endRefreshing()
                    }
                }
            }
        }
    }
    
    func setupSearchBar() {
        searchBar.showsCancelButton = true
        searchBar.delegate = self
        searchBar.isTranslucent = true
        searchBar.barStyle = .black
        searchBar.enablesReturnKeyAutomatically = false
        
        let textField = searchBar.value(forKey: "searchField") as? UITextField
        textField?.textColor = .white
        textField?.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("Search", comment: ""), attributes: [NSAttributedString.Key.foregroundColor: UIColor(white: 1.0, alpha: 0.8)])
        
        let imageView = textField?.leftView as! UIImageView
        imageView.image = imageView.image?.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
        imageView.tintColor = .white
    }
    
    
    // MARK: - Button Actions
    
    @IBAction func searchButtonAction(_ sender: Any) {
        UIView.transition(with: navigationController!.navigationBar, duration: 0.1, options: .transitionCrossDissolve, animations: {
            self.navigationItem.rightBarButtonItems = nil
            self.navigationItem.leftBarButtonItem = nil
            self.navigationItem.titleView = self.searchBar
            self.navigationItem.hidesBackButton = true
        }, completion: { (completed) in
            if completed {
                self.searchBar.becomeFirstResponder()
            }
        })
    }
    
    @IBAction func addButtonAction(_ sender: Any) {
        if isSelection {
            var oldEmails = ComposeMailModelController.shared.mail.cc
            
            if selectionStyle == .to {
                oldEmails = ComposeMailModelController.shared.mail.to
            } else if selectionStyle == .bcc {
                oldEmails = ComposeMailModelController.shared.mail.bcc
            }
            
            var emails: [String] = oldEmails ?? []
            
            for contact in selectedCells {
                if let email = contact.viewEmail {
                    if !emails.contains(email) {
                        emails.append(email)
                    }
                }
            }
            
            if selectionStyle == .cc {
                ComposeMailModelController.shared.mail.cc = emails
            } else if selectionStyle == .to {
                ComposeMailModelController.shared.mail.to = emails
            } else if selectionStyle == .bcc {
                ComposeMailModelController.shared.mail.bcc = emails
            }
            
            navigationController?.popViewController(animated: true)
            dismiss(animated: true, completion: nil)
        } else {
            ContactsModelController.shared.contact = APIContact()
            performSegue(withIdentifier: "AddContactSegue", sender: nil)
        }
    }
    
    @IBAction func menuButtonAction(_ sender: Any) {
        let actionSheet = UIAlertController.init(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let mailButton = UIAlertAction.init(title: NSLocalizedString("Mails", comment: ""), style: .default) { (alert: UIAlertAction!) in
            self.dismiss(animated: false, completion: nil)
            self.navigationController?.popViewController(animated: false)
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
        actionSheet.addAction(settingsButton)
        actionSheet.addAction(logOutButton)
        actionSheet.addAction(cancelButton)
        
        present(actionSheet, animated: true, completion: nil)
    }
    
    @IBAction func showGroupsButtonAction(_ sender: Any) {
        present(SideMenuManager.default.menuLeftNavigationController!, animated: true, completion: nil)
    }
    
    @IBAction func showGroupButtonAction(_ sender: Any) {
        performSegue(withIdentifier: "ShowGroup", sender: nil)
    }
    
    @IBAction func addContactButtonAction(_ sender: Any) {
        self.performSegue(withIdentifier: "AddContactSegue", sender: nil)
    }
    
    @IBAction func addGroupButtonAction(_ sender: Any) {
        GroupsModelController.shared.group = ContactsGroupDB()
        performSegue(withIdentifier: "EditGroup", sender: nil)
    }
    
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "AddContactSegue" {
            ContactsModelController.shared.contact = APIContact()
            
            let vc = segue.destination as! ContactDetailsViewController
            vc.isAdding = true
        }
        
        if segue.identifier == "ShowGroup" {
            let vc = segue.destination as! GroupDetailsViewController
            GroupsModelController.shared.group = GroupsModelController.shared.selectedItem
            vc.inEditingMode = false
            
        }
    }

}


extension ContactsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contacts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ContactTableViewCell.cellID(), for: indexPath) as! ContactTableViewCell
        cell.contact = contacts[indexPath.row]
        cell.switch.isHidden = !isSelection || !(cell.contact?.viewEmail?.count ?? 0 > 0)
        
        let isSelected = selectedCells.contains { (item) -> Bool in
            return cell.contact?.viewEmail == item.viewEmail
        }
        
        cell.switch.isOn = isSelected
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isSelection {
            let contact = contacts[indexPath.row]
            
            if (contact.viewEmail?.count ?? 0 > 0) {
                let isSelected = selectedCells.contains { (item) -> Bool in
                    return contact.viewEmail == item.viewEmail
                }
                
                if isSelected {
                    selectedCells.remove(at: selectedCells.firstIndex(where: { (item) -> Bool in
                        return contact.viewEmail == item.viewEmail
                    })!)
                } else {
                    selectedCells.append(contact)
                }
                
                tableView.reloadData()
            }
        } else {
            ContactsModelController.shared.contact = contacts[indexPath.row]
            performSegue(withIdentifier: "ShowContactSegue", sender: nil)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if refreshControl.isRefreshing {
            refreshControlAction()
        }
    }
}


extension ContactsViewController: UISearchBarDelegate {
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchTimer?.invalidate()
        
        reloadData()
        
        searchBar.resignFirstResponder()
        
        UIView.transition(with: navigationController!.navigationBar, duration: 0.1, options: .transitionCrossDissolve, animations: {
            self.navigationItem.titleView = nil
            
            if self.isSelection {
                
                if self.selectedCells.count > 0 {
                    self.title = NSLocalizedString("Selected: \(self.selectedCells.count)", comment: "")
                } else {
                    self.title = NSLocalizedString("Choose contacts", comment: "")
                }
                
                self.navigationItem.hidesBackButton = false
                self.navigationItem.leftBarButtonItems = nil
                self.navigationItem.rightBarButtonItems = [self.addButton, self.searchButton]
            } else {
                self.navigationItem.hidesBackButton = true
                self.navigationItem.leftBarButtonItem = self.sideMenuAction
                self.navigationItem.rightBarButtonItems = [self.menuButton, self.searchButton]
                
                if GroupsModelController.shared.selectedItem.uuid != "" {
                    self.navigationItem.rightBarButtonItems?.append(self.showGroupButton)
                }
            }
            
            self.shouldUpdateTitle()
        }, completion: nil)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchTimer?.invalidate()
        
        searchTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(makeSearch), userInfo: nil, repeats: false)
    }
    
    @objc func makeSearch() {
        contacts = StorageProvider.shared.getContacts(nil, search: searchBar.text)
        tableView.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchTimer?.invalidate()
        
        if searchBar.text!.count == 0 {
            searchBarCancelButtonClicked(searchBar)
        } else {
            makeSearch()
        }
        
        searchBar.resignFirstResponder()
    }
    
}
