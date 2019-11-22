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
import QuickLook
import Contacts

class ComposeMailViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    
    @IBOutlet var tableViewBottomConstraint: NSLayoutConstraint!
    
    @IBOutlet var dialogView: UIView!
    @IBOutlet var encryptDialogView: UIView!
    @IBOutlet var encryptDialogTitle: UILabel!
    @IBOutlet var signTitle: UILabel!
    @IBOutlet var signSwitch: UISwitch!
    @IBOutlet var encryptTitle: UILabel!
    @IBOutlet var encryptSwitch: UISwitch!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var eyeButton: UIButton!
    @IBOutlet var encryptButton: UIButton!
    @IBOutlet var cancelEncryptButton: UIButton!
    
    var attachementPreviewURL: URL?
    
    var shouldShowBcc = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.theme_backgroundColor = .surface
        tableView.theme_separatorColor = .onSurfaceSeparator
        encryptDialogView.theme_backgroundColor = .secondarySurface
        encryptDialogTitle.theme_textColor = .onSurfaceMajorText
        encryptTitle.theme_textColor = .onSurfaceMajorText
        signTitle.theme_textColor = .onSurfaceMajorText
        
        title = NSLocalizedString("Compose", comment: "")
        
        passwordTextField.delegate = self
        dialogView.alpha = 0.0
                
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 50.0
        
        tableView.register(cellClass: AddressTableViewCell())
        tableView.register(cellClass: MailSubjectTableViewCell())
        tableView.register(cellClass: MailBodyTableViewCell())
        tableView.register(cellClass: MailHTMLBodyTableViewCell())
        tableView.register(cellClass: MailAttachmentTableViewCell())
        
        tableView.tableFooterView = UIView(frame: CGRect.zero)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isToolbarHidden = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        tableView.reloadData()
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIApplication.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIApplication.keyboardWillHideNotification, object: nil)
                
        if let fileURL = ComposeMailModelController.shared.attachmentFileURL {
            ComposeMailModelController.shared.attachmentFileURL = nil
            addAttachments(urls: [fileURL])
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Button actions
    
    @IBAction func sendAction(_ sender: Any) {
        DispatchQueue.main.async {
            if let to = ComposeMailModelController.shared.mail.to {
                if to.count > 0 {
                    SVProgressHUD.show()
                    self.view.isUserInteractionEnabled = false
                    
                    let mail = ComposeMailModelController.shared.mail
                    
                    API.shared.sendMail(mail: mail) { (result, error) in
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
        
    }
    
    @IBAction func optionsAction(_ sender: Any) {
    }
    
    @IBAction func encryptAction(_ sender: Any) {
        UIView.animate(withDuration: 0.25) {
            self.dialogView.alpha = 1.0
        }
    }
    
    @IBAction func attachAction(_ sender: Any) {
        let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .formSheet
        
        if #available(iOS 11.0, *) {
            documentPicker.allowsMultipleSelection = false
        }
        
        present(documentPicker, animated: true, completion: nil)
    }
    
    @IBAction func signEncryptButtonAction(_ sender: Any) {
        var mail = ComposeMailModelController.shared.mail
        
        if let email = mail.to?.first {
            do {
                if let publicKey = StorageProvider.shared.getPGPKey(email, isPrivate: false)?.armoredKey {
                    #if !targetEnvironment(simulator)
                    if let body = mail.htmlBody, encryptSwitch.isOn {
                        let data = body.data(using: .utf8)!
                        var keys = try ObjectivePGP.readKeys(from: publicKey.data(using: .utf8)!)
                        
                        if let privateKey = StorageProvider.shared.getPGPKey(API.shared.currentUser.email, isPrivate: true)?.armoredKey {
                            do {
                               let privateKeys = try ObjectivePGP.readKeys(from: privateKey.data(using: .utf8)!)
                                keys.append(contentsOf: privateKeys)
                            } catch {
                                
                            }
                        }
                        
                        if signSwitch.isOn && passwordTextField.text?.count ?? 0 == 0 {
                            SVProgressHUD.showInfo(withStatus: NSLocalizedString("Please enter password for signing", comment: ""))
                            return
                        }
                        
                        let encrypted = try ObjectivePGP.encrypt(data, addSignature: signSwitch.isOn, using: keys, passphraseForKey: { (key) -> String? in
                            return passwordTextField.text
                        })
                        
                        let armoredResult = Armor.armored(encrypted, as: .message).replacingOccurrences(of: "\n", with: "<br>")
                        
                        mail.htmlBody = armoredResult
                        ComposeMailModelController.shared.mail = mail
                        tableView.reloadData()
                    }
                    #endif
                } else {
                    SVProgressHUD.showInfo(withStatus: NSLocalizedString("Please enter public key in settings", comment: ""))
                }
            } catch {
                SVProgressHUD.showInfo(withStatus: error.localizedDescription)
            }
        } else {
            SVProgressHUD.showInfo(withStatus: NSLocalizedString("Please add mail recipient", comment: ""))
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
    
    @IBAction func saveButtonAction(_ sender: Any) {
        SVProgressHUD.show()
        
        API.shared.sendMail(mail: ComposeMailModelController.shared.mail, isSaving: true) { (result, error) in
            DispatchQueue.main.async {
                if result ?? false {
                    SVProgressHUD.showSuccess(withStatus: nil)
                } else {
                    SVProgressHUD.showError(withStatus: error?.localizedDescription)
                }
            }
        }
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
        
//        tableView.reloadData()
    }
    
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "AddContact" {
            if let vc = segue.destination as? ContactsViewController,
                let style = (sender as? AddressTableViewCell)?.style {
                vc.isSelection = true
                vc.selectionStyle = style
            }
        }
    }
    
}


extension ComposeMailViewController: UITableViewDelegate, UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (shouldShowBcc ? 5 : 4) + (ComposeMailModelController.shared.mail.attachmentsToSend?.keys.count ?? 0)
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let mail = ComposeMailModelController.shared.mail
        
        var result = UITableViewCell()
            
        // Hot fix
        if shouldShowBcc {
            switch indexPath.row {
            case 0:
                let cell = tableView.dequeueReusableCell(withIdentifier: AddressTableViewCell.cellID(), for: indexPath) as! AddressTableViewCell
                cell.style = .to
                cell.setItems(ComposeMailModelController.shared.mail.to ?? [])
                cell.delegate = self
                cell.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
                result = cell
                break
                
            case 1:
                let cell = tableView.dequeueReusableCell(withIdentifier: AddressTableViewCell.cellID(), for: indexPath) as! AddressTableViewCell
                cell.style = .cc
                cell.setItems(ComposeMailModelController.shared.mail.cc ?? [])
                cell.delegate = self
                cell.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
                result = cell
                break
                
            case 2:
                let cell = tableView.dequeueReusableCell(withIdentifier: AddressTableViewCell.cellID(), for: indexPath) as! AddressTableViewCell
                cell.style = .bcc
                cell.setItems(ComposeMailModelController.shared.mail.bcc ?? [])
                cell.delegate = self
                cell.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
                result = cell
                break
                
            case 3:
                let cell = tableView.dequeueReusableCell(withIdentifier: MailSubjectTableViewCell.cellID(), for: indexPath) as! MailSubjectTableViewCell
                cell.textField.text = mail.subject
                cell.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
                result = cell
                break
                
            case (self.tableView(tableView, numberOfRowsInSection: 0) - 1):
                let cell = tableView.dequeueReusableCell(withIdentifier: MailHTMLBodyTableViewCell.cellID(), for: indexPath) as! MailHTMLBodyTableViewCell
                
                cell.isEditor = true
                cell.htmlText = mail.htmlBody ?? mail.plainBody ?? ""
                cell.delegate = self
                
                cell.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: .greatestFiniteMagnitude)
                result = cell
                break
                
            default:
                let cell = tableView.dequeueReusableCell(withIdentifier: MailAttachmentTableViewCell.cellID(), for: indexPath) as! MailAttachmentTableViewCell
                
                cell.importKeyButton.isHidden = true
                cell.importConstraint.isActive = false
                
                var tempNames: [String] = []
                
                for key in mail.attachmentsToSend!.keys {
                    tempNames.append(key)
                }
                
                tempNames.sort()
                
                let tempName = tempNames[indexPath.row - 4]
                
                if let attachment = mail.attachmentsToSend?[tempName] as? [String] {
                    let fileName = attachment[0]
                    
                    cell.downloadLink = tempName
                    cell.isComposer = true
                    cell.titleLabel.text = fileName
                    
                    if (fileName as NSString).pathExtension == "asc" {
                        cell.importKeyButton.isHidden = false
                        cell.importConstraint.isActive = true
                    }
                    
                } else {
                    cell.titleLabel.text = ""
                }
                
                cell.delegate = self
                
                result = cell
                break
            }
        } else {
            switch indexPath.row {
            case 0:
                let cell = tableView.dequeueReusableCell(withIdentifier: AddressTableViewCell.cellID(), for: indexPath) as! AddressTableViewCell
                cell.style = .to
                cell.setItems(ComposeMailModelController.shared.mail.to ?? [])
                cell.delegate = self
                cell.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
                result = cell
                break
                
            case 1:
                let cell = tableView.dequeueReusableCell(withIdentifier: AddressTableViewCell.cellID(), for: indexPath) as! AddressTableViewCell
                cell.style = .cc
                cell.setItems(ComposeMailModelController.shared.mail.cc ?? [])
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
                
            case (self.tableView(tableView, numberOfRowsInSection: 0) - 1):
                let cell = tableView.dequeueReusableCell(withIdentifier: MailHTMLBodyTableViewCell.cellID(), for: indexPath) as! MailHTMLBodyTableViewCell
                
                cell.isEditor = true
                cell.htmlText = mail.htmlBody ?? mail.plainBody ?? ""
                cell.delegate = self
                
                cell.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: .greatestFiniteMagnitude)
                result = cell
                break
                
            default:
                let cell = tableView.dequeueReusableCell(withIdentifier: MailAttachmentTableViewCell.cellID(), for: indexPath) as! MailAttachmentTableViewCell
                
                cell.importKeyButton.isHidden = true
                cell.importConstraint.isActive = false
                
                var tempNames: [String] = []
                
                for key in mail.attachmentsToSend!.keys {
                    tempNames.append(key)
                }
                
                tempNames.sort()
                
                let tempName = tempNames[indexPath.row - 3]
                
                if let attachment = mail.attachmentsToSend?[tempName] as? [String] {
                    let fileName = attachment[0]
                    
                    cell.downloadLink = tempName
                    cell.isComposer = true
                    cell.titleLabel.text = fileName
                    
                    if (fileName as NSString).pathExtension == "asc" {
                        cell.importKeyButton.isHidden = false
                        cell.importConstraint.isActive = true
                    }
                    
                } else {
                    cell.titleLabel.text = ""
                }
                
                cell.delegate = self
                
                result = cell
                break
            }
        }
            
        result.selectionStyle = .none
        
        return result
    }
}


