//
//  FolderTableViewCell.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

class FolderTableViewCell: UITableViewCell, UITableViewCellExtensionProtocol {
    
    @IBOutlet var iconImageView: UIImageView!
    @IBOutlet var expandImageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var unreadLabel: UILabel!
    @IBOutlet var unreadView: UIView!
    
    @IBOutlet var unreadCountConstraint: NSLayoutConstraint!
    @IBOutlet var expandIconConstraint: NSLayoutConstraint!
    @IBOutlet var sideConstraint: NSLayoutConstraint!
    
    var folder: APIFolder?
    
    var subFoldersCount = 0 {
        didSet {
            if subFoldersCount > 0 {
                expandImageView.isHidden = false
                expandIconConstraint.isActive = true
            } else {
                expandImageView.isHidden = true
                expandIconConstraint.isActive = false
            }
            
            contentView.layoutIfNeeded()
        }
    }
    
    var unreadCount = 0 {
        didSet {
            unreadLabel.text = "\(unreadCount)"
            
            if unreadCount == 0 {
                unreadView.isHidden = true
                unreadCountConstraint.isActive = false
            } else {
                unreadView.isHidden = false
                unreadCountConstraint.isActive = true
            }
            
            contentView.layoutIfNeeded()
        }
    }
    
    static func cellID() -> String {
        return "FolderTableViewCell"
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.unreadView.layer.cornerRadius = 10.0
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    func setSelected(_ selected: Bool) {        
        if selected {
            backgroundColor = ColorScheme.accentColor
            titleLabel.textColor = .white
            unreadLabel.textColor = .white
            iconImageView.tintColor = .white
            expandImageView.tintColor = .white
        } else {
            backgroundColor = .white
            titleLabel.textColor = .black
            unreadLabel.textColor = .black
            iconImageView.tintColor = .black
            expandImageView.tintColor = .black
        }
        
        #if DEBUG
        if StorageProvider.shared.syncingFolders.contains(folder?.fullName ?? "") {
            backgroundColor = .blue
        }
        #endif
    }
    
}
