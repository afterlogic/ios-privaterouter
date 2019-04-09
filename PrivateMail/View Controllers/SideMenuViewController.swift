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

extension Notification.Name {
    static let didSelectFolder = Notification.Name("didSelectFolder")
}

class SideMenuViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var emailLabel: UILabel!
    @IBOutlet var avatarImageView: UIImageView!
    @IBOutlet var settingsButton: UIButton!
    
    let refreshControl = UIRefreshControl()
    
    var currentUser: APIUser?
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        avatarImageView.layer.cornerRadius = avatarImageView.frame.size.height / 2.0
        
        setupTableView()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadData), name: .didRecieveUser, object: nil)
        
        let withAction = MenuModelController.shared.folders.count == 0
        
        if withAction {
            if let folders = StorageProvider.shared.getFoldersList() {
                MenuModelController.shared.folders = folders
            }
        }
        
        self.tableView.reloadData()
        selectCurrentFolder(withAction: withAction)
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
    }
    
    @objc func reloadData() {
        refreshControl.beginRefreshing(in: tableView)
        
        API.shared.getFolders(completionHandler: {(result, error) in
            if let folders = result {
                let withAction = MenuModelController.shared.folders.count == 0
                StorageProvider.shared.saveFoldersList(folders: folders)
                
                MenuModelController.shared.folders = folders
                
                API.shared.getFoldersInfo(folders: folders, completionHandler: { (result, error) in
                    if let folders = result {
                        MenuModelController.shared.folders = folders
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
    
    @IBAction func settingsButtonAction(_ sender: Any) {
        var server = "production"
        
        if let test = UserDefaults.standard.object(forKey: "Test") as? Bool {
            UserDefaults.standard.set(!test, forKey: "Test")
            server = !test ? "test" : "production"
        } else {
            UserDefaults.standard.set(true, forKey: "Test")
            server = "test"
        }
        
        let alert = UIAlertController.init(title: NSLocalizedString("Served was changed to \(server)", comment: ""), message: nil, preferredStyle: .alert)
        
        let okButton = UIAlertAction.init(title: NSLocalizedString("Ok", comment: ""), style: .cancel) { (alert: UIAlertAction!) in
        }
        
        alert.addAction(okButton)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    
    // MARK: - Other
    
    func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsSelection = true
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        tableView.register(cellClass: FolderTableViewCell())
        tableView.separatorStyle = .none
        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(self.reloadData), for: .valueChanged)
    }
    
    func selectCurrentFolder(withAction: Bool) {
        let folders = MenuModelController.shared.folders
        if folders.count > 0 {
            var index = 0
            for i in 0..<folders.count {
                if let name = folders[i].name {
                    if name == MenuModelController.shared.selectedFolder {
                        index = i
                        break
                    }
                }
            }
            
            self.tableView.selectRow(at: IndexPath(row: index, section: 0), animated: true, scrollPosition: .top)
            
            if let folder = MenuModelController.shared.selectedFolder {
                StorageProvider.shared.syncFolderIfNeeded(folder: folder)
            }
            
            if withAction {
                self.tableView(tableView, didSelectRowAt: IndexPath(row: index, section: 0))
            }
        }
    }
    
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
    }
    
}


extension SideMenuViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return MenuModelController.shared.folders.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50.0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FolderTableViewCell.cellID(), for: indexPath) as! FolderTableViewCell
        
        cell.titleLabel.text = ""
        
        let folder = MenuModelController.shared.folders[indexPath.row]
        
        cell.unreadCount = folder.unreadCount ?? 0
        cell.titleLabel.text = folder.name
        
        cell.selectionStyle = .none
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        MenuModelController.shared.selectedFolder = MenuModelController.shared.folders[indexPath.row].name
        
        if let folder = MenuModelController.shared.selectedFolder {
            StorageProvider.shared.syncFolderIfNeeded(folder: folder)
        }
        
        NotificationCenter.default.post(name: .didSelectFolder, object: nil)
        dismiss(animated: true, completion: nil)
    }
    
}
