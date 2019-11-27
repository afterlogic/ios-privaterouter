//
//  GroupsViewController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

class GroupsModelController: NSObject {
    static let shared = GroupsModelController()
    
    var selectedItem = ContactsGroupDB()
    var group = ContactsGroupDB()
}

class GroupsViewController: UIViewController {

    @IBOutlet var tableView: UITableView!
    
    var content: [ContactsGroupDB] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = NSLocalizedString("Groups", comment: "")
        navigationController?.navigationBar.barTintColor = UIColor(rgb: 0x6A0C40)
        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.tintColor = .white
        
        tableView.register(cellClass: GroupTableViewCell())
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView(frame: .zero)
                
        API.shared.getContactGroups { (result, error) in
            DispatchQueue.main.async {
                if let result = result {
//                    StorageProvider.shared.deleteGroups()
//                    StorageProvider.shared.saveContactsGroups(groups: result)
                    
                    self.content = result //StorageProvider.shared.getContactGroups()
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    @IBAction func closeButtonAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
}


extension GroupsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : content.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: GroupTableViewCell.cellID(), for: indexPath) as! GroupTableViewCell
        var group: ContactsGroupDB?
        
        if indexPath.section == 0 {
            group = ContactsGroupDB()
            group?.name = "Personal"
        } else {
            group = content[indexPath.row]
        }
        
        cell.titleLabel.text = group?.name
        cell.isSelected = group?.uuid == GroupsModelController.shared.selectedItem.uuid
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            GroupsModelController.shared.selectedItem = ContactsGroupDB()
        } else {
            GroupsModelController.shared.selectedItem = content[indexPath.row]
        }
        
        tableView.reloadData()
        
        NotificationCenter.default.post(name: .contactsViewShouldUpdate, object: nil)
        closeButtonAction(self)
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 1 {
            return "Groups"
        } else {
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        ThemeUtil.themeTableViewSectionHeader(view)
    }
    
}
