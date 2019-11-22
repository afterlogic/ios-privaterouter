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
import SwiftTheme

extension Notification.Name {
    static let mainViewControllerShouldRefreshData = Notification.Name("mainViewControllerShouldRefreshData")
    static let mainViewControllerShouldGoToSelectionMode = Notification.Name("mainViewControllerShouldGoToSelectionMode")
    static let mainViewControllerShouldMakeSearch = Notification.Name("mainViewControllerShouldMakeSearch")
}

class MainViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    @IBOutlet var composeMailButton: UIButton!
    
    @IBOutlet var optionsButton: UIBarButtonItem!
    @IBOutlet var searchButton: UIBarButtonItem!
    @IBOutlet var menuButton: UIBarButtonItem!
    
    var shouldShowMoreButton = true {
        didSet {
            tableView.reloadData()
        }
    }
    
    var showThreads = true
    
    var mails: [APIMail] = [] {
        didSet {
            let foldersWithoutThreading = ["Drafts", "Trash", "Spam"]
            showThreads = true
            
            var shouldShowButton = false
            defer {
                shouldShowMoreButton = shouldShowButton
            }
            
            if let syncingPeriod = SettingsModelController.shared.getValueFor(.syncPeriod) as? Double, syncingPeriod > 0.0
                && (searchBar.text?.count ?? 0 == 0) {
                if let totalCount = MenuModelController.shared.currentFolder()?.messagesCount,
                    totalCount > mails.count {
                    shouldShowButton = true
                }
            }
                
            if searchBar.text?.count ?? 0 > 0 || foldersWithoutThreading.contains(MenuModelController.shared.currentFolder()?.name ?? "") {
                showThreads = false
                return
            }
            
            var threadedList: [APIMail] = []
            
            for i in 0 ..< mails.count {
                var mail = mails[i]
                
                if let threadUID = mail.threadUID {
                    if threadUID == mail.uid {
                        for threadMail in mails {
                            if (threadMail.threadUID == threadUID) && (threadUID != threadMail.uid) {
                                mail.thread.append(threadMail)
                            }
                        }
                        
                        mail.thread.sort { (a, b) -> Bool in
                            return a.date?.timeIntervalSince1970 ?? 0.0 > b.date?.timeIntervalSince1970 ?? 0.0
                        }
                        
                        threadedList.append(mail)
                    }
                } else {
                    threadedList.append(mail)
                }
            }
            
            threadedList.sort { (a, b) -> Bool in
                return a.date?.timeIntervalSince1970 ?? 0.0 > b.date?.timeIntervalSince1970 ?? 0.0
            }
    
            if case .custom(.starred) = MenuModelController.shared.selectedMenuItem {
                self.mails = threadedList
                    .filter { $0.isFlagged ?? false }
            } else {
                self.mails = threadedList
            }
        }
    }
    
    var selectedMail: APIMail?
    var selectedFolder = "Mail"
    var lastSelectedMenuItem: MenuItem?
    
    var unfoldedThreads: [Int] = []
    
    var lastPage = false
    var isSelection = false {
        didSet {
            selectedCells = []
            tableView.reloadData()
            
            UIView.transition(with: navigationController!.navigationBar, duration: 0.1, options: .transitionCrossDissolve, animations: {
                self.navigationItem.titleView = nil
                
                self.composeMailButton.isHidden = self.isSelection
                
                if !self.isSelection {
                    self.title = self.selectedFolder
                    self.navigationItem.rightBarButtonItems = [self.optionsButton, self.searchButton]
                    self.navigationItem.leftBarButtonItem = self.menuButton
                    
                    if self.searchBar.text?.count ?? 0 > 0 {
                        self.searchButtonAction(self.searchButton as Any)
                    }
                } else {
                    guard let folder = MenuModelController.shared.currentFolder() else {
                        return
                    }
                    
                    let trashButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(self.trashButtonAction(_:)))
                    
                    let hideSpamFolders = [2, 3]
                    
                    let notASpam = (folder.type ?? -1) == 4
                    let spamButton = UIBarButtonItem(image: UIImage(named: notASpam ? "not_spam" : "spam"), style: .plain, target: self, action: #selector(self.spamButtonAction(_:)))
                    
                    var buttons: [UIBarButtonItem] = []
                    
                    if (folder.type ?? -1) != 5 {
                        buttons.append(trashButton)
                    }
                    
                    if !hideSpamFolders.contains(folder.type ?? -1) {
                        buttons.append(spamButton)
                    }
                    
                    self.navigationItem.rightBarButtonItems = buttons
                    
                    let cancelSelectionButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(self.cancelSelectionButtonAction(_:)))
                    self.navigationItem.leftBarButtonItem = cancelSelectionButton
                }
                
            }, completion: nil)
        }
    }
    
    var selectedCells: [IndexPath] = [] {
        didSet {
            if isSelection {
                title = String(format: NSLocalizedString("Selected: %d", comment: ""), selectedCells.count)
            }
        }
    }
    
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
        view.theme_backgroundColor = .surface
        tableView.theme_separatorColor = .onSurfaceSeparator
        composeMailButton.theme_backgroundColor = .accent
        composeMailButton.theme_tintColor = .onAccent
        
        title = NSLocalizedString("Mail", comment: "")
        
        NotificationCenter.default.addObserver(self, selector: #selector(didSelectFolder), name: .didSelectFolder, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshData), name: .mainViewControllerShouldRefreshData, object: nil)
        NotificationCenter.default.addObserver(forName: .mainViewControllerShouldGoToSelectionMode, object: nil, queue: .main) { (notification) in
            self.isSelection = true
        }
        
        NotificationCenter.default.addObserver(forName: .mainViewControllerShouldMakeSearch, object: nil, queue: .main) { (notification) in
            self.searchButtonAction(self)
            self.searchBar.text = notification.object as? String
            self.searchBarSearchButtonClicked(self.searchBar)
        }
        
        StorageProvider.shared.delegate = self
        
        setupSideMenu()
        setupTableView()
        setupSearchBar()
        setupComposeMailButton()
     
        refreshTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(refreshTimerAction), userInfo: nil, repeats: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isToolbarHidden = true
        
        SettingsModelController.shared.currentSyncingPeriodMultiplier = 1.0
        mails = MenuModelController.shared.mailsForFolder(name: selectedFolder)
        tableView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let sideVC = (storyboard?.instantiateViewController(withIdentifier: "SideMenuViewController"))!
        SideMenuManager.default.menuLeftNavigationController = UISideMenuNavigationController(rootViewController: sideVC)
    }
    
    
    // MARK: - API
    
    @objc func refreshTimerAction() {
        let refreshTime = (SettingsModelController.shared.getValueFor(.syncFrequency) as? Int) ?? -1
        
        if refreshTime > 0 {
            let lastRefreshDate = (SettingsModelController.shared.getValueFor(.lastRefresh) as? Date) ?? Date(timeIntervalSince1970: 0.0)
            
            #if DEBUG
                let timeInterval = TimeInterval(refreshTime * 5)
            #else
                let timeInterval = TimeInterval(refreshTime * 60)
            #endif
            
            if Date().timeIntervalSince(lastRefreshDate) >= timeInterval {
                SettingsModelController.shared.setValue(Date(), for: .lastRefresh)
                reloadData(withSyncing: true, completionHandler: {})
            }
        }
    }
    
    @objc func refreshControlAction() {
        if !tableView.isDragging {
            SettingsModelController.shared.currentSyncingPeriodMultiplier = 1.0
            MenuModelController.shared.updateFolder(folder: selectedFolder, hash: "")
            reloadData(withSyncing: true, completionHandler: {})
        }
    }
    
    func reloadData(withSyncing: Bool, showRefreshControl: Bool = true, completionHandler: @escaping () -> Void) {
        if isSelection {
            refreshControl.endRefreshing()
            return
        }
        
        if showRefreshControl {
            refreshControl.beginRefreshing(in: tableView)
        }
        
        lastPage = false
        
        let folder = selectedFolder
        mails = MenuModelController.shared.mailsForFolder(name: folder)
        
        if searchBar.text?.count == 0 {
            tableView.reloadData()
        }
        
        if withSyncing {
            API.shared.getFoldersInfo(folders: MenuModelController.shared.expandedFolders(folders: MenuModelController.shared.folders), completionHandler: { (result, error) in
                DispatchQueue.main.async {
                    if showRefreshControl {
                        self.refreshControl.endRefreshing()
                    }
                    
                    if let error = error {
                        SVProgressHUD.showError(withStatus: error.localizedDescription)
                        return
                    }
    
                    if let folders = result {
                        MenuModelController.shared.updateFolders(newFolders: folders)
                        NotificationCenter.default.post(name: .shouldRefreshFoldersInfo, object: nil)
                    }
                }
            })
        } else {
            loadMails(text: searchBar.text ?? "", folder: folder, limit: nil, offset: nil, completionHandler: {
                completionHandler()
            })
            
            if showRefreshControl {
                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                }
            }
        }
    }
    
    func loadMails(text: String, folder: String, limit: Int?, offset: Int?, completionHandler: @escaping () -> Void) {
        if (offset ?? 0) > 0 && lastPage || StorageProvider.shared.isFetching {
            return
        }
        
        StorageProvider.shared.getMails(text: text, folder: folder, limit: limit, additionalPredicate: nil, completionHandler: { (result) in
            DispatchQueue.main.async {
                if folder == self.selectedFolder {
                    self.mails = result
                }
                
                MenuModelController.shared.setMailsForFolder(mails: result, folder: folder)
                
                self.lastPage = self.mails.count == StorageProvider.shared.uids[folder]?.count
                
                self.tableView.reloadData()
                self.scrollViewDidScroll(self.tableView)
                
                completionHandler()
            }
        })
    }
    
    @objc func didSelectFolder() {
        isSelection = false
        
        let selectedMenuItem = MenuModelController.shared.selectedMenuItem
        
        guard lastSelectedMenuItem != selectedMenuItem else {
            return
        }
        lastSelectedMenuItem = selectedMenuItem
        
        switch selectedMenuItem {
        case .custom(.starred):
            title = Strings.starred
        case .folder(let fullName):
            title = fullName
        }
        
        if selectedFolder != MenuModelController.shared.selectedFolder {
            SettingsModelController.shared.currentSyncingPeriodMultiplier = 1.0
            
            selectedFolder = MenuModelController.shared.selectedFolder
            
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
            DispatchQueue.main.async {
                SVProgressHUD.showSuccess(withStatus: NSLocalizedString("Done", comment: ""))
                StorageProvider.shared.deleteMailsFor(accountID: API.shared.currentUser.id)
                StorageProvider.shared.deleteAllFolders {}
                StorageProvider.shared.deleteAllContacts()
                
                self.mails = []
                MenuModelController.shared.folders = []
                //            MenuModelController.shared.setMailsForCurrentFolder(mails: self.mails)
                
                self.tableView.reloadData()
            }
        }
        
        let logOutButton = UIAlertAction.init(title: NSLocalizedString("Log Out", comment: ""), style: .default) { (alert: UIAlertAction!) in
            SVProgressHUD.show()
            
            API.shared.logout(completionHandler: { (result, error) in
                SVProgressHUD.dismiss()
                
                if let error = error {
                    SVProgressHUD.showError(withStatus: error.localizedDescription)
                } else {
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
    
    @objc func cancelSelectionButtonAction(_ sender: Any) {
        isSelection = false
    }
    
    @objc func trashButtonAction(_ sender: Any) {
        guard let folder = MenuModelController.shared.currentFolder() else {
            return
        }
        
        let moveToTrash = (folder.type ?? -1) != 5
        
        let alert = UIAlertController.init(title: NSLocalizedString(moveToTrash ? "Move this messages to trash?" : "Delete this messages?", comment: ""), message: nil, preferredStyle: .alert)
        
        let yesButton = UIAlertAction.init(title: NSLocalizedString("Yes", comment: ""), style: .destructive) { (alert: UIAlertAction!) in
            SVProgressHUD.show()
            
            var mails: [APIMail] = []
            
            for item in self.selectedCells {
                var mail = self.mails[item.section]
                
                if item.row > 0 {
                    if item.row < mail.thread.count {
                        mail = mail.thread[item.row]
                    } else {
                        continue
                    }
                }
                
                mails.append(mail)
            }
            
            if moveToTrash {
                API.shared.moveMessages(mails: mails, toFolder: "Trash") { (result, error) in
                    DispatchQueue.main.async {
                        SVProgressHUD.dismiss()
                        
                        if let success = result {
                            if success {
                                for mail in mails {
                                    StorageProvider.shared.deleteMail(mail: mail)
                                    MenuModelController.shared.removeMail(mail: mail)
                                }
                                
                                self.mails = MenuModelController.shared.mailsForCurrentFolder()
                                self.isSelection = false
                            } else {
                                SVProgressHUD.showError(withStatus: Strings.cantCompleteAction)
                            }
                        } else {
                            if let error = error {
                                SVProgressHUD.showError(withStatus: error.localizedDescription)
                            }
                        }
                        
                        self.selectedCells = []
                        self.tableView.reloadData()
                    }
                }
            } else {
                API.shared.deleteMessages(mails: mails) { (result, error) in
                    DispatchQueue.main.async {
                        SVProgressHUD.dismiss()
                        
                        if let success = result {
                            if success {
                                for mail in mails {
                                    StorageProvider.shared.deleteMail(mail: mail)
                                    MenuModelController.shared.removeMail(mail: mail)
                                }
                                
                                self.mails = MenuModelController.shared.mailsForCurrentFolder()
                                self.isSelection = false
                            } else {
                                SVProgressHUD.showError(withStatus: Strings.cantDeleteMessage)
                            }
                            
                        } else {
                            if let error = error {
                                SVProgressHUD.showError(withStatus: error.localizedDescription)
                            }
                        }
                    }
                    
                    self.selectedCells = []
                    self.tableView.reloadData()
                }
            }
        }
        
        let cancelButton = UIAlertAction.init(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { (alert: UIAlertAction!) in
        }
        
        alert.addAction(cancelButton)
        alert.addAction(yesButton)
        
        present(alert, animated: true, completion: nil)
    }

    @objc func spamButtonAction(_ sender: Any) {
        let markAsSpam = selectedFolder != "Spam"
        
        let alert = UIAlertController.init(title: NSLocalizedString(markAsSpam ? "Mark this messages as spam?" :  "Mark this messages as not spam?", comment: ""), message: nil, preferredStyle: .alert)
        
        var mails: [APIMail] = []
        
        for item in self.selectedCells {
            var mail = self.mails[item.section]
            
            if item.row > 0 {
                if item.row < mail.thread.count {
                    mail = mail.thread[item.row]
                } else {
                    continue
                }
            }
            
            mails.append(mail)
        }
        
        let yesButton = UIAlertAction.init(title: NSLocalizedString("Yes", comment: ""), style: .destructive) { (alert: UIAlertAction!) in
            SVProgressHUD.show()
            
            API.shared.moveMessages(mails: mails, toFolder: markAsSpam ? "Spam" : "Inbox") { (result, error) in
                DispatchQueue.main.async {
                    SVProgressHUD.dismiss()
                    
                    if let success = result {
                        if success {
                            for mail in mails {
                                StorageProvider.shared.deleteMail(mail: mail)
                                MenuModelController.shared.removeMail(mail: mail)
                            }
                            
                            self.mails = MenuModelController.shared.mailsForCurrentFolder()
                            self.isSelection = false
                        } else {
                            SVProgressHUD.showError(withStatus: Strings.cantCompleteAction)
                        }
                    } else {
                        if let error = error {
                            SVProgressHUD.showError(withStatus: error.localizedDescription)
                        }
                    }
                    
                    self.selectedCells = []
                    self.tableView.reloadData()
                }
            }
        }
        
        let cancelButton = UIAlertAction.init(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { (alert: UIAlertAction!) in
        }
        
        alert.addAction(cancelButton)
        alert.addAction(yesButton)
        
        present(alert, animated: true, completion: nil)
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
        textField?.theme_textColor = .onPrimary
        textField?.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("Search", comment: ""), attributes: [NSAttributedString.Key.foregroundColor: UIColor(white: 1.0, alpha: 0.8)])
        
        let imageView = textField?.leftView as! UIImageView
        imageView.image = imageView.image?.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
        imageView.theme_tintColor = .onPrimary
        
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
    func numberOfSections(in tableView: UITableView) -> Int {
        (mails.isEmpty ? 1 : mails.count) + (shouldShowMoreButton ? 1 : 0);
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 && mails.isEmpty || section == tableView.numberOfSections - 1 && shouldShowMoreButton {
            return 1
        } else if unfoldedThreads.contains(mails[section].threadUID ?? -1) || unfoldedThreads.contains(-999) {
            return mails[section].thread.count + 1;
        } else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == tableView.numberOfSections - 1 && shouldShowMoreButton {
            return 44.0
        } else {
            return 80.0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 && mails.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: "NoMessagesCell")!
            return cell
        }
        
        if indexPath.section == tableView.numberOfSections - 1 && shouldShowMoreButton {
            let cell = tableView.dequeueReusableCell(withIdentifier: "MoreMessagesCell")!
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: MailTableViewCell.cellID(), for: indexPath) as! MailTableViewCell
        
        var mail = mails[indexPath.section]
        
        if indexPath.row > 0 {
            mail = mail.thread[indexPath.row - 1]
        }
        
        cell.showThreading = showThreads
        cell.mail = mail
        cell.delegate = self
        cell.isSelection = isSelection
        
        cell.selectionSwitch.isOn = selectedCells.contains(indexPath)
        
        cell.selectionStyle = .none
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == tableView.numberOfSections - 1 && shouldShowMoreButton {
            SettingsModelController.shared.currentSyncingPeriodMultiplier += 1.0
            reloadData(withSyncing: true, showRefreshControl: false, completionHandler: {})
            return
        }
        
        if isSelection {
            if selectedCells.contains(indexPath) {
                selectedCells.remove(at: selectedCells.firstIndex(of: indexPath)!)
            } else {
                selectedCells.append(indexPath)
            }
            
            tableView.reloadData()
        } else {
            if indexPath.row > 0 {
                selectedMail = mails[indexPath.section].thread[indexPath.row - 1]
            } else {
                selectedMail = mails[indexPath.section]
            }
            
            var mailsToUpdate = MenuModelController.shared.mailsForFolder(name: selectedFolder)
            
            for index in 0 ..< mailsToUpdate.count {
                if mailsToUpdate[index].uid == selectedMail?.uid {
                    mailsToUpdate[index].isSeen = true
                    break
                }
            }
            
            MenuModelController.shared.setMailsForFolder(mails: mailsToUpdate, folder: selectedFolder)
            
            var shouldReturnSearchBar = false
            
            if navigationItem.titleView != nil {
                shouldReturnSearchBar = true
                navigationItem.titleView = nil
            }
            
            performSegue(withIdentifier: "MailSegue", sender: nil)
            
            if shouldReturnSearchBar {
                navigationItem.titleView = searchBar
            }
        }
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
            self.mails = MenuModelController.shared.mailsForFolder(name: self.selectedFolder)
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
            if folder == self.selectedFolder {
                if self.searchBar.text?.count ?? 0 < 1 {
                    self.mails = mails
                }
                
                MenuModelController.shared.setMailsForFolder(mails: mails, folder: folder)
                
                self.tableView.reloadData()
            }
        }
    }
}


extension MainViewController: MailTableViewCellDelegate {
    func updateFlagsInMail(mail: APIMail?) {
        if let mail = mail {
            for i in 0 ..< mails.count {
                if mails[i].uid == mail.uid {
                    mails[i] = mail
                }
            }
        }
    }
    
    func unfoldThreadWith(id: Int) {
        if unfoldedThreads.contains(id) {
            unfoldedThreads.removeAll { (item) -> Bool in
                return item == id
            }
        } else {
            unfoldedThreads.append(id)
        }
        
        for i in 0 ..< mails.count {
            if mails[i].threadUID == id {
                tableView.reloadSections([i], with: .automatic)
                break
            }
        }
    }
}
