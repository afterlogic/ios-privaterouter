//
//  PGPSettingsViewController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import ObjectivePGP
import KeychainAccess
import SVProgressHUD

class PGPSettingsViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!

    var publicKeys: [PGPKey] = []
    var privateKeys: [PGPKey] = []
    
    var selectedKey: PGPKey?
    
    var buttons = [
        NSLocalizedString("EXPORT ALL PUBLIC KEYS", comment: ""),
        NSLocalizedString("IMPORT KEYS FROM TEXT", comment: ""),
        NSLocalizedString("IMPORT KEYS FROM FILE", comment: ""),
        NSLocalizedString("GENERATE KEYS", comment: ""),
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("OpenPGP", comment: "")
   
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(cellClass: SettingsTableViewCell())
        tableView.register(cellClass: SettingsButtonTableViewCell())
        tableView.tableFooterView = UIView(frame: .zero)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        publicKeys = StorageProvider.shared.getPGPKeys(false)
        privateKeys = StorageProvider.shared.getPGPKeys(true)
        tableView.reloadData()
    }
    
    func generateKeys() {
        for key in publicKeys + privateKeys {
            if key.email == API.shared.currentUser.email {
                presentAlertView(NSLocalizedString("Error", comment: ""), message: NSLocalizedString("Already have keys for this email", comment: ""), style: .alert, actions: [], addCancelButton: true)
                return
            }
        }
        
        let alert = UIAlertController(title: NSLocalizedString("Enter password", comment: ""), message: nil, preferredStyle: .alert)
        
        alert.addTextField { (textField) in
            textField.placeholder = NSLocalizedString("Enter password", comment: "")
            textField.isSecureTextEntry = true
        }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Ok", comment: ""), style: .default, handler: { [weak alert] (_) in
            let textField = alert?.textFields![0]
            
            if let password = textField?.text {
                SVProgressHUD.show()
                
                #if !targetEnvironment(simulator)
                self.view.isUserInteractionEnabled = false
                
                if var email = API.shared.currentUser.email {
                    email = "<\(email)>"
                    
                    DispatchQueue.global(qos: .userInitiated).async {
                        let generator = KeyGenerator()
                        generator.keyBitsLength = 2048
                        
                        let key = generator.generate(for: email, passphrase: password)
                        
                        DispatchQueue.main.async {
                            do {
                                let publicKey = try key.export(keyType: .public)
                                let secretKey = try key.export(keyType: .secret)
                                
                                let armoredPublicKey = Armor.armored(publicKey, as: .publicKey)
                                let armoredPrivateKey = Armor.armored(secretKey, as: .secretKey)

                                StorageProvider.shared.savePGPKey(email, isPrivate: true, armoredKey: armoredPrivateKey)
                                StorageProvider.shared.savePGPKey(email, isPrivate: false, armoredKey: armoredPublicKey)
                                
                                self.publicKeys = StorageProvider.shared.getPGPKeys(false)
                                self.privateKeys = StorageProvider.shared.getPGPKeys(true)
                                
                                self.tableView.reloadData()
                                
                                SVProgressHUD.dismiss()
                            } catch {
                                SVProgressHUD.showError(withStatus: NSLocalizedString("Can't generate keys", comment: ""))
                            }
                            
                            self.view.isUserInteractionEnabled = true
                        }
                    }
                } else {
                    SVProgressHUD.showError(withStatus: NSLocalizedString("Can't generate keys", comment: ""))
                    self.view.isUserInteractionEnabled = true
                }
                #endif
                
            }
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    
    // MARK: Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PreviewSegue" {
            let vc = segue.destination as! PGPKeyPreviewViewController
            vc.key = selectedKey
            vc.showForMultiple = false
        } else if segue.identifier == "MultiplePreviewSegue" {
            let vc = segue.destination as! PGPKeyPreviewViewController
            vc.key = selectedKey
            vc.showForMultiple = true
        } else if segue.identifier == "ImportFromFileSegue" {
            let vc = segue.destination as! ImportKeysListViewController
            vc.keyString = sender as? String
        }
    }
}

extension PGPSettingsViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return publicKeys.count
            
        case 1:
            return privateKeys.count
            
        case 2:
            return buttons.count
            
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section < 2 {
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.cellID(), for: indexPath) as! SettingsTableViewCell
            cell.titleLabel.text = indexPath.section == 0 ? publicKeys[indexPath.row].email : privateKeys[indexPath.row].email
            
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsButtonTableViewCell.cellID(), for: indexPath) as! SettingsButtonTableViewCell
            cell.titleLabel.text = buttons[indexPath.row]
            cell.separatorInset = UIEdgeInsets(top: 0.0, left: tableView.bounds.width, bottom: 0.0, right: 0.0)
            
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return NSLocalizedString("Public keys", comment: "")
        }
        
        if section == 1 {
            return NSLocalizedString("Private keys", comment: "")
        }
        
        return nil
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section < 2 {
            selectedKey = indexPath.section == 0 ? publicKeys[indexPath.row] : privateKeys[indexPath.row]
            performSegue(withIdentifier: "PreviewSegue", sender: nil)
        } else {
            let button = buttons[indexPath.row]
            
            if button == NSLocalizedString("EXPORT ALL PUBLIC KEYS", comment: "") {
                selectedKey = PGPKey()
                
                for key in publicKeys {
                    selectedKey?.armoredKey += key.armoredKey + "\n"
                }

                performSegue(withIdentifier: "MultiplePreviewSegue", sender: nil)
            } else if button == NSLocalizedString("IMPORT KEYS FROM TEXT", comment: "") {
              performSegue(withIdentifier: "ImportFromTextSegue", sender: nil)
            } else if button == NSLocalizedString("GENERATE KEYS", comment: ""){
                generateKeys()
            } else if button == NSLocalizedString("IMPORT KEYS FROM FILE", comment: "") {
                let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
                documentPicker.delegate = self
                documentPicker.modalPresentationStyle = .formSheet
                
                if #available(iOS 11.0, *) {
                    documentPicker.allowsMultipleSelection = false
                }
                
                present(documentPicker, animated: true, completion: nil)
            }
        }
    }
}

extension PGPSettingsViewController: UIDocumentPickerDelegate {
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let keys = String(data: data, encoding: .utf8)
            performSegue(withIdentifier: "ImportFromFileSegue", sender: keys)
        } catch {
            presentAlertView(NSLocalizedString("Error", comment: ""), message: NSLocalizedString("Can't open file", comment: ""), style: .alert, actions: [], addCancelButton: true)
        }
    }
    
    public func documentMenu(_ documentMenu:UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController) {
        documentPicker.delegate = self
        present(documentPicker, animated: true, completion: nil)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        dismiss(animated: true, completion: nil)
    }
}
