//
//  MailViewController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import DMSOpenPGP
import SVProgressHUD
import QuickLook
import Contacts
import DropDown
import SwiftTheme

class ComposeMailViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    
    @IBOutlet var tableViewBottomConstraint: NSLayoutConstraint!
    
    @IBOutlet var encryptBarButton: UIBarButtonItem!
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
    var mailInput: MailHTMLBodyTableViewCell?
    private var shouldShowBcc = false
    
    private var shouldShowFrom = false
    
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
        if let attachmentText = modelController.attachmentText {
            modelController.attachmentText = nil
            addAttachments(text: attachmentText)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Button actions
    
    @IBAction func sendAction(_ sender: Any) {
        guard let to = self.modelController.mail.to, to.count > 0 else  {
            return
        }
        let progressCompletion = ProgressHUD.showWithCompletion()
        
                modelController.mail.htmlBody = mailInput?.getTextFromWebView()
        self.view.isUserInteractionEnabled = false
        
        var mail = self.modelController.mail
        if(!mail.encrypted && !mail.signed){
            mail.htmlBody = mailInput?.getTextFromWebView()
        }
        API.shared.sendMail(mail: mail, identity: self.modelController.selectedIdentity) { (result, error) in
            DispatchQueue.main.async {
                self.view.isUserInteractionEnabled = true
                
                if let error = error {
                    progressCompletion(.error(error.localizedDescription))
                } else if result != nil {
                    progressCompletion(.dismiss)
                    self.navigationController?.popViewController(animated: true)
                } else {
                    progressCompletion(.error(NSLocalizedString("Message wasn't sent", comment: "")))
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
        modelController.mail.htmlBody = mailInput?.getTextFromWebView()
        var mail = modelController.mail
        if( mail.encrypted || mail.signed ){
            return
        }
        mail.isHtml=false
        
        
        do {
            var email:String?
            var publicKeyRing:DMSPGPKeyRing?
            if(encryptSwitch.isOn){
                email = mail.to?.first
                if(email==nil){
                    SVProgressHUD.showInfo(withStatus: NSLocalizedString("Please add mail recipient", comment: ""))
                    cancelButtonAction(sender)
                    return
                }
                let publicArmoredKeyString = StorageProvider.shared.getPGPKey(email!, isPrivate: false)?.armoredKey
                
                if(publicArmoredKeyString==nil){
                    SVProgressHUD.showInfo(withStatus: NSLocalizedString("Please enter public key in settings", comment: ""))
                    cancelButtonAction(sender)
                    return
                }
                publicKeyRing = try DMSPGPKeyRing(armoredKey: String(publicArmoredKeyString!) );
            }
            

            let message = try NSAttributedString(data: mail.htmlBody!.data(using: .utf8)!, options: [.documentType : NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil).string
            var secretKeyRing : DMSPGPKeyRing? = nil;
            
            if signSwitch.isOn {
                if  passwordTextField.text?.count ?? 0 == 0 {
                    SVProgressHUD.showInfo(withStatus: NSLocalizedString("Please enter password for signing", comment: ""))
                    cancelButtonAction(sender)
                    return
                }
                let secretArmoredKeyString = StorageProvider.shared.getPGPKey(API.shared.currentUser.email!, isPrivate: true)?.armoredKey
                if(secretArmoredKeyString==nil){
                    SVProgressHUD.showInfo(withStatus: NSLocalizedString("Please enter private key in settings", comment: ""))
                    cancelButtonAction(sender)
                    return
                }
                secretKeyRing = try DMSPGPKeyRing(armoredKey: String(secretArmoredKeyString!)  );
                
            }
            
            var encryptedMessage = message.removingRegexMatches(pattern: "\n", replaceWith: "\r\n")
            if (signSwitch.isOn){
                mail.signed=true
                mail.encrypted=publicKeyRing != nil
                let pass : String = passwordTextField.text ?? ""
                
                let encryptorWithSignature = publicKeyRing != nil ?
                    try DMSPGPEncryptor(
                        publicKeyRings: [publicKeyRing!.publicKeyRing],
                        secretKeyRing: (secretKeyRing?.secretKeyRing!)!,
                        password:  pass) :
                    try DMSPGPEncryptor(
                        secretKeyRing: (secretKeyRing?.secretKeyRing!)!,
                        password:  pass)
                
                encryptedMessage = try encryptorWithSignature.encrypt(fullMessage: encryptedMessage)
                
            } else if(encryptSwitch.isOn) {
                mail.encrypted=true
                let encryptorWithoutSignature = try DMSPGPEncryptor(publicKeyRings: [publicKeyRing!.publicKeyRing ])
                
                encryptedMessage = try encryptorWithoutSignature.encrypt(fullMessage: encryptedMessage)
            }else{
                cancelButtonAction(sender)
                return
            }
            
            
            mail.encryptedBody = encryptedMessage
            mail.htmlBody = mail.encryptedBody!.removingRegexMatches(pattern: "\n", replaceWith: "<br>")
            modelController.mail = mail
            ComposeMailModelController.shared.mail = mail
            mailInput!.isEditor = false
            mailInput!.htmlText = mail.htmlBody!
            mailInput!.setEnable(false)
            encryptBarButton.isEnabled = false
            encryptBarButton.tintColor = UIColor.clear
        } catch {
            SVProgressHUD.showInfo(withStatus: error.localizedDescription)
        }
        tableView.reloadData()
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
        modelController.mail.htmlBody = mailInput?.getTextFromWebView()
        SVProgressHUD.show()
    
        API.shared.sendMail(mail: modelController.mail,identity: nil, isSaving: true) { (result, error) in
            DispatchQueue.main.async {
                SVProgressHUD.dismiss()
                if error == nil {
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
        
        shouldShowFrom = identities.isNotEmpty
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
        (shouldShowFrom ? 1 : 0)
            + (shouldShowBcc ? 5 : 4)
            + (modelController.mail.attachmentsToSend?.keys.count ?? 0)
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let mail = modelController.mail
        
        var result: UITableViewCell?
        
        let fromShift = shouldShowFrom ? 1 : 0
        let bccShift = fromShift + (shouldShowBcc ? 1 : 0)
        
        switch true {
        case shouldShowFrom && indexPath.row == 0:
            let cell: IdentityChooserTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            
            cell.valueText = modelController.selectedIdentity?.description
                ?? defaultIdentityText
            
            cell.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            result = cell
            break
            
        case indexPath.row == 0 + fromShift:
            let cell: AddressTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.isUserInteractionEnabled = !modelController.mail.encrypted
            cell.textLabel?.isEnabled =  !modelController.mail.encrypted
            cell.detailTextLabel?.isEnabled =  !modelController.mail.encrypted
            cell.style = .to
            cell.setItems(modelController.mail.to ?? [],!modelController.mail.encrypted)
            cell.delegate = self
            cell.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            result = cell
            break
            
        case indexPath.row == 1 + fromShift:
            let cell: AddressTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.isUserInteractionEnabled = !modelController.mail.encrypted
            cell.textLabel?.isEnabled =  !modelController.mail.encrypted
            cell.detailTextLabel?.isEnabled =  !modelController.mail.encrypted
            cell.style = .cc
            cell.setItems(modelController.mail.cc ?? [],!modelController.mail.encrypted)
            cell.delegate = self
            cell.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            result = cell
            break
            
        case shouldShowBcc && indexPath.row == 2 + fromShift:
            let cell: AddressTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.isUserInteractionEnabled = !modelController.mail.encrypted
            cell.textLabel?.isEnabled =  !modelController.mail.encrypted
            cell.detailTextLabel?.isEnabled =  !modelController.mail.encrypted
            cell.style = .bcc
            cell.setItems(modelController.mail.bcc ?? [],!modelController.mail.encrypted)
            cell.delegate = self
            cell.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            result = cell
            break
            
        case indexPath.row == 2 + bccShift:
            let cell: MailSubjectTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.textField.text = mail.subject
            cell.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            result = cell
            break
            
        case indexPath.row == (self.tableView(tableView, numberOfRowsInSection: 0) - 1):
            if(mailInput==nil){
                mailInput = tableView.dequeueReusableCell(for: indexPath)
                
                mailInput!.isEditor = true
                mailInput!.isAllowTheming = false
                mailInput!.htmlText = mail.htmlBody ?? mail.plainBody ?? ""
                mailInput!.delegate = self
                
                mailInput!.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: .greatestFiniteMagnitude)
            }
            result = mailInput
            
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
        guard shouldShowFrom && indexPath.row == 0 else { return }
        
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
        dropdown.backgroundColor = ThemeManager.color(.secondarySurface)
        dropdown.selectedTextColor = ThemeManager.color(.onAccent)
        dropdown.selectionBackgroundColor = ThemeManager.color(.accent)
        
        dropdown.show()
    }
}


extension ComposeMailViewController: AddressTableViewCellDelegate {
    
    func cellSizeDidChanged() {
        UIView.setAnimationsEnabled(false)
        tableView.beginUpdates()
        tableView.endUpdates()
        UIView.setAnimationsEnabled(true)
    }
    
    func addressCellContentTriggered(_ cell: AddressTableViewCell) {
        if cell.style == .cc {
            if !shouldShowBcc {
                shouldShowBcc = true
                let bccCellIndexPath = IndexPath(row: shouldShowFrom ? 3 : 2, section: 0)
                tableView.insertRows(at: [bccCellIndexPath], with: .automatic)
            }
        }
    }
    
}

extension ComposeMailViewController: UITextViewDelegateExtensionProtocol {
    
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
    func addAttachments(text: [String: String]) {
        DispatchQueue.main.async {
            
            let key = text.first!
            
            SVProgressHUD.show()
            API.shared.uploadAttachment(name: key.key, content: key.value) { (result, error) in
                DispatchQueue.main.async {
                    SVProgressHUD.dismiss()
                    
                    if let result = result?["Result"] as? [String: Any] {
                        if  let tempName = result["FileName"] as? String,
                            let fileName = result["FileName"] as? String {
                            let attachment = [fileName, "", "0", "0", ""]
                            
                            if self.modelController.mail.attachmentsToSend == nil {
                                self.modelController.mail.attachmentsToSend = [:]
                            }
                            
                            self.modelController.mail.attachmentsToSend?[tempName] = attachment
                            self.tableView.reloadData()
                            
                        } else {
                            SVProgressHUD.showError(withStatus: "Can't upload the file")
                        }
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
