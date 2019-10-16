//
//  SettingsViewController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

struct SettingsItem {
    let title: String
    var segue: String? = nil
    var parameter: SettingsParameter? = nil
}

class SettingsViewController: UIViewController {

    @IBOutlet var tableView: UITableView!

    let content: [SettingsItem] = [
        SettingsItem(title: NSLocalizedString("Common", comment: ""), segue: "CommonSegue", parameter: nil),
        SettingsItem(title: NSLocalizedString("Sync", comment: ""), segue: "SyncSegue", parameter: nil),
        SettingsItem(title: NSLocalizedString("OpenPGP", comment: ""), segue: "PGPSegue", parameter: nil)
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = NSLocalizedString("Settings", comment: "")
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(cellClass: SettingsTableViewCell())
        tableView.tableFooterView = UIView(frame: .zero)
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
}

extension SettingsViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return content.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.cellID(), for: indexPath) as! SettingsTableViewCell
        
        cell.titleLabel.text = content[indexPath.row].title
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let segue = content[indexPath.row].segue {
            performSegue(withIdentifier: segue, sender: nil)
        }
    }
    
}
