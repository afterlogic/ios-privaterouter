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

extension Notification.Name {
    static let mainViewControllerShouldRefreshData = Notification.Name("mainViewControllerShouldRefreshData")
}

class MainViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    @IBOutlet var emptyLabel: UILabel!
    @IBOutlet var composeMailButton: UIButton!
    
    @IBOutlet var optionsButton: UIBarButtonItem!
    @IBOutlet var searchButton: UIBarButtonItem!
    @IBOutlet var menuButton: UIBarButtonItem!
    
    var mails: [APIMail] = []
    var selectedMail: APIMail?
    
    var lastPage = false
    
    let refreshControl = UIRefreshControl()
    let searchBar = UISearchBar()
    
    var refreshTimer: Timer?
    var searchTimer: Timer?
    
    @IBOutlet var progressHolder: UIView!
    @IBOutlet var progressLabel: UILabel!
    
    @IBOutlet var progressConstraint: NSLayoutConstraint!
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("Mail", comment: "")
        
        NotificationCenter.default.addObserver(self, selector: #selector(didSelectFolder), name: .didSelectFolder, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshData), name: .mainViewControllerShouldRefreshData, object: nil)
        
        StorageProvider.shared.delegate = self
        
        setupSideMenu()
        setupTableView()
        setupSearchBar()
        setupComposeMailButton()
     
        #if DEBUG
        refreshTimer = Timer.scheduledTimer(timeInterval: 10.0, target: self, selector: #selector(refreshTimerAction), userInfo: nil, repeats: true)
        #else
        refreshTimer = Timer.scheduledTimer(timeInterval: 5.0 * 60.0, target: self, selector: #selector(refreshTimerAction), userInfo: nil, repeats: true)
        #endif
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isToolbarHidden = true
        
        mails = MenuModelController.shared.mailsForFolder(name: title ?? "")
        tableView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    
    // MARK: - API
    
    @objc func refreshTimerAction() {
        reloadData(withSyncing: true, completionHandler: {})
    }
    
    @objc func refreshControlAction() {
        if !tableView.isDragging {
            reloadData(withSyncing: true, completionHandler: {})
        }
    }
    
    func reloadData(withSyncing: Bool, completionHandler: @escaping () -> Void) {
        refreshControl.beginRefreshing(in: tableView)
        
        lastPage = false
        
        let folder = title ?? ""
        
        mails = MenuModelController.shared.mailsForFolder(name: folder)
        
        if searchBar.text?.count == 0 {
            tableView.reloadData()
        }
        
        if withSyncing {
            API.shared.getFoldersInfo(folders: MenuModelController.shared.expandedFolders(folders: MenuModelController.shared.folders), completionHandler: { (result, error) in
                if let folders = result {
                    MenuModelController.shared.updateFolders(newFolders: folders)
                    NotificationCenter.default.post(name: .shouldRefreshFoldersInfo, object: nil)
                }
                
                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                }
            })
        } else {
            loadMails(text: searchBar.text ?? "", folder: folder, limit: nil, offset: nil, completionHandler: {
                completionHandler()
            })
            
            DispatchQueue.main.async {
                self.refreshControl.endRefreshing()
            }
        }
    }
    
    func loadMails(text: String, folder: String, limit: Int?, offset: Int?, completionHandler: @escaping () -> Void) {
        if (offset ?? 0) > 0 && lastPage || StorageProvider.shared.isFetching {
            return
        }
        
        StorageProvider.shared.getMails(text: text, folder: folder, limit: limit, additionalPredicate: nil, completionHandler: { (result) in
            DispatchQueue.main.async {
                if folder == self.title {
                    self.mails = result
                }
                
                MenuModelController.shared.setMailsForFolder(mails: self.mails, folder: folder)
                
                self.lastPage = self.mails.count == StorageProvider.shared.uids[folder]?.count
                
                self.tableView.reloadData()
                self.scrollViewDidScroll(self.tableView)
                
                completionHandler()
            }
        })
    }
    
    @objc func didSelectFolder() {
        if title != MenuModelController.shared.selectedFolder {
            title = MenuModelController.shared.selectedFolder
            
            mails = MenuModelController.shared.mailsForCurrentFolder()
            
            var needsSyncing = true
            
            if let uids = StorageProvider.shared.uids[MenuModelController.shared.selectedFolder] {
                if mails.count == uids.count {
                    needsSyncing = false
                }
            }
            
            tableView.reloadData()
            
            if needsSyncing {
                reloadData(withSyncing: false, completionHandler: {
                    self.reloadData(withSyncing: true, completionHandler: {})
                })
            }
        }
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
            SVProgressHUD.showSuccess(withStatus: NSLocalizedString("Done", comment: ""))
            StorageProvider.shared.deleteMailsFor(accountID: API.shared.currentUser.id)
            StorageProvider.shared.deleteAllFolders {}
            
            self.mails = []
            MenuModelController.shared.folders = []
//            MenuModelController.shared.setMailsForCurrentFolder(mails: self.mails)
            
            self.tableView.reloadData()
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
    
    @IBAction func cancelSyncingButtonAction(_ sender: Any) {
        StorageProvider.shared.stopSyncingCurrentFolder()
        updateHeaderWith(progress: nil, folder: MenuModelController.shared.selectedFolder)
    }
    
    
    // MARK: - Other
    
    func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(cellClass: MailTableViewCell())
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        tableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: tableView.frame.size.height - composeMailButton.frame.origin.y, right: 0.0)
        
        refreshControl.addTarget(self, action: #selector(refreshControlAction), for: .valueChanged)
        
        if #available(iOS 10.0, *) {
            tableView.refreshControl = refreshControl
        } else {
            tableView.addSubview(refreshControl)
        }
        
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
            let vc = segue.destination as! MailPageViewController
            
            if let folder = MenuModelController.shared.currentFolder() {
                vc.folder = folder
            }
            
            if let mail = selectedMail {
                vc.mail = mail
            }
        } else if segue.identifier == "ComposeSegue" {
            ComposeMailModelController.shared.mail = APIMail()
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
        cell.delegate = self
        cell.selectionStyle = .none
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedMail = mails[indexPath.row]
        performSegue(withIdentifier: "MailSegue", sender: nil)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if mails.count > 0 {
            if scrollView.contentSize.height - scrollView.contentOffset.y < scrollView.frame.height * 1.5 {
//                loadMails(text: searchBar.text ?? "", folder: MenuModelController.shared.selectedFolder, limit: 50, offset: mails.count)
            }
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if refreshControl.isRefreshing {
            refreshControlAction()
        }
    }
    
    @objc func refreshData() {
        DispatchQueue.main.async {
            self.mails = MenuModelController.shared.mailsForFolder(name: self.title)
            self.tableView.reloadData()
        }
    }
}


extension MainViewController: UISearchBarDelegate {
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchTimer?.invalidate()
        
        reloadData(withSyncing: false, completionHandler: {})
        
        searchBar.resignFirstResponder()
        
        UIView.transition(with: navigationController!.navigationBar, duration: 0.1, options: .transitionCrossDissolve, animations: {
            self.navigationItem.titleView = nil
            self.navigationItem.rightBarButtonItems = [self.optionsButton, self.searchButton]
            self.navigationItem.leftBarButtonItem = self.menuButton
        }, completion: nil)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchTimer?.invalidate()

        searchTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(makeSearch), userInfo: nil, repeats: false)
    }
    
    @objc func makeSearch() {
        refreshControl.beginRefreshing(in: tableView)

        StorageProvider.shared.getMails(text: searchBar.text ?? "", folder: MenuModelController.shared.selectedFolder, limit: nil, additionalPredicate: nil, completionHandler: { (result) in
            self.mails = result
            self.tableView.reloadData()
            self.refreshControl.endRefreshing()
        })
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchTimer?.invalidate()
        
        if searchBar.text!.count == 0 {
            searchBarCancelButtonClicked(searchBar)
        } else {
            reloadData(withSyncing: false, completionHandler: {})
        }
        
        searchBar.resignFirstResponder()
    }
    
}


