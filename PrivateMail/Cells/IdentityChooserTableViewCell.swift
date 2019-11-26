//
//  IdentityChooserTableViewCell.swift
//  PrivateMail
//
//  Created by Александр Цикин on 26.11.2019.
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import Foundation
import UIKit
import SwiftTheme

class IdentityChooserTableViewCell: UITableViewCell {
    
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var valueLabel: UILabel!
    
    var valueText: String? {
        get { valueLabel.text }
        set { valueLabel.text = newValue }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        theme_backgroundColor = .surface
        titleLabel.theme_textColor = .onSurfaceMinorText
        valueLabel.theme_textColor = .onSurfaceMajorText
    }
    
}

extension IdentityChooserTableViewCell: UITableViewCellExtensionProtocol { }
