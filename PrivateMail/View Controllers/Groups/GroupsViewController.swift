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
    var selectedStorage = ApiStorage("personal")
    var selectedItem = ContactsGroupDB()
    var group = ContactsGroupDB()
}

class GroupsViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    
    var groups: [ContactsGroupDB] = []
    var storage: [ApiStorage]=[]
    
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
        
        API.shared.getContactStorage { (result, error) in
            if let result = result {
                self.storage = result
            }
            API.shared.getContactGroups { (result, error) in
                DispatchQueue.main.async {
                    if let result = result {
                        self.groups = result
                        self.tableView.reloadData()
                    }
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
        return section == 0 ? storage.count : groups.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: GroupTableViewCell.cellID(), for: indexPath) as! GroupTableViewCell
        var group: ContactsGroupDB?
        if indexPath.section == 0 {
            let item = storage[indexPath.row]
            group = ContactsGroupDB()
            group?.name = item.id!
            cell.isSelected = item.id == GroupsModelController.shared.selectedStorage.id
        } else {
            group = groups[indexPath.row]
            cell.isSelected = group?.uuid == GroupsModelController.shared.selectedItem.uuid
        }
       
        cell.titleLabel.text = group?.name
       
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            GroupsModelController.shared.selectedStorage = storage[indexPath.row]
            GroupsModelController.shared.selectedItem = ContactsGroupDB()
        } else {
            GroupsModelController.shared.selectedItem = groups[indexPath.row]
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
