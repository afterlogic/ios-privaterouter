//
// Created by Александр Цикин on 19.11.2019.
// Copyright (c) 2019 PrivateRouter. All rights reserved.
//

import Foundation
import UIKit

extension UILabel {
    
    // Localizable text
    @IBInspectable var localizedText: String? {
        set { text = newValue.map { .localized($0) } }
        get { text }
    }
    
}