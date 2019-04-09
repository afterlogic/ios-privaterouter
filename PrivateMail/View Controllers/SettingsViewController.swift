//
//  SettingsViewController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import ObjectivePGP
import KeychainAccess
import SVProgressHUD

class SettingsViewController: UIViewController {

    @IBOutlet var publicKeyLabel: UILabel!
    @IBOutlet var privateKeyLabel: UILabel!
    @IBOutlet var publicKeyTextView: UITextView!
    @IBOutlet var privateKeyTextView: UITextView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Settings", comment: "")
        
        publicKeyLabel.text = NSLocalizedString("Public key", comment: "")
        privateKeyLabel.text = NSLocalizedString("Private key", comment: "")
    
        let cornerRadius : CGFloat = 10.0
        publicKeyTextView.layer.cornerRadius = cornerRadius
        privateKeyTextView.layer.cornerRadius = cornerRadius
        
        publicKeyTextView.text = keychain["PublicKey"]
        privateKeyTextView.text = keychain["PrivateKey"]

        publicKeyTextView.doneAccessory = true
        privateKeyTextView.doneAccessory = true
    }
    
    @IBAction func saveButtonAction(_ sender: Any) {
        keychain["PublicKey"] = publicKeyTextView.text
        keychain["PrivateKey"] = privateKeyTextView.text
        
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func generateButtonAction(_ sender: Any) {
        let alert = UIAlertController(title: NSLocalizedString("Enter password", comment: ""), message: nil, preferredStyle: .alert)
        
        alert.addTextField { (textField) in
            textField.placeholder = NSLocalizedString("Enter password", comment: "")
            textField.isSecureTextEntry = true
        }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Ok", comment: ""), style: .default, handler: { [weak alert] (_) in
            let textField = alert?.textFields![0]
            
            if let password = textField?.text {
                SVProgressHUD.show()
                self.view.isUserInteractionEnabled = false
                
                if let email = API.shared.currentUser.email {
                    DispatchQueue.global(qos: .userInitiated).async {
                        let key = KeyGenerator().generate(for: email, passphrase: password)
                        
                        DispatchQueue.main.async {
                            do {
                                let publicKey = try key.export(keyType: .public)
                                let secretKey = try key.export(keyType: .secret)
                                
                                let armoredPublicKey = Armor.armored(publicKey, as: .publicKey)
                                let armoredPrivateKey = Armor.armored(secretKey, as: .secretKey)
                                
                                self.publicKeyTextView.text = armoredPublicKey
                                self.privateKeyTextView.text = armoredPrivateKey
                                
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
            }
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
    
}
