//
//  ViewController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import SideMenu
import SVProgressHUD
import RealmSwift

class MainViewController: UIViewController {

    @IBOutlet var tableView: UITableView!
    @IBOutlet var emptyLabel: UILabel!
    @IBOutlet var composeMailButton: UIButton!
    
    @IBOutlet var optionsButton: UIBarButtonItem!
    @IBOutlet var searchButton: UIBarButtonItem!
    @IBOutlet var menuButton: UIBarButtonItem!
    
    var mails: [APIMail] = []
    var selectedMail: APIMail?
    var progressHeader: String? = nil
    
    var loadingNextPage = false
    var lastPage = false
    
    let refreshControl = UIRefreshControl()
    let searchBar = UISearchBar()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Mail", comment: "")
        
        NotificationCenter.default.addObserver(self, selector: #selector(didSelectFolder), name: .didSelectFolder, object: nil)
        
        StorageProvider.shared.delegate = self
        
        setupSideMenu()
        setupTableView()
        setupSearchBar()
        setupComposeMailButton()
        
        reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isToolbarHidden = true
        tableView.reloadData()
    }
    
    
    // MARK: - API
    
    @objc func reloadData() {
        refreshControl.beginRefreshing(in: tableView)
        
        lastPage = false
        loadMails(text: searchBar.text ?? "", folder: MenuModelController.shared.selectedFolder ?? "INBOX", limit: 50, offset: 0)
    }
    
    func loadMails(text: String, folder: String, limit: Int, offset: Int) {        
        if offset > 0 && (loadingNextPage || lastPage) {
            return
        }
        
        loadingNextPage = true
        
        if offset == 0 {
            StorageProvider.shared.getMails(text: text, folder: folder, limit: nil, completionHandler: { (result) in
                self.mails = result
                self.tableView.reloadData()
            })
        }
        
        API.shared.getMailsList(text: text, folder: folder, limit: limit, offset: offset) { (result, error) in
            self.loadingNextPage = false
            
            if error == nil {
                if let result = result {
                    if offset > 0 {
                        if result.count < limit {
                            self.lastPage = true
                        }
                    }
                    
                    for mail in result {
                        if !self.mails.contains(where: { (item) -> Bool in
                            return mail.uid == item.uid
                        }) {
                            self.mails.append(mail)
                        }
                    }
                    
                    self.mails = self.mails.sorted(by: { (a, b) -> Bool in
                        return a.date ?? Date() > b.date ?? Date()
                    })
                }
                
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    
                    self.scrollViewDidScroll(self.tableView)
                }
            }
            
            DispatchQueue.main.async {
                if self.refreshControl.isRefreshing {
                    self.refreshControl.endRefreshing()
                }
            }
        }
    }
    
    @objc func didSelectFolder() {
        DispatchQueue.main.async {
            self.title = MenuModelController.shared.selectedFolder
        }
        
        reloadData()
    }
    
    
    // MARK: - Buttons
    
    @IBAction func composeMailAction(_ sender: Any) {
        performSegue(withIdentifier: "ComposeSegue", sender: nil)
    }
    
    @IBAction func menuButtonAction(_ sender: Any) {
        let actionSheet = UIAlertController.init(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let mailButton = UIAlertAction.init(title: NSLocalizedString("Compose mail", comment: ""), style: .default) { (alert: UIAlertAction!) in
            self.performSegue(withIdentifier: "ComposeSegue", sender: nil)
        }
        
        let contactsButton = UIAlertAction.init(title: NSLocalizedString("Contacts", comment: ""), style: .default) { (alert: UIAlertAction!) in
            self.performSegue(withIdentifier: "ContactsSegue", sender: nil)
        }
        
        let settingsButton = UIAlertAction.init(title: NSLocalizedString("Settings", comment: ""), style: .default) { (alert: UIAlertAction!) in
            self.performSegue(withIdentifier: "SettingsSegue", sender: nil)
        }

        let deleteButton = UIAlertAction.init(title: NSLocalizedString("Clear user cache", comment: ""), style: .default) { (alert: UIAlertAction!) in
            StorageProvider.shared.deleteMailsFor(accountID: API.shared.currentUser.id)
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
        actionSheet.addAction(deleteButton)
        actionSheet.addAction(logOutButton)
        actionSheet.addAction(cancelButton)
        
        present(actionSheet, animated: true, completion: nil)
    }
    
    @IBAction func searchButtonAction(_ sender: Any) {
        UIView.transition(with: navigationController!.navigationBar, duration: 0.1, options: .transitionCrossDissolve, animations: {
            self.navigationItem.rightBarButtonItems = nil
            self.navigationItem.leftBarButtonItem = nil
            self.navigationItem.titleView = self.searchBar
        }, completion: { (completed) in
            if completed {
                self.searchBar.becomeFirstResponder()
            }
        })
    }
    
    
    // MARK: - Other
    
    func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(cellClass: MailTableViewCell())
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        tableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: tableView.frame.size.height - composeMailButton.frame.origin.y, right: 0.0)
        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(reloadData), for: .valueChanged)
        emptyLabel.text = NSLocalizedString("No mails", comment: "")
    }
    
    func setupSideMenu() {
        SideMenuManager.default.menuLeftNavigationController = storyboard?.instantiateViewController(withIdentifier: "LeftMenuNavigationController") as? UISideMenuNavigationController
        SideMenuManager.default.menuFadeStatusBar = false
        SideMenuManager.default.menuPresentMode = .menuSlideIn
        SideMenuManager.default.menuWidth = view.frame.size.width - 40.0
        SideMenuManager.default.menuAnimationFadeStrength = 0.2
        SideMenuManager.default.menuAddPanGestureToPresent(toView: navigationController!.navigationBar)
        SideMenuManager.default.menuAddScreenEdgePanGesturesToPresent(toView: navigationController!.view, forMenu: .left)
    }
    
    func setupComposeMailButton() {
        composeMailButton.layer.masksToBounds = false
        composeMailButton.layer.cornerRadius = composeMailButton.frame.size.height / 2.0
        composeMailButton.layer.shadowRadius = 10.0
        composeMailButton.layer.shadowColor = UIColor.black.cgColor
        composeMailButton.layer.shadowOpacity = 0.3
        composeMailButton.layer.shadowOffset = CGSize(width: 0.0, height: 3.0)
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
    
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "MailSegue" {
            let vc = segue.destination as! MailViewController
            
            if let mail = selectedMail {
                vc.mail = mail
            }
        }
    }
    
}


