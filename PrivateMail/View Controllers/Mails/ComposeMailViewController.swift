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
import DropDown
import SwiftTheme

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
    
    private var showFrom = false
    
    private var isFirstIdentityUpdate = true
    
    private let identitiesRepository = IdentitiesRepository.shared
    private let modelController = ComposeMailModelController.shared
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupIdentities()
        
        view.theme_backgroundColor = .surface
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
    
        tableView.register(cellClass: IdentityChooserTableViewCell.self)
        tableView.register(cellClass: AddressTableViewCell.self)
        tableView.register(cellClass: MailSubjectTableViewCell.self)
        tableView.register(cellClass: MailBodyTableViewCell.self)
        tableView.register(cellClass: MailHTMLBodyTableViewCell.self)
        tableView.register(cellClass: MailAttachmentTableViewCell.self)
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
                
        if let fileURL = modelController.attachmentFileURL {
            modelController.attachmentFileURL = nil
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
            if let to = self.modelController.mail.to {
                if to.count > 0 {
                    SVProgressHUD.show()
                    self.view.isUserInteractionEnabled = false
                    
                    let mail = self.modelController.mail
                    
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
        var mail = modelController.mail
        
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
                        modelController.mail = mail
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
        
        API.shared.sendMail(mail: modelController.mail, isSaving: true) { (result, error) in
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
    
    
    // region: MARK: - Identities
    
    private func setupIdentities() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(updateContentByIdentities), name: .identitiesChanged, object: identitiesRepository)
        
        updateContentByIdentities()
        updateIdentities()
    }
    
    private func updateIdentities() {
        let progressCompletion = ProgressHUD.showWithErrorCompletion()
        identitiesRepository.updateIdentities(completionHandler: progressCompletion)
    }
    
    @objc private func updateContentByIdentities() {
        let identities = identitiesRepository.identities
        
        if identities.isNotEmpty && isFirstIdentityUpdate {
            isFirstIdentityUpdate = false
            selectDefaultIdentity()
        }
    
        if let currentSelectedIdentity = modelController.selectedIdentity,
           !identities.contains(currentSelectedIdentity) {
            selectDefaultIdentity()
        }
        
        showFrom = identities.isNotEmpty
        reloadData()
    }
    
    private func selectDefaultIdentity() {
        modelController.selectedIdentity = identitiesRepository.identities
            .first(where: { $0.isDefault })
    }
    
    // endregion
    
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
    
    private var defaultIdentityText: String {
        "\(API.shared.currentUser.firstName ?? "") <\(API.shared.currentUser.email ?? "")>"
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        (showFrom ? 1 : 0)
            + (shouldShowBcc ? 5 : 4)
            + (modelController.mail.attachmentsToSend?.keys.count ?? 0)
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let mail = modelController.mail
        
        var result: UITableViewCell?
        
        let fromShift = showFrom ? 1 : 0
        let bccShift = fromShift + (shouldShowBcc ? 1 : 0)
    
        switch true {
        case showFrom && indexPath.row == 0:
            let cell: IdentityChooserTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            
            cell.valueText = modelController.selectedIdentity?.description
                ?? defaultIdentityText
            
            cell.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            result = cell
            break
            
        case indexPath.row == 0 + fromShift:
            let cell = tableView.dequeueReusableCell(withIdentifier: AddressTableViewCell.cellID(), for: indexPath) as! AddressTableViewCell
            cell.style = .to
            cell.setItems(modelController.mail.to ?? [])
            cell.delegate = self
            cell.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            result = cell
            break
    
        case indexPath.row == 1 + fromShift:
            let cell = tableView.dequeueReusableCell(withIdentifier: AddressTableViewCell.cellID(), for: indexPath) as! AddressTableViewCell
            cell.style = .cc
            cell.setItems(modelController.mail.cc ?? [])
            cell.delegate = self
            cell.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            result = cell
            break
    
        case shouldShowBcc && indexPath.row == 2 + fromShift:
            let cell = tableView.dequeueReusableCell(withIdentifier: AddressTableViewCell.cellID(), for: indexPath) as! AddressTableViewCell
            cell.style = .bcc
            cell.setItems(modelController.mail.bcc ?? [])
            cell.delegate = self
            cell.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            result = cell
            break
    
        case indexPath.row == 2 + bccShift:
            let cell = tableView.dequeueReusableCell(withIdentifier: MailSubjectTableViewCell.cellID(), for: indexPath) as! MailSubjectTableViewCell
            cell.textField.text = mail.subject
            cell.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            result = cell
            break
    
        case indexPath.row == (self.tableView(tableView, numberOfRowsInSection: 0) - 1):
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
            
            let positionShift = bccShift + 3
        
            let tempName = tempNames[indexPath.row - positionShift]
        
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
        
        let checkedResult = result ?? UITableViewCell()
    
        checkedResult.selectionStyle = .none
        
        return checkedResult
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard showFrom && indexPath.row == 0 else { return }
        
        let dropdown = DropDown()
        dropdown.dataSource = [defaultIdentityText] + identitiesRepository.identities.map { $0.description }
        dropdown.selectionAction = { [weak self] (i, _) in
            guard let self = self else { return }
            
            if i == 0 {
                self.modelController.selectedIdentity = nil
            } else {
                self.modelController.selectedIdentity = self.identitiesRepository.identities[i - 1]
            }
            
            self.updateContentByIdentities()
        }
        
        
        dropdown.width = tableView.bounds.width - 48
        dropdown.bottomOffset = CGPoint(x: 24, y: 40)
        dropdown.anchorView = tableView.cellForRow(at: indexPath)
    
        dropdown.textColor = ThemeManager.color(.onSurfaceMajorText)
        dropdown.backgroundColor = ThemeManager.color(.surface)
        dropdown.selectedTextColor = ThemeManager.color(.onAccent)
        dropdown.selectionBackgroundColor = ThemeManager.color(.accent)
        
        dropdown.show()
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
                            
                            if self.modelController.mail.attachmentsToSend == nil {
                                self.modelController.mail.attachmentsToSend = [:]
                            }
                            
                            self.modelController.mail.attachmentsToSend?[tempName] = attachment
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

fileprivate extension APIIdentity {
    
    var description: String {
        "\(friendlyName) <\(email)>"
    }
    
}
