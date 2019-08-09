//
//  ImportKeysListViewController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import ObjectivePGP

class ImportKeysListViewController: UIViewController {

    @IBOutlet var addSelectedButton: UIButton!
    @IBOutlet var closeButton: UIButton!
    @IBOutlet var tableView: UITableView!
    @IBOutlet var noteLabel: UILabel!
    
    var keyString: String? {
        didSet {
            do {
                let keyString = self.keyString ?? ""
                let keys = try ObjectivePGP.readKeys(from: keyString.data(using: .utf8)!)
                self.keys = []
                
                for key in keys {
                    if key.isPublic {
                        let newKey = PGPKey()
                        let publicKey = try key.export(keyType: .public)
                        let armoredPublicKey = Armor.armored(publicKey, as: .publicKey)
                        newKey.isPrivate = false
                        newKey.armoredKey = armoredPublicKey
                        newKey.email = key.publicKey?.primaryUser?.userID ?? NSLocalizedString("(email undefined)", comment: "")
                        
                        if StorageProvider.shared.getPGPKey(newKey.email, isPrivate: newKey.isPrivate) != nil {
                            newKey.accountID = 0
                        }
                        
                        self.keys.append(newKey)
                    }
                    
                    if key.isSecret {
                        let newKey = PGPKey()
                        let secretKey = try key.export(keyType: .secret)
                        let armoredPrivateKey = Armor.armored(secretKey, as: .secretKey)
                        newKey.isPrivate = true
                        newKey.armoredKey = armoredPrivateKey
                        newKey.email = key.secretKey?.primaryUser?.userID ?? NSLocalizedString("(email undefined)", comment: "")
                        
                        if StorageProvider.shared.getPGPKey(newKey.email, isPrivate: newKey.isPrivate) != nil {
                            newKey.accountID = 0
                        }
                        
                        self.keys.append(newKey)
                    }
                }
            } catch {
                
            }
        }
    }
    
    var keys: [PGPKey] = []
    var selectedIndexPaths: [IndexPath] = [] {
        didSet {
            self.addSelectedButton.isEnabled = self.selectedIndexPaths.count > 0
            self.addSelectedButton.alpha = self.addSelectedButton.isEnabled ? 1.0 : 0.5
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isToolbarHidden = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Import keys", comment: "")
        addSelectedButton.setTitle(NSLocalizedString("IMPORT SELECTED KEYS", comment: ""), for: .normal)
        closeButton.setTitle(NSLocalizedString("CANCEL", comment: ""), for: .normal)
        noteLabel.text = NSLocalizedString("Keys which are already in the system are greyed out.", comment: "")
        
        selectedIndexPaths = []
        
        addSelectedButton.layer.cornerRadius = addSelectedButton.bounds.height / 2.0
        closeButton.layer.cornerRadius = closeButton.bounds.height / 2.0
        tableView.layer.cornerRadius = 10.0
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(cellClass: KeyImportTableViewCell())
        tableView.tableFooterView = UIView(frame: .zero)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        if keys.count == 0 {
            let cancel = UIAlertAction(title: NSLocalizedString("Ok", comment: ""), style: .cancel) { (action) in
                self.cancelButtonAction(action)
            }
            
            presentAlertView(NSLocalizedString("Error", comment: ""), message: NSLocalizedString("No keys found", comment: ""), style: .alert, actions: [cancel])
        }
    }
    
    @IBAction func importKeysButtonAction(_ sender: Any) {
        for indexPath in selectedIndexPaths {
            let key = keys[indexPath.row]
            StorageProvider.shared.savePGPKey(key.email, isPrivate: key.isPrivate, armoredKey: key.armoredKey)
        }
        
        cancelButtonAction(sender)
    }
    
    @IBAction func cancelButtonAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
}


extension ImportKeysListViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return keys.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: KeyImportTableViewCell.cellID(), for: indexPath) as! KeyImportTableViewCell
        cell.emailLabel.text = keys[indexPath.row].email
        cell.descriptionLabel.text =  "(2048-bit, \(keys[indexPath.row].isPrivate ? "private" : "public"))"
        
        cell.switch.isOn = selectedIndexPaths.contains(indexPath)
        
        if keys[indexPath.row].accountID == 0 {
            cell.contentView.alpha = 0.5
        } else {
            cell.contentView.alpha = 1.0
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if keys[indexPath.row].accountID != 0 {
            if selectedIndexPaths.contains(indexPath) {
                selectedIndexPaths.removeAll { (item) -> Bool in
                    return item == indexPath
                }
            } else {
                selectedIndexPaths.append(indexPath)
            }
        }
            
        tableView.reloadData()
    }
}