extension MainViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if mails.count > 0 {
            emptyLabel.isHidden = true
        } else {
            emptyLabel.isHidden = false
        }
        
        return mails.count;
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80.0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MailTableViewCell.cellID(), for: indexPath) as! MailTableViewCell
        cell.mail = mails[indexPath.row]
        
        cell.selectionStyle = .none
        
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedMail = mails[indexPath.row]
        performSegue(withIdentifier: "MailSegue", sender: nil)
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return progressHeader
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if mails.count > 0 {
            if scrollView.contentSize.height - scrollView.contentOffset.y < scrollView.frame.height * 1.5 {
                loadMails(text: searchBar.text ?? "", folder: MenuModelController.shared.selectedFolder ?? "INBOX", limit: 50, offset: mails.count)
            }
        }
    }
}


extension MainViewController: UISearchBarDelegate {
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        
        reloadData()
        
        searchBar.resignFirstResponder()
        
        UIView.transition(with: navigationController!.navigationBar, duration: 0.1, options: .transitionCrossDissolve, animations: {
            self.navigationItem.titleView = nil
            self.navigationItem.rightBarButtonItems = [self.optionsButton, self.searchButton]
            self.navigationItem.leftBarButtonItem = self.menuButton
        }, completion: nil)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        StorageProvider.shared.getMails(text: searchText, folder: MenuModelController.shared.selectedFolder ?? "INBOX", limit: nil, completionHandler: { (result) in
            self.mails = result
            self.tableView.reloadData()
        })
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        
        if searchBar.text!.count == 0 {
            searchBarCancelButtonClicked(searchBar)
        } else {
            reloadData()
        }
        
        searchBar.resignFirstResponder()
    }
}


extension MainViewController: StorageProviderDelegate {
    func updateHeaderWith(progress: String?, folder: String) {
        if MenuModelController.shared.selectedFolder == folder {
            progressHeader = progress
            self.tableView.reloadData()
        }
    }
}
