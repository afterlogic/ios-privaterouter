//
//  SideMenuViewController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import SDWebImage
import SideMenu
import SwiftTheme

extension Notification.Name {
    static let didSelectFolder = Notification.Name("didSelectFolder")
    static let shouldRefreshFoldersInfo = Notification.Name("didRecieveUpdatedFoldersInfo")
}

class SideMenuViewController: UIViewController {
    
    @IBOutlet weak var topBarContainer: UIView!
    @IBOutlet var tableView: UITableView!
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var emailLabel: UILabel!
    @IBOutlet var avatarImageView: UIImageView!
    
    let refreshControl = UIRefreshControl()
    
    var currentUser: APIUser?
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.theme_backgroundColor = .surface
        topBarContainer.theme_backgroundColor = .primary
        nameLabel.theme_textColor = .onPrimary
        emailLabel.theme_textColor = .onPrimary
        
        avatarImageView.layer.cornerRadius = avatarImageView.frame.size.height / 2.0
        
        navigationController?.isNavigationBarHidden = true
        
        setupTableView()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadData), name: .didRecieveUser, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadTableView), name: .shouldRefreshFoldersInfo, object: nil)
        
        let shouldLoadFromCache = MenuModelController.shared.folders.count == 0
        
        if shouldLoadFromCache {
            StorageProvider.shared.getFolders(completionHandler: { (result) in
                MenuModelController.shared.folders = MenuModelController.shared.compressedFolders(folders: result)
                
                self.tableView.reloadData()
                self.selectCurrentFolder(withAction: shouldLoadFromCache)
            })
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        currentUser = API.shared.currentUser
        nameLabel.text = (currentUser?.firstName ?? "") + " " + (currentUser?.lastName ?? "")
        
        if nameLabel.text?.count == 1 {
            nameLabel.text = "No Name"
        }
        
        emailLabel.text = currentUser?.email
        avatarImageView.sd_setImage(with: API.shared.currentUser.profileImageURL, placeholderImage: UIImage(named: "avatar_placeholder"))
        
        tableView.reloadData()
    }
    
    @objc func refreshControlAction() {
        if !tableView.isDragging {
            reloadData()
        }
    }
    
    @objc func reloadTableView() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    @objc func reloadData() {
        refreshControl.beginRefreshing(in: tableView)
        
        API.shared.getFolders(completionHandler: {(result, error) in
            if let folders = result {
                let withAction = MenuModelController.shared.folders.count == 0
                MenuModelController.shared.updateFolders(newFolders: folders)
                
                API.shared.getFoldersInfo(folders: MenuModelController.shared.expandedFolders(folders: folders), completionHandler: { (result, error) in
                    if let foldersWithHash = result {
                        var folderWithoutHash: [APIFolder] = []
                        
                        for folder in foldersWithHash {
                            var newFolder = folder
                            newFolder.hash = nil
                            folderWithoutHash.append(newFolder)
                        }
                        
                        MenuModelController.shared.updateFolders(newFolders: folderWithoutHash)
                        let expandedFolders = MenuModelController.shared.expandedFolders(folders: MenuModelController.shared.folders)
                        StorageProvider.shared.saveFolders(folders: expandedFolders)
                        
                        DispatchQueue.main.async {
                            self.tableView.reloadData()
                            self.selectCurrentFolder(withAction: withAction)
                        }
                    }
                })
                
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    self.selectCurrentFolder(withAction: withAction)
                }
            }
            
            DispatchQueue.main.async {
                self.refreshControl.endRefreshing()
            }
        })
    }
    
    
    // MARK: - Buttons
    
    
    // MARK: - Other
    
    func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsSelection = true
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        tableView.register(cellClass: FolderTableViewCell.self)
        tableView.separatorStyle = .none

        refreshControl.addTarget(self, action: #selector(refreshControlAction), for: .valueChanged)
        
        if #available(iOS 10.0, *) {
            tableView.refreshControl = refreshControl
        } else {
            tableView.addSubview(refreshControl)
        }

    }
    
    func selectCurrentFolder(withAction: Bool) {
        guard
            let selectedIndex = getSelectedItemIndex()
            else { return }
        
        let indexPath = IndexPath(row: selectedIndex, section: 0)
    
        self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .top)
    
        if withAction {
            self.tableView(tableView, didSelectRowAt: indexPath)
        }
    }
    
    private func getSelectedItemIndex() -> Int? {
        MenuModelController.shared.menuItems()
            .firstIndex(where: {
                $0 == MenuModelController.shared.selectedMenuItem
            })
    }
    
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
    }
    
}


extension SideMenuViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return MenuModelController.shared.menuItems().count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50.0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FolderTableViewCell.cellID(), for: indexPath) as! FolderTableViewCell
        
        cell.titleLabel.text = ""
        cell.selectionStyle = .none
        
        let item = MenuModelController.shared.menuItems()[indexPath.row]
        
        defer {
            cell.setSelected(item == MenuModelController.shared.selectedMenuItem)
        }
        
        switch item {
        case .custom(.starred):
            cell.subFoldersCount = 0
            cell.unreadCount = 0
            cell.sideConstraint.constant = 15.0
            cell.titleLabel.text = Strings.starred
            cell.iconImageView.image = nil
            cell.iconImageView.image = UIImage(named: "folder_starred")?.withRenderingMode(.alwaysTemplate)
            cell.theme_iconTintColor = .accentFavorite
            return cell
            
        case .folder(let folderName):
            guard let folder = MenuModelController.shared.folder(byFullName: folderName) else {
                return cell
            }
    
            cell.folder = folder
            cell.theme_iconTintColor = .onSurfaceMajorText
    
            if folder.type == 3 {
                cell.unreadCount = folder.messagesCount ?? 0
            } else {
                cell.unreadCount = folder.unreadCount ?? 0
            }
    
            cell.subFoldersCount = 0 //folder.subFoldersCount ?? 0
            cell.titleLabel.text = folder.name
    
            cell.sideConstraint.constant = 15.0 * CGFloat(folder.depth + 1)
    
            switch folder.type {
            case 1:
                cell.iconImageView.image = UIImage(named: "folder_inbox")
    
            case 2:
                cell.iconImageView.image = UIImage(named: "folder_sent")
    
            case 3:
                cell.iconImageView.image = UIImage(named: "folder_drafts")
    
            case 4:
                cell.iconImageView.image = UIImage(named: "folder_spam")
    
            case 5:
                cell.iconImageView.image = UIImage(named: "folder_trash")
    
            default:
                cell.iconImageView.image = nil //UIImage(named: "folder_default")
            }
    
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = MenuModelController.shared.menuItems()[indexPath.row]
    
        MenuModelController.shared.selectedMenuItem = item
        
        switch item {
        case .folder(let folderName):
            if let folder = MenuModelController.shared.folder(byFullName: folderName),
               folder.isSelectable ?? true {
                
                let systemFolders = ["INBOX", "Sent", "Drafts"]
        
                if !systemFolders.contains(MenuModelController.shared.selectedFolder) {
                    StorageProvider.shared.stopSyncingFolder(MenuModelController.shared.selectedFolder)
                }
            }
            
        default: break
        }
    
        NotificationCenter.default.post(name: .didSelectFolder, object: nil)
        tableView.reloadData()
        dismiss(animated: true, completion: nil)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if refreshControl.isRefreshing {
            reloadData()
        }
    }
    
}
