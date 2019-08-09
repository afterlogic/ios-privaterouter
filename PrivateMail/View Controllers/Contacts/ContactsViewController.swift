//
//  ContactsViewController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

class ContactsViewController: UIViewController {

    @IBOutlet var tableView: UITableView!
    
    @IBOutlet var searchButton: UIBarButtonItem!
    @IBOutlet var addButton: UIBarButtonItem!
    
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
    
    var selectedCells: [IndexPath] = [
    ]
    
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
        
        if isSelection {
            title = NSLocalizedString("Choose contacts", comment: "")
        }
        
        setupSearchBar()
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
        refreshControl.beginRefreshing(in: tableView)
        
        contacts = StorageProvider.shared.getContacts()
        let oldCTag = StorageProvider.shared.getContactsGroup()?.cTag ?? -1
        
        API.shared.getContactsInfo { (result, group, error) in
            if let contacts = result,
                oldCTag != group?.cTag {
                API.shared.getContacts(contacts: contacts, completionHandler: { (result, error) in
                    if let contacts = result {
                        DispatchQueue.main.async {
                            StorageProvider.shared.deleteAllContacts()
                            StorageProvider.shared.saveContacts(contacts: contacts)
                            
                            if let group = group {
                                StorageProvider.shared.saveContactsGroup(group: group)
                            }
                            
                            self.contacts = StorageProvider.shared.getContacts()
                        }
                    }
                    
                    DispatchQueue.main.async {
                        self.refreshControl.endRefreshing()
                    }
                })
            } else {
                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
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
            }
            
            var emails: [String] = oldEmails ?? []
            
            for indexPath in selectedCells {
                if let email = contacts[indexPath.row].viewEmail {
                    if !emails.contains(email) {
                        emails.append(email)
                    }
                }
            }
            
            if selectionStyle == .cc {
                ComposeMailModelController.shared.mail.cc = emails
            } else if selectionStyle == .to {
                ComposeMailModelController.shared.mail.to = emails
            }
            
            navigationController?.popViewController(animated: true)
            dismiss(animated: true, completion: nil)
        } else {
            ContactsModelController.shared.contact = APIContact()
            performSegue(withIdentifier: "AddContactSegue", sender: nil)
        }
    }
    
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "AddContactSegue" {
            let vc = segue.destination as! ContactDetailsViewController
            vc.isAdding = true
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
        cell.switch.isHidden = !isSelection
        cell.switch.isOn = selectedCells.contains(indexPath)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isSelection {
            if selectedCells.contains(indexPath) {
                selectedCells.remove(at: selectedCells.firstIndex(of: indexPath)!)
            } else {
                selectedCells.append(indexPath)
            }
            
            tableView.reloadData()
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
            self.navigationItem.rightBarButtonItems = [self.addButton, self.searchButton]
            self.navigationItem.hidesBackButton = false
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
