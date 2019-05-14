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
    @IBOutlet var scrollView: UIScrollView!
    
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIApplication.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIApplication.keyboardWillHideNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Buttons
    
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
                
                #if !targetEnvironment(simulator)
                self.view.isUserInteractionEnabled = false
                
                if let email = API.shared.currentUser.email {
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
                #endif
                
            }
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    
    // MARK: - Keyboard
    
    @objc func keyboardWillShow(notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: {
                self.scrollView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: keyboardSize.height, right: 0.0)
                self.scrollView.scrollIndicatorInsets = self.scrollView.contentInset
            }, completion: nil)
        }
    }
    
    @objc func keyboardWillHide(notification: Notification) {
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: {
            self.scrollView.contentInset = UIEdgeInsets()
            self.scrollView.scrollIndicatorInsets = self.scrollView.contentInset
        }, completion: nil)
    }
    
}
