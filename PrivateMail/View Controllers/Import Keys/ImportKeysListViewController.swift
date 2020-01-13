//
//  ImportKeysListViewController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import DMSOpenPGP

class ImportKeysListViewController: UIViewController {

    @IBOutlet var addSelectedButton: UIButton!
    @IBOutlet var closeButton: UIButton!
    @IBOutlet var tableView: UITableView!
    @IBOutlet var noteLabel: UILabel!
    
    var keyString: String? {
        didSet {
            do {
                
                var keyString = self.keyString ?? ""
                 
                self.keys = []
                         
                           
                var hasKey = true;
                while (hasKey) {
                    var hasPrivateKey = false;
                    var hasPublicKey = false;
                    
                    let range1 = (keyString as NSString).range(of: "-----BEGIN PGP PUBLIC KEY BLOCK-----")
                    let range2 = (keyString as NSString).range(of:  "-----END PGP PUBLIC KEY BLOCK-----")
                    
                    if  range1.length>0 && range2.length>0 {
        
                        let lowerBound = String.Index.init(encodedOffset:range1.location)
                        let upperBound = String.Index.init(encodedOffset: range2.location + range2.length-1)
                        let key: Substring = keyString[lowerBound...upperBound]
                        let keyRing = try DMSPGPKeyRing(armoredKey: String(key)  );
                        print(keyRing.publicKeyRing.armored())
                        keyString = keyString.replacingOccurrences(of: key, with: "")
                        hasPublicKey = true;
                        
                        let newKey = PGPKey()
                        let publicKey = try keyRing.publicKeyRing
                        let armoredPublicKey = publicKey.armored()
                        newKey.isPrivate = false
                        newKey.armoredKey = armoredPublicKey
                       
                        let publicKeyRing = keyRing.publicKeyRing;
                        let userIds = publicKeyRing.getPublicKey()?.getUserIDs()
                        newKey.email =  NSLocalizedString("(email undefined)", comment: "")
                        while (userIds?.hasNext())! {
                            let userId = userIds!.next()
                            print(userId.debugDescription)
                            let regex = try! NSRegularExpression(pattern: "\\([\\w\\W]* <[\\w\\W]*>\\)")
                            var range=regex.firstMatch(
                                in: userId.debugDescription,
                                options: [],
                                range:NSRange(location: 0, length: userId.debugDescription.utf16.count
                                ))?.range
                            if(range==nil){
                                 newKey.email = userId.debugDescription
                            }else{
                                range =  NSRange(location: range!.location+1, length: range!.length-2)
                            
                                newKey.email =  String(userId.debugDescription[Range(range!, in: userId.debugDescription)!])
                            }
                        }
                         
                        
                        if StorageProvider.shared.getPGPKey(newKey.email, isPrivate: newKey.isPrivate) != nil {
                            newKey.accountID = 0
                        }
                        
                        self.keys.append(newKey)
                    
                    }
                    
                    let rangePrivate1 = (keyString as NSString).range(of: "-----BEGIN PGP PRIVATE KEY BLOCK-----")
                    let rangePrivate2 = (keyString as NSString).range(of:  "-----END PGP PRIVATE KEY BLOCK-----")
                                
                    if  rangePrivate1.length>0 && rangePrivate2.length>0 {
         
                         let lowerBound = String.Index.init(encodedOffset:rangePrivate1.location)
                         let upperBound = String.Index.init(encodedOffset: rangePrivate2.location + rangePrivate2.length-1)
                         let key: Substring = keyString[lowerBound...upperBound]
                         let keyRing = try DMSPGPKeyRing(armoredKey: String(key)  );
                         keyString = keyString.replacingOccurrences(of: key, with: "")
                         hasPrivateKey = true;
                        
                        let newKey = PGPKey()
                        let secretKey = try keyRing.secretKeyRing
                        newKey.isPrivate = true
                        newKey.armoredKey = (secretKey?.armored())!
                        
                        let publicKeyRing = keyRing.secretKeyRing;
                        let userIds = publicKeyRing?.getSecretKey()?.getUserIDs()
                        
                        
                        newKey.email =  NSLocalizedString("(email undefined)", comment: "")
                        while (userIds?.hasNext())! {
                            let userId = userIds!.next()
                            print(userId.debugDescription)
                            let regex = try! NSRegularExpression(pattern: "\\([\\w\\W]* <[\\w\\W]*>\\)")
                            var range=regex.firstMatch(
                                in: userId.debugDescription,
                                options: [],
                                range:NSRange(location: 0, length: userId.debugDescription.utf16.count
                                ))?.range
                            if(range==nil){
                                 newKey.email = userId.debugDescription
                            }else{
                                range =  NSRange(location: range!.location+1, length: range!.length-2)
                            
                                newKey.email =  String(userId.debugDescription[Range(range!, in: userId.debugDescription)!])
                            }
                        }
                        
                        if StorageProvider.shared.getPGPKey(newKey.email, isPrivate: newKey.isPrivate) != nil {
                            newKey.accountID = 0
                        }
                        
                        self.keys.append(newKey)
                     
                     }
                    hasKey = hasPrivateKey || hasPublicKey;
                    
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
        view.theme_backgroundColor = .secondarySurface

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
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        if keys.count == 0 {
            let cancel = UIAlertAction(title: NSLocalizedString("Ok", comment: ""), style: .cancel) { (action) in
                self.cancelButtonAction(action)
            }
            
            presentAlertView(Strings.error, message: NSLocalizedString("No keys found", comment: ""), style: .alert, actions: [cancel])
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
