//
//  FolderTableViewCell.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import SwiftTheme

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
    
    var theme_iconTintColor: ThemeColorPicker = .onSurfaceMajorText
    
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
            theme_backgroundColor = .accent
            titleLabel.theme_textColor = .onAccent
            unreadLabel.theme_textColor = .onAccent
            iconImageView.theme_tintColor = .onAccent
            expandImageView.theme_tintColor = .onAccent
        } else {
            theme_backgroundColor = .surface
            titleLabel.theme_textColor = .onSurfaceMajorText
            unreadLabel.theme_textColor = .onSurfaceMajorText
            iconImageView.theme_tintColor = theme_iconTintColor
            expandImageView.theme_tintColor = .onSurfaceMajorText
        }
        
        #if DEBUG
        if StorageProvider.shared.syncingFolders.contains(folder?.fullName ?? "") {
            backgroundColor = .blue
        }
        #endif
    }
    
}
