//
//  MailPageViewController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import SVProgressHUD
import ObjectivePGP

class MailPageViewController: UIPageViewController {

    var folder: APIFolder = APIFolder() {
        didSet {
            let hideSpamFolders = [2, 3]

            let notASpam = (folder.type ?? -1) == 4
            spamButton.image = UIImage(named: notASpam ? "not_spam" : "spam")
            
            var buttons: [UIBarButtonItem] = [menuButton]
            
            if (folder.type ?? -1) != 5 {
                buttons.append(trashButton)
            }
            
            if !hideSpamFolders.contains(folder.type ?? -1) {
                buttons.append(spamButton)
            }
            
            navigationItem.rightBarButtonItems = buttons
        }
    }
    
    var mail: APIMail = APIMail()
    var keysToImport: String?
    
    @IBOutlet var spamButton: UIBarButtonItem!
    @IBOutlet var trashButton: UIBarButtonItem!
    @IBOutlet var menuButton: UIBarButtonItem!
    @IBOutlet var decryptButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = self
        delegate = self
        
        let mailVC = storyboard?.instantiateViewController(withIdentifier: "MailVC") as! MailViewController
        mailVC.mail = mail
        setViewControllers([mailVC], direction: .forward, animated: false, completion: nil)
        
        title = NSLocalizedString("Mail", comment: "")
        navigationController?.isToolbarHidden = false
        view.backgroundColor = .white
        
        decryptButton.title = NSLocalizedString("Decrypt", comment: "")
        
