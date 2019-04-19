//
//  MailViewController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import SVProgressHUD
import ObjectivePGP

class MailViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    var mail: APIMail = APIMail()
    
    @IBOutlet var decryptButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("Mail", comment: "")
        navigationController?.isToolbarHidden = false
        
        decryptButton.title = NSLocalizedString("Decrypt", comment: "")
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        
        tableView.register(cellClass: MailHeaderTableViewCell())
        tableView.register(cellClass: MailAttachmentTableViewCell())
        tableView.register(cellClass: MailBodyTableViewCell())
        
        StorageProvider.shared.containsMail(mail: mail) { (contains) in
            if contains == nil {
                SVProgressHUD.show()
                self.view.isUserInteractionEnabled = false
                
                API.shared.getMail(mail: self.mail) { (result, error) in
                    SVProgressHUD.dismiss()
                    
                    if let result = result {
                        self.mail = result
                        self.mail.isSeen = true
                        
                        API.shared.setMailSeen(mail: result, completionHandler: { (resul, error) in
                            if let error = error {
                                SVProgressHUD.showError(withStatus: error.localizedDescription)
                            }
                        })
                    }
                    
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                        self.view.isUserInteractionEnabled = true
                    }
                    
                    if let error = error {
                        SVProgressHUD.showError(withStatus: error.localizedDescription)
                        return
                    }
                }
            } else {
                if self.mail.isSeen != true {
                    self.mail.isSeen = true
                    StorageProvider.shared.saveMail(mail: self.mail)
                    
                    API.shared.setMailSeen(mail: self.mail, completionHandler: { (resul, error) in
                        if let error = error {
                            SVProgressHUD.showError(withStatus: error.localizedDescription)
                        }
                    })
                }
            }
        }
    }
    
    
    // MARK: - Buttons
    
    @IBAction func decryptButtonAction(_ sender: Any) {
        var mail = self.mail
        
        let alert = UIAlertController(title: NSLocalizedString("Enter password", comment: ""), message: nil, preferredStyle: .alert)
        
        alert.addTextField { (textField) in
            textField.placeholder = NSLocalizedString("Enter password", comment: "")
            textField.isSecureTextEntry = true
        }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Ok", comment: ""), style: .default, handler: { [weak alert] (_) in
            let textField = alert?.textFields![0]
            
            if let password = textField?.text {
                SVProgressHUD.show()
                
                do {
                    #if !targetEnvironment(simulator)
                    if let body = mail.body, let privateKey = keychain["PrivateKey"] {
                        let data = try Armor.readArmored(body)
                        let key = try ObjectivePGP.readKeys(from: privateKey.data(using: .utf8)!)
                        let decrypted = try ObjectivePGP.decrypt(data, andVerifySignature: false, using: key, passphraseForKey: { (key) -> String? in
                            return password
                        })
                        
                        let result = String(data: decrypted, encoding: .utf8)
                        mail.body = result
                        self.mail = mail
                        self.tableView.reloadData()
                    }
                    #endif
                    
                    SVProgressHUD.dismiss()
                } catch {
                    SVProgressHUD.showError(withStatus: NSLocalizedString("Can't decrypt message", comment: ""))
                }
            }
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func deleteButtonAction(_ sender: Any) {
        
        let alert = UIAlertController.init(title: NSLocalizedString("Delete this message?", comment: ""), message: nil, preferredStyle: .alert)
        
        let yesButton = UIAlertAction.init(title: NSLocalizedString("Yes", comment: ""), style: .destructive) { (alert: UIAlertAction!) in
            SVProgressHUD.show()
            
            StorageProvider.shared.deleteMail(mail: self.mail)
            
            API.shared.deleteMessage(mail: self.mail) { (result, error) in
                DispatchQueue.main.async {
                    if let success = result {
                        if success {
                            self.navigationController?.popViewController(animated: true)
                        } else {
                            SVProgressHUD.showError(withStatus: NSLocalizedString("Can't delete message", comment: ""))
                        }
                        
                        SVProgressHUD.dismiss()
                    } else {
                        if let error = error {
                            SVProgressHUD.showError(withStatus: error.localizedDescription)
                        } else {
                            SVProgressHUD.dismiss()
                        }
                    }
                }
            }
        }
        
        let cancelButton = UIAlertAction.init(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { (alert: UIAlertAction!) in
            
        }
        
        alert.addAction(cancelButton)
        alert.addAction(yesButton)
        
        present(alert, animated: true, completion: nil)
    }
    
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
    }
    
}


extension MailViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2 + (mail.attachments?.count ?? 0)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var result = UITableViewCell()
        
        switch indexPath.row {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: MailHeaderTableViewCell.cellID(), for: indexPath) as! MailHeaderTableViewCell
            cell.subjectLabel.text = mail.subject
            
            if cell.subjectLabel.text?.count == 0 {
                cell.subjectLabel.text = NSLocalizedString("(no subject)", comment: "")
            }
            
            cell.senderLabel.text = mail.senders?.first
            cell.dateLabel.text = mail.date?.getDateString()
            
            result = cell
            break
            
        case (self.tableView(tableView, numberOfRowsInSection: 0) - 1):
            let cell = tableView.dequeueReusableCell(withIdentifier: MailBodyTableViewCell.cellID(), for: indexPath) as! MailBodyTableViewCell
            cell.placeholderLabel.text = ""
            
            cell.textView.text = (mail.body?.count ?? 0) > 0 ? mail.body : mail.htmlBody

            cell.updateHeight(withAction: true)
            cell.textView.isEditable = false
            cell.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: .greatestFiniteMagnitude)
            result = cell
            break
            
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: MailAttachmentTableViewCell.cellID(), for: indexPath) as! MailAttachmentTableViewCell
            if let fileName = mail.attachments?[indexPath.row - 1]["FileName"] as? String {
                cell.titleLabel.text = fileName
            } else {
                cell.titleLabel.text = ""
            }
            
            result = cell
            break
            
        }
        
        result.selectionStyle = .none
        
        return result
    }
    
}