extension MainViewController: StorageProviderDelegate {
    func updateHeaderWith(progress: String?, folder: String) {
        DispatchQueue.main.async {
            if MenuModelController.shared.selectedFolder == folder && progress != nil {
                self.progressConstraint.constant = 0
                
                UIView.animate(withDuration: 0.2) {
                    self.view.layoutIfNeeded()
                    self.progressLabel.text = progress
                    self.progressHolder.isHidden = false
                }
            } else {
                self.progressConstraint.constant = -self.progressHolder.frame.size.height
                
                UIView.animate(withDuration: 0.2) {
                    self.view.layoutIfNeeded()
                    self.progressHolder.isHidden = true
                }
            }
            
            if self.mails.count == 0 {
                self.loadMails(text: self.searchBar.text ?? "", folder: folder, limit: 50, offset: 0, completionHandler: {})
            } else {
                self.scrollViewDidScroll(self.tableView)
            }
        }
    }
    
    func updateTableView(mails: [APIMail], folder: String) {
        DispatchQueue.main.async {
            if folder == self.title && self.searchBar.text == "" {
                self.mails = mails
                MenuModelController.shared.setMailsForFolder(mails: mails, folder: folder)
                
                self.tableView.reloadData()
            }
        }
    }
}


extension MainViewController: MailTableViewCellDelegate {
    func updateFlagsInMail(mail: APIMail?) {
        if let mail = mail {
            for i in 0..<mails.count {
                if mails[i].uid == mail.uid {
                    mails[i] = mail
                }
            }
        }
    }
    
}