        NotificationCenter.default.addObserver(forName: .shouldImportKey, object: nil, queue: nil) { (notification) in
            DispatchQueue.main.async {
                if let keys = notification.object as? String {
                    self.keysToImport = keys
                    self.performSegue(withIdentifier: "ImportKeysSegue", sender: nil)
                }
            }
        }
    }

    
    // MARK: - Buttons Actions
    
    @IBAction func decryptButtonAction(_ sender: Any) {
        guard let mailVC = viewControllers?.first as? MailViewController else { return }
        var mail = mailVC.mail
        
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
                    if let privateKey = StorageProvider.shared.getPGPKey(API.shared.currentUser.email, isPrivate: true)?.armoredKey {
                        let body = mail.plainedBody(false)
                        let data = try Armor.readArmored(body)
                        let key = try ObjectivePGP.readKeys(from: privateKey.data(using: .utf8)!)
                        let decrypted = try ObjectivePGP.decrypt(data, andVerifySignature: false, using: key, passphraseForKey: { (key) -> String? in
                            return password
                        })
                        
                        let result = String(data: decrypted, encoding: .utf8)
                        mail.htmlBody = result
                        self.mail = mail
                        
                        if let mailVC = self.viewControllers?.last as? MailViewController {
                            mailVC.mail = mail
                            mailVC.tableView.reloadData()
                        }
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
    
    @IBAction func trashButtonAction(_ sender: Any) {
        let moveToTrash = (folder.type ?? -1) != 5
        
        let alert = UIAlertController.init(title: NSLocalizedString(moveToTrash ? "Move this message to trash?" : "Delete this message?", comment: ""), message: nil, preferredStyle: .alert)
        
        let yesButton = UIAlertAction.init(title: NSLocalizedString("Yes", comment: ""), style: .destructive) { (alert: UIAlertAction!) in
            SVProgressHUD.show()
            
            if moveToTrash {
                API.shared.moveMessage(mail: self.mail, toFolder: "Trash") { (result, error) in
                    DispatchQueue.main.async {
                        if let success = result {
                            if success {
                                StorageProvider.shared.deleteMail(mail: self.mail)
                                MenuModelController.shared.removeMail(mail: self.mail)
                                self.navigationController?.popViewController(animated: true)
                            } else {
                                SVProgressHUD.showError(withStatus: NSLocalizedString("Can't complete action", comment: ""))
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
            } else {
                API.shared.deleteMessage(mail: self.mail) { (result, error) in
                    DispatchQueue.main.async {
                        if let success = result {
                            if success {
                                StorageProvider.shared.deleteMail(mail: self.mail)
                                MenuModelController.shared.removeMail(mail: self.mail)
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
        }
        
        let cancelButton = UIAlertAction.init(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { (alert: UIAlertAction!) in
        }
        
        alert.addAction(cancelButton)
        alert.addAction(yesButton)
        
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func spamButtonAction(_ sender: Any) {
        let markAsSpam = mail.folder != "Spam"
        
        let alert = UIAlertController.init(title: NSLocalizedString(markAsSpam ? "Mark this message as spam?" :  "Mark this message as not spam?", comment: ""), message: nil, preferredStyle: .alert)
        
        let yesButton = UIAlertAction.init(title: NSLocalizedString("Yes", comment: ""), style: .destructive) { (alert: UIAlertAction!) in
            SVProgressHUD.show()
            
            API.shared.moveMessage(mail: self.mail, toFolder: markAsSpam ? "Spam" : "Inbox") { (result, error) in
                DispatchQueue.main.async {
                    if let success = result {
                        if success {
                            StorageProvider.shared.deleteMail(mail: self.mail)
                            MenuModelController.shared.removeMail(mail: self.mail)
                            self.navigationController?.popViewController(animated: true)
                        } else {
                            SVProgressHUD.showError(withStatus: NSLocalizedString("Can't complete action", comment: ""))
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
    
    @IBAction func menuButtonAction(_ sender: Any) {
        let actionSheet = UIAlertController.init(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let replyButton = UIAlertAction.init(title: NSLocalizedString("Reply", comment: ""), style: .default) { (alert: UIAlertAction!) in
            self.performSegue(withIdentifier: "ReplySegue", sender: nil)
        }
        
        replyButton.setValue(UIImage(named: "action_reply"), forKey: "image")
        
        let replyAllButton = UIAlertAction.init(title: NSLocalizedString("Reply all", comment: ""), style: .default) { (alert: UIAlertAction!) in
            self.performSegue(withIdentifier: "ReplyAllSegue", sender: nil)
        }
        
        replyAllButton.setValue(UIImage(named: "action_reply_all"), forKey: "image")
        
        let forwardButton = UIAlertAction.init(title: NSLocalizedString("Forward", comment: ""), style: .default) { (alert: UIAlertAction!) in
            self.performSegue(withIdentifier: "ForwardSegue", sender: nil)
        }
        
        forwardButton.setValue(UIImage(named: "action_forward"), forKey: "image")
        
        let removeButton = UIAlertAction.init(title: NSLocalizedString("Remove", comment: ""), style: .default) { (alert: UIAlertAction!) in
            self.trashButtonAction(self.trashButton as Any)
        }
        
        let cancel = UIAlertAction.init(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { (alert: UIAlertAction!) in
        }
        
        if ![2, 3, 4].contains(folder.type ?? -1) {
            actionSheet.addAction(replyButton)
            actionSheet.addAction(replyAllButton)
        }
        
        if (folder.type ?? -1) != 3 {
            actionSheet.addAction(forwardButton)
        }
        
        if (folder.type ?? -1) == 5 {
            actionSheet.addAction(removeButton)
        }
        
        actionSheet.addAction(cancel)
        
        present(actionSheet, animated: true, completion: nil)
    }
    
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ImportKeysSegue" {
            let vc = segue.destination as! ImportKeysListViewController
            vc.keyString = keysToImport
            return
        }
        
        var newMail = APIMail()
        
        guard let mailVC = viewControllers?.first as? MailViewController else { return }
        mail = mailVC.mail
        
        if segue.identifier == "ReplySegue" || segue.identifier == "ReplyAllSegue" {
//            if segue.identifier == "ReplySegue" {
//                if let sender = mail.from?.first {
//                    newMail.to = [sender]
//                }
//            } else {
            if let replyTo = mail.replyTo, replyTo.count > 0 {
                newMail.to = replyTo
            } else {
                newMail.to = mail.from
            }
//            }
            
            if segue.identifier == "ReplyAllSegue" {
                var emails: [String] = []
                
                var cc = mail.cc ?? []
                cc.append(contentsOf: mail.to ?? [])
                
                for email in cc {
                    if !emails.contains(email) && email != API.shared.currentUser.email {
                        emails.append(email)
                    }
                }
                
                newMail.cc = emails
            }
            
            newMail.subject = "\(mail.reSubject())"
            newMail.htmlBody = """
            
            On \(mail.date?.getFullDateString() ?? "") \(mail.from?.first ?? "") wrote
            <blockquote style=\"border-left: solid 2px #000000; margin: 4px 2px; padding-left: 6px;\">
            \(mail.body(false))
            </blockquote>
            """
        } else if segue.identifier == "ForwardSegue" {
            newMail.subject = "Fwd: \(mail.subject ?? "")"
            
            var body = """
            
            –––– Original Message ––––<br/>
            From: \(mail.from?.joined(separator: ", ") ?? "")<br/>
            To: \(mail.to?.joined(separator: ", ") ?? "")<br/>\n
            """
           
            if let cc = mail.cc, cc.count > 0 {
                body += "CC: \(cc.joined(separator: ", "))<br/>\n"
            }
            
            body += """
            Sent: \(mail.date?.getFullDateString() ?? "")<br/>
            Subject: \(mail.subject ?? "")<br/>
            
            \(mail.body(false))
            
            """
            
            newMail.htmlBody = body
        }
                
        ComposeMailModelController.shared.mail = newMail
    }
}


extension MailPageViewController: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        let mailVC = storyboard?.instantiateViewController(withIdentifier: "MailVC") as! MailViewController
        let currentVC = viewController as! MailViewController
        
        let mails = MenuModelController.shared.mailsForCurrentFolder()
        let index = mails.firstIndex { (item) -> Bool in
            return item.uid == currentVC.mail.uid
            } ?? 1
        
        let nextIndex = index - 1
        
        if nextIndex < 0 {
            return nil
        }
        
        mailVC.mail = mails[nextIndex]
        
        return mailVC
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        let mailVC = storyboard?.instantiateViewController(withIdentifier: "MailVC") as! MailViewController
        let currentVC = viewController as! MailViewController
        
        let mails = MenuModelController.shared.mailsForCurrentFolder()
        let index = mails.firstIndex { (item) -> Bool in
            return item.uid == currentVC.mail.uid
            } ?? -1
        
        let nextIndex = index + 1
        
        if nextIndex >= mails.count {
            return nil
        }
        
        mailVC.mail = mails[nextIndex]
        
        return mailVC
    }
}


extension MailPageViewController: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed {
            guard let mailVC = pageViewController.viewControllers?.first as? MailViewController else { return }
            mail = mailVC.mail
        }
    }
}
