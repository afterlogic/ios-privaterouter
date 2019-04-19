//
//  MailViewController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import ObjectivePGP
import SVProgressHUD

class ComposeMailViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    
    @IBOutlet var tableViewBottomConstraint: NSLayoutConstraint!
    
    @IBOutlet var dialogView: UIView!
    @IBOutlet var signSwitch: UISwitch!
    @IBOutlet var encryptSwitch: UISwitch!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var eyeButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("Compose", comment: "")
        navigationController?.isToolbarHidden = false
        
        passwordTextField.delegate = self
        dialogView.alpha = 0.0
        
        ComposeMailModelController.shared.mail = APIMail()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 50.0
        
        tableView.register(cellClass: AddressTableViewCell())
        tableView.register(cellClass: MailSubjectTableViewCell())
        tableView.register(cellClass: MailBodyTableViewCell())
        
        tableView.tableFooterView = UIView(frame: CGRect.zero)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        tableView.reloadData()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIApplication.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIApplication.keyboardWillHideNotification, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Button actions
    
    @IBAction func sendAction(_ sender: Any) {
        if let to = ComposeMailModelController.shared.mail.to {
            if to.count > 0 {
                SVProgressHUD.show()
                view.isUserInteractionEnabled = false
                
                API.shared.sendMail(mail: ComposeMailModelController.shared.mail) { (result, error) in
                    DispatchQueue.main.async {
                        SVProgressHUD.dismiss()
                        self.view.isUserInteractionEnabled = true
                        
                        if let success = result {
                            if success {
                                self.navigationController?.popViewController(animated: true)
                            } else {
                                SVProgressHUD.showError(withStatus: NSLocalizedString("Message wasn't sent", comment: ""))
                            }
                        } else if let error = error {
                            SVProgressHUD.showError(withStatus: error.localizedDescription)
                            return
                        }
                        
                    }
                    
                }
                
            }
        }
        
    }
    
    @IBAction func optionsAction(_ sender: Any) {
    }
    
    @IBAction func encryptAction(_ sender: Any) {
        UIView.animate(withDuration: 0.25) {
            self.dialogView.alpha = 1.0
        }
    }
    
    @IBAction func attachAction(_ sender: Any) {

    }
    
    @IBAction func signEncryptButtonAction(_ sender: Any) {
        var mail = ComposeMailModelController.shared.mail
        
        do {
            if let publicKey = keychain["PublicKey"] {
                if let body = mail.body, encryptSwitch.isOn {
                    let data = body.data(using: .utf8)!
                    let key = try ObjectivePGP.readKeys(from: publicKey.data(using: .utf8)!)
                    
                    let encrypted = try ObjectivePGP.encrypt(data, addSignature: signSwitch.isOn && false, using: key, passphraseForKey: { (key) -> String? in
                        return passwordTextField.text
                    })

                    let armoredResult = Armor.armored(encrypted, as: .message)
                    
                    mail.body = armoredResult
                    ComposeMailModelController.shared.mail = mail
                    tableView.reloadData()
                }
            } else {
                SVProgressHUD.showInfo(withStatus: NSLocalizedString("Please enter public key in settings", comment: ""))
            }
        } catch {
        }
        
        cancelButtonAction(sender)
    }
    
    @IBAction func cancelButtonAction(_ sender: Any) {
        passwordTextField.resignFirstResponder()
        
        UIView.animate(withDuration: 0.25) {
            self.dialogView.alpha = 0.0
        }
    }
    
    @IBAction func eyeButtonAction(_ sender: UIButton) {
        passwordTextField.isSecureTextEntry = !passwordTextField.isSecureTextEntry
        
        let icon = UIImage(named: passwordTextField.isSecureTextEntry ? "password_eye_closed" : "password_eye_opened")
        sender.setImage(icon, for: .normal)
    }
    
    
    // MARK: - Keyboard
    
    @objc func keyboardWillShow(notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            tableViewBottomConstraint.constant = keyboardSize.height
            
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: {
                self.view.layoutIfNeeded()
            }, completion: nil)
        }
    }
    
    @objc func keyboardWillHide(notification: Notification) {
        tableViewBottomConstraint.constant = 0.0
        
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
    }
    
}


extension ComposeMailViewController: UITableViewDelegate, UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let mail = ComposeMailModelController.shared.mail
        
        var result = UITableViewCell()
        
        switch indexPath.row {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: AddressTableViewCell.cellID(), for: indexPath) as! AddressTableViewCell
            cell.style = .to
            cell.items = ComposeMailModelController.shared.mail.to ?? []
            cell.delegate = self
            cell.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            result = cell
            break
            
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: AddressTableViewCell.cellID(), for: indexPath) as! AddressTableViewCell
            cell.style = .cc
            cell.items = ComposeMailModelController.shared.mail.cc ?? []
            cell.delegate = self
            cell.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            result = cell
            break
            
        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: MailSubjectTableViewCell.cellID(), for: indexPath) as! MailSubjectTableViewCell
            cell.textField.text = mail.subject
            cell.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            result = cell
            break
            
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: MailBodyTableViewCell.cellID(), for: indexPath) as! MailBodyTableViewCell
            cell.textView.text = mail.body
            cell.updateHeight(withAction: false)
            cell.delegate = self
            cell.textView.doneAccessory = true
            cell.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: .greatestFiniteMagnitude)
            result = cell
            break
        }
        
        result.selectionStyle = .none
        
        return result
    }
}


extension ComposeMailViewController: UITableViewDelegateExtensionProtocol & UITextViewDelegateExtensionProtocol {
    func cellSizeDidChanged() {
        tableView.beginUpdates()
        tableView.endUpdates()
    }
    
    func textViewDidChanged(textView: UITextView) {
//        let caret = textView.caretRect(for: textView.selectedTextRange!.start)
//        let convertedCaret = textView.convert(caret, to: tableView)
//        let diffY = convertedCaret.origin.y - tableView.contentOffset.y + convertedCaret.height + 7.0 - tableView.frame.size.height
//
//        if diffY > 0.0 {
//            self.tableView.setContentOffset(CGPoint.init(x: 0.0, y: self.tableView.contentOffset.y + diffY), animated: true)
//        }
    }
}


extension ComposeMailViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}