extension ComposeMailViewController: UITableViewDelegateExtensionProtocol & UITextViewDelegateExtensionProtocol {
    func cellSizeDidChanged() {
        UIView.setAnimationsEnabled(false)
        tableView.beginUpdates()
        tableView.endUpdates()
        UIView.setAnimationsEnabled(true)
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


extension ComposeMailViewController: UIDocumentPickerDelegate {
    func addAttachments(urls: [URL]) {
        DispatchQueue.main.async {
            guard let url = urls.first else {
                return
            }
            
            SVProgressHUD.show()
            
            API.shared.uploadAttachment(fileName: url.absoluteString) { (result, error) in
                DispatchQueue.main.async {
                    SVProgressHUD.dismiss()
                    
                    if let result = result?["Result"] as? [String: Any] {
                        if let attachmentInfo = result["Attachment"] as? [String: Any],
                            let tempName = attachmentInfo["TempName"] as? String,
                            let fileName = attachmentInfo["FileName"] as? String {
                            let attachment = [fileName, "", "0", "0", ""]
                            
                            if ComposeMailModelController.shared.mail.attachmentsToSend == nil {
                                ComposeMailModelController.shared.mail.attachmentsToSend = [:]
                            }
                            
                            ComposeMailModelController.shared.mail.attachmentsToSend?[tempName] = attachment
                            self.tableView.reloadData()
                        } else {
                            SVProgressHUD.showError(withStatus: "Can't upload the file")
                        }
                    } else {
                        SVProgressHUD.showError(withStatus: "Can't upload the file")
                    }
                }
            }
        }
    }
    
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        addAttachments(urls: urls)
    }
    
    public func documentMenu(_ documentMenu:UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController) {
        documentPicker.delegate = self
        present(documentPicker, animated: true, completion: nil)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        dismiss(animated: true, completion: nil)
    }
}

extension ComposeMailViewController: MailAttachmentTableViewCellDelegate {
    func shouldOpenImportScreen(url: URL?, fileName: String) {
        if let url = url {
            SVProgressHUD.show()
            
            API.shared.downloadAttachementWith(url: url) { (data, error) in
                DispatchQueue.main.async {
                    SVProgressHUD.dismiss()
                    
                    if let error = error {
                        SVProgressHUD.showError(withStatus: error.localizedDescription)
                    } else if let data = data {
                        let keys = String(data: data, encoding: .utf8)
                        NotificationCenter.default.post(name: .shouldImportKey, object: keys)
                    } else {
                        SVProgressHUD.showError(withStatus: Strings.failedToDownloadFile)
                    }
                }
            }
        } else {
            SVProgressHUD.showError(withStatus: Strings.wrongUrl)
        }
    }
    
    func shouldPreviewAttachment(url: URL?, fileName: String) {
        if let url = url {
            SVProgressHUD.show()
            
            API.shared.downloadAttachementWith(url: url) { (data, error) in
                DispatchQueue.main.async {
                    SVProgressHUD.dismiss()
                    
                    if let error = error {
                        SVProgressHUD.showError(withStatus: error.localizedDescription)
                    } else if let data = data {
                        if let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                            let fileURL = directory.appendingPathComponent(fileName)
                            
                            do {
                                try data.write(to: fileURL)
                                
                                self.attachementPreviewURL = fileURL
                                
                                let previewController = QLPreviewController()
                                previewController.dataSource = self
                                self.present(previewController, animated: true)
                            } catch {
                                SVProgressHUD.showError(withStatus: Strings.somethingGoesWrong)
                            }
                        }
                    } else {
                        SVProgressHUD.showError(withStatus: Strings.failedToDownloadFile)
                    }
                }
            }
        } else {
            SVProgressHUD.showError(withStatus: Strings.wrongUrl)
        }
    }
}


extension ComposeMailViewController: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return attachementPreviewURL! as QLPreviewItem
    }
    
    func reloadData() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
}
