//
//  MailViewController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import SVProgressHUD
import QuickLook

extension Notification.Name {
    static let shouldImportKey = Notification.Name("shouldImportKey")
}

class MailViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    
    var mail: APIMail = APIMail()
    var attachementPreviewURL: URL?
    var showSafe: Bool = true
    
    @IBOutlet var warningView: UIView!
    @IBOutlet var warningLabel: UILabel!
    @IBOutlet var showPicturesButton: UIButton!
    @IBOutlet var alwaysShowPicturesButton: UIButton!
    @IBOutlet var warningTopConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("Mail", comment: "")
        navigationController?.isToolbarHidden = false

        warningLabel.text = NSLocalizedString("Pictures in this message have been blocked for your safety", comment: "")
        showPicturesButton.setTitle("Show pictures", for: .normal)
        alwaysShowPicturesButton.setTitle("Always show pictures", for: .normal)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        
        tableView.register(cellClass: MailHeaderTableViewCell())
        tableView.register(cellClass: MailAttachmentTableViewCell())
        tableView.register(cellClass: MailHTMLBodyTableViewCell())
        
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
                self.mail = APIMail(data: contains!.data)
                self.mail.isSeen = contains!.isSeen
                self.mail.isFlagged = contains!.isFlagged
                self.mail.isForwarded = contains!.isForwarded
                self.mail.isDeleted = contains!.isDeleted
                self.mail.isDraft = contains!.isDraft
                self.mail.isRecent = contains!.isRecent
                
                if self.mail.showInlineWarning() {
                    self.warningTopConstraint.isActive = true
                    self.warningView.isHidden = false
                    self.tableView.contentInset.top = self.warningView.frame.size.height
                } else {
                    self.warningView.isHidden = true
                    self.tableView.contentInset.top = 0.0
                }
                
                self.tableView.scrollIndicatorInsets = self.tableView.contentInset
                self.tableView.scrollRectToVisible(CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0), animated: false)
                
                if self.mail.isSeen != true {
                    self.mail.isSeen = true
                    
                    StorageProvider.shared.saveMail(mail: self.mail)

                    API.shared.setMailSeen(mail: self.mail, completionHandler: { (resul, error) in
                        if let error = error {
                            SVProgressHUD.showError(withStatus: error.localizedDescription)
                        }
                    })
                }
                
                self.tableView.reloadData()
            }
        }
    }
    
    
    // MARK: - Buttons Actions
    
    @IBAction func showPicturesButtonAction(_ sender: Any) {
        showSafe = false
        tableView.reloadData()
        
        warningTopConstraint.isActive = false
        
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
            self.tableView.contentInset.top = 0.0
            self.tableView.scrollIndicatorInsets = self.tableView.contentInset
        }
    }
    
    @IBAction func alwaysShowPicturesButtonAction(_ sender: Any) {
        showPicturesButtonAction(sender)
        
        API.shared.setEmailSafety(mail: mail) { (resul, error) in
            
        }
    }
    
}


extension MailViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2 + mail.attachmentsToShow().count
    }
   
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var result = UITableViewCell()
        
        switch indexPath.row {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: MailHeaderTableViewCell.cellID(), for: indexPath) as! MailHeaderTableViewCell
            cell.subjectLabel.text = mail.subject
            cell.delegate = self
            
            if cell.subjectLabel.text?.count == 0 {
                cell.subjectLabel.text = NSLocalizedString("(no subject)", comment: "")
            }
            
            cell.senderLabel.text = mail.senders?.first
            
            cell.detailedSenderLabel.text = mail.from?.joined(separator: ", ")
            cell.detailedToLabel.text = mail.to?.joined(separator: ", ")
            cell.detailedDateLabel.text = mail.date?.getFullDateString()
            
            cell.dateLabel.text = mail.date?.getDateString()
            
            result = cell
            break
            
        case (self.tableView(tableView, numberOfRowsInSection: 0) - 1):
            let cell = tableView.dequeueReusableCell(withIdentifier: MailHTMLBodyTableViewCell.cellID(), for: indexPath) as! MailHTMLBodyTableViewCell
            
            cell.webView.loadHTMLString(mail.body(showSafe), baseURL: URL(string: API.shared.getServerURL()))
            cell.delegate = self
            
            cell.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: .greatestFiniteMagnitude)
            result = cell
            break
            
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: MailAttachmentTableViewCell.cellID(), for: indexPath) as! MailAttachmentTableViewCell
            
            cell.importKeyButton.isHidden = true
            cell.importConstraint.isActive = false
            
            if let fileName = mail.attachmentsToShow()[indexPath.row - 1]["FileName"] as? String {
                cell.titleLabel.text = fileName
                
                if (fileName as NSString).pathExtension == "asc" {
                    cell.importKeyButton.isHidden = false
                    cell.importConstraint.isActive = true
                }
                
            } else {
                cell.titleLabel.text = ""
            }
            
            cell.downloadLink = nil
            cell.delegate = self
            
            if let actions = mail.attachmentsToShow()[indexPath.row - 1]["Actions"] as? [String: [String: String]] {
                if let downloadLink = actions["download"]?["url"] {
                    cell.downloadLink = downloadLink
                }
            }
            
            result = cell
            break
        }
        
        result.selectionStyle = .none
        
        return result
    }
}


extension MailViewController: MailAttachmentTableViewCellDelegate {
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
                        SVProgressHUD.showError(withStatus: NSLocalizedString("Failed to download file", comment: ""))
                    }
                }
            }
        } else {
            SVProgressHUD.showError(withStatus: NSLocalizedString("Wrong url", comment: ""))
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
                                SVProgressHUD.showError(withStatus: NSLocalizedString("Something goes wrong", comment: ""))
                            }
                        }
                    } else {
                        SVProgressHUD.showError(withStatus: NSLocalizedString("Failed to download file", comment: ""))
                    }
                }
            }
        } else {
            SVProgressHUD.showError(withStatus: NSLocalizedString("Wrong url", comment: ""))
        }
    }
    
    func reloadData() {
    }
}


extension MailViewController: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return attachementPreviewURL! as QLPreviewItem
    }
}

extension MailViewController: UITableViewDelegateExtensionProtocol {
    func cellSizeDidChanged() {
        UIView.setAnimationsEnabled(false)
        tableView.beginUpdates()
        tableView.endUpdates()
        UIView.setAnimationsEnabled(true)
    }
}
