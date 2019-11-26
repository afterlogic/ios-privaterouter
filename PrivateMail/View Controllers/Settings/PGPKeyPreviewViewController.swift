//
//  PGPKeyPreviewViewController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

class PGPKeyPreviewViewController: UIViewController {

    @IBOutlet var tableView: UITableView!
    
    var key: PGPKey?
    
    var showForMultiple = false {
        didSet {
            if self.showForMultiple {
                self.buttons = [
                    NSLocalizedString("SEND ALL", comment: ""),
                    NSLocalizedString("DOWNLOAD ALL", comment: "")
                ]
            } else {
                self.buttons = [
                    NSLocalizedString("SEND", comment: ""),
                    NSLocalizedString("DOWNLOAD", comment: ""),
                    NSLocalizedString("DELETE", comment: "")
                ]
            }
        }
    }
    
    var buttons: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(cellClass: MailHTMLBodyTableViewCell())
        tableView.register(cellClass: SettingsButtonTableViewCell())
        tableView.tableFooterView = UIView(frame: .zero)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.isToolbarHidden = true
        
        if key?.accountID == -1 {
            navigationItem.title = NSLocalizedString("All public keys", comment: "")
        } else if key?.isPrivate == true {
            navigationItem.title = NSLocalizedString("Private key", comment: "")
        } else {
            navigationItem.title = NSLocalizedString("Public key", comment: "")
        }
    }
    
}

extension PGPKeyPreviewViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else {
            return buttons.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: MailHTMLBodyTableViewCell.cellID(), for: indexPath) as! MailHTMLBodyTableViewCell
            
            if var body = key?.armoredKey {
                body = body.replacingOccurrences(of: "\n", with: "<br>")
                body = """
                <div style=\"padding: 10px; word-break: break-word; font-size: 10px;\">
                \(body)
                </div>
                """
                
                cell.webView.loadHTMLString(body, baseURL: nil)
                cell.webView.scrollView.isScrollEnabled = false
            }
            
            cell.delegate = self
            
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsButtonTableViewCell.cellID(), for: indexPath) as! SettingsButtonTableViewCell
            cell.titleLabel.text = buttons[indexPath.row]
            cell.separatorInset = UIEdgeInsets(top: 0.0, left: tableView.bounds.width, bottom: 0.0, right: 0.0)
            
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return key?.email
        }

        return nil
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        Themer.themeTableViewSectionHeader(view)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 {
            if indexPath.row == 0 {
                var mail = APIMail()
                mail.htmlBody = key?.armoredKey.replacingOccurrences(of: "\n", with: "<br>")
                
                ComposeMailModelController.shared.mail = mail
                performSegue(withIdentifier: "ComposeSegue", sender: nil)
            } else if indexPath.row == 1 {
                if let key = self.key {
                    
                    var filename = "\(key.email) OpenPGP \(key.isPrivate ? "private" : "public") key.asc"
                    
                    if key.accountID == -1 {
                        filename = "OpenPGP \(key.isPrivate ? "private" : "public") keys.asc"
                    }
                    
                    let path = NSTemporaryDirectory() + "/" + filename
                    
                    do {
                        try key.armoredKey.write(toFile: path, atomically: true, encoding: .utf8)
                        
                        let fileURL = NSURL(fileURLWithPath: path)
                        
                        let objectsToShare = [fileURL]
                        let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
                        
                        self.present(activityVC, animated: true, completion: nil)
                    } catch {
                    }
                }
            } else if indexPath.row == 2 {
                let ok = UIAlertAction(title: NSLocalizedString("Ok", comment: ""), style: .destructive) { (action) in
                    
                    if let key = self.key {
                        StorageProvider.shared.deletePGPKey(key.email, isPrivate: key.isPrivate)
                    }
                    
                    self.navigationController?.popViewController(animated: true)
                }
                
                presentAlertView(NSLocalizedString("Warning", comment: ""), message: NSLocalizedString("Confirm key removal", comment: ""), style: .alert, actions: [ok], addCancelButton: true)
            }
        }
    }
    
}

extension PGPKeyPreviewViewController: UITableViewDelegateExtensionProtocol {
    func cellSizeDidChanged() {
        UIView.setAnimationsEnabled(false)
        tableView.beginUpdates()
        tableView.endUpdates()
        UIView.setAnimationsEnabled(true)
    }
}
