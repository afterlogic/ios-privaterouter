//
//  SyncSettingsViewController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

class SyncSettingsViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    
    let frequencyOptions = [
        -1: NSLocalizedString("never", comment: ""),
        1: NSLocalizedString("1 minute", comment: ""),
        5: NSLocalizedString("5 minutes", comment: ""),
        60: NSLocalizedString("1 hour", comment: ""),
        2 * 60: NSLocalizedString("2 hours", comment: ""),
        24 * 60: NSLocalizedString("daily", comment: ""),
        30 * 24 * 60: NSLocalizedString("monthly", comment: ""),
    ]
    
    let periodOptions = [
        -1: NSLocalizedString("all time", comment: ""),
        30 * 24 * 60: NSLocalizedString("1 month", comment: ""),
        2 * 30 * 24 * 60: NSLocalizedString("2 months", comment: ""),
        3 * 30 * 24 * 60: NSLocalizedString("3 months", comment: ""),
        6 * 30 * 24 * 60: NSLocalizedString("6 months", comment: ""),
        12 * 30 * 24 * 60: NSLocalizedString("1 year", comment: "")
    ]
    
    let content: [SettingsItem] = [
        SettingsItem(title: NSLocalizedString("Sync frequency", comment: ""), segue: nil, parameter: .syncFrequency),
        SettingsItem(title: NSLocalizedString("Sync period", comment: ""), segue: nil, parameter: .syncPeriod)
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Sync", comment: "")
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(cellClass: SettingsTableViewCell())
        tableView.tableFooterView = UIView(frame: .zero)
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
}

extension SyncSettingsViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return content.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.cellID(), for: indexPath) as! SettingsTableViewCell
        
        cell.titleLabel.text = content[indexPath.row].title
        cell.style = .leftText
        
        if let parameter = content[indexPath.row].parameter {
            switch parameter {
                
            case .syncFrequency:
                let frequency = (SettingsModelController.shared.getValueFor(.syncFrequency) as? Int) ?? -1
                
                cell.leftTextLabel.text = frequencyOptions[frequency] ?? NSLocalizedString("\(String(frequency)) minutes", comment: "")
                break
                
            case .syncPeriod:
                let period = (SettingsModelController.shared.getValueFor(.syncPeriod) as? Int) ?? -1
                
                cell.leftTextLabel.text = periodOptions[period] ?? NSLocalizedString("\(String(period)) minutes", comment: "")
                break
                
            default:
                break
                
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let parameter = content[indexPath.row].parameter {
            switch parameter {
                
            case .syncFrequency:
                var actions: [UIAlertAction] = []
                let frequencies = [Int](frequencyOptions.keys).sorted()
                
                for frequency in frequencies {
                    let action = UIAlertAction(title: frequencyOptions[frequency], style: .default) { (action) in
                        SettingsModelController.shared.setValue(frequency, for: .syncFrequency)
                        SettingsModelController.shared.setValue(Date(timeIntervalSince1970: 0.0), for: .lastRefresh)
                        self.tableView.reloadData()
                    }
                    
                    actions.append(action)
                }
                
                presentAlertView(content[indexPath.row].title, message: nil, style: .actionSheet, actions: actions, addCancelButton: true)
                break
                
            case .syncPeriod:
                var actions: [UIAlertAction] = []
                let periods = [Int](periodOptions.keys).sorted()
                
                for period in periods {
                    let action = UIAlertAction(title: periodOptions[period], style: .default) { (action) in
                        SettingsModelController.shared.setValue(period, for: .syncPeriod)
                        self.tableView.reloadData()
                    }
                    
                    actions.append(action)
                }
                
                presentAlertView(content[indexPath.row].title, message: nil, style: .actionSheet, actions: actions, addCancelButton: true)
                break
                
            default:
                break
                
            }
        }
        
        tableView.reloadData()
    }
    
}
