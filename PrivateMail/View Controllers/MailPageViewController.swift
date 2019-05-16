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

    var mail: APIMail = APIMail() {
        didSet {
            let notSpamFolders = ["Sent", "Drafts", "Spam", "Trash"]
            let notASpam = notSpamFolders.contains(self.mail.folder ?? "")
            let hideSpamButton = (self.mail.folder ?? "") == "Trash"
            
            self.spamButton.tintColor = hideSpamButton ? .clear : .white
            self.spamButton.isEnabled = !hideSpamButton
            self.spamButton.image = UIImage(named: notASpam ? "not_spam" : "spam")
        }
    }
    
    @IBOutlet var spamButton: UIBarButtonItem!
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
    }

    
    // MARK: - Buttons Actions
    
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
                    if let body = mail.plainBody, let privateKey = keychain["PrivateKey"] {
                        let data = try Armor.readArmored(body)
                        let key = try ObjectivePGP.readKeys(from: privateKey.data(using: .utf8)!)
                        let decrypted = try ObjectivePGP.decrypt(data, andVerifySignature: false, using: key, passphraseForKey: { (key) -> String? in
                            return password
                        })
                        
                        let result = String(data: decrypted, encoding: .utf8)
                        mail.plainBody = result
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
        let moveToTrash = mail.folder != "Trash"
        
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
        
        let cancel = UIAlertAction.init(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { (alert: UIAlertAction!) in
        }
        
        actionSheet.addAction(replyButton)
        actionSheet.addAction(replyAllButton)
        actionSheet.addAction(forwardButton)
        actionSheet.addAction(cancel)
        
        present(actionSheet, animated: true, completion: nil)
    }
    
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        var newMail = APIMail()
        
        if segue.identifier == "ReplySegue" || segue.identifier == "ReplyAllSegue" {
            if segue.identifier == "ReplySegue" {
                if let sender = mail.from?.first {
                    newMail.to = [sender]
                }
            } else {
                newMail.to = mail.from
            }
            
            newMail.subject = "\(mail.reSubject())"
            newMail.plainBody = """
            
            On \(mail.date?.getFullDateString() ?? "") \(mail.from?.first ?? "") wrote
            <blockquote>
            \(mail.plainedBody(true))
            </blockquote>
            """
        } else if segue.identifier == "ForwardSegue" {
            newMail.subject = "Fwd: \(mail.subject ?? "")"
            
            newMail.plainBody = """
            
            –––– Original Message ––––
            From: \(mail.from?.joined(separator: ", ") ?? "")
            To: \(mail.to?.joined(separator: ", ") ?? "")
            Sent: \(mail.date?.getFullDateString() ?? "")
            Subject: \(mail.subject ?? "")
            
            \(mail.plainedBody(true))
            
            """
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
