//
//  CommonSettingsViewController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import SwiftTheme

class CommonSettingsViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    
    let content: [SettingsItem] = [
        SettingsItem(title: NSLocalizedString("Time format", comment: ""), segue: nil, parameter: .timeFormat),
        SettingsItem(title: NSLocalizedString("Dark theme", comment: ""), segue: nil, parameter: .darkTheme),
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = NSLocalizedString("Common", comment: "")
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(cellClass: SettingsTableViewCell())
        tableView.tableFooterView = UIView(frame: .zero)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
}

extension CommonSettingsViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return content.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.cellID(), for: indexPath) as! SettingsTableViewCell
        cell.delegate = self
        
        cell.titleLabel.text = content[indexPath.row].title
        
        if let parameter = content[indexPath.row].parameter {
            switch parameter {
            case .timeFormat:
                cell.style = .leftText
                let isAMPM = (SettingsModelController.shared.getValueFor(.timeFormat) as? Bool) ?? true
                
                cell.leftTextLabel.text = isAMPM ? NSLocalizedString("1PM", comment: "") : NSLocalizedString("13:00", comment: "")
                break
                
            case .darkTheme:
                cell.style = .switcher
                let isDarkTheme = (SettingsModelController.shared.getValueFor(.darkTheme) as? Bool) ?? false
                cell.isSwitchedOn = isDarkTheme
                
            default:
                break
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let parameter = content[indexPath.row].parameter {
            switch parameter {
            case .timeFormat:
                let ampm = UIAlertAction(title: NSLocalizedString("1PM", comment: ""), style: .default) { (action) in
                    SettingsModelController.shared.setValue(true, for: .timeFormat)
                    self.tableView.reloadData()
                }
                
                let twentyFour = UIAlertAction(title: NSLocalizedString("13:00", comment: ""), style: .default) { (action) in
                    SettingsModelController.shared.setValue(false, for: .timeFormat)
                    self.tableView.reloadData()
                }

                presentAlertView(content[indexPath.row].title, message: nil, style: .actionSheet, actions: [ampm, twentyFour], addCancelButton: true)
                break
                
            default:
                break
            }
        }
        
        tableView.reloadData()
    }
    
}

extension CommonSettingsViewController: SettingsTableViewCellDelegate {
    
    func settingsCell(_ cell: SettingsTableViewCell, switchValueChanged isOn: Bool) {
        guard
            let indexPath = tableView.indexPath(for: cell),
            let parameter = content[indexPath.row].parameter
            else { return }
        
        switch parameter {
        case .darkTheme:
            ThemeManager.setTheme(isOn ? .dark : .light)
        default:
            break
        }
    
        SettingsModelController.shared.setValue(isOn, for: parameter)
    }

    
}
