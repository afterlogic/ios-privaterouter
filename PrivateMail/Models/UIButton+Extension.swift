//
// Created by Александр Цикин on 19.11.2019.
// Copyright (c) 2019 PrivateRouter. All rights reserved.
//

import Foundation
import UIKit

extension UIButton {
    
    // Localizable text
    @IBInspectable var localizedTitle: String? {
        set {
            guard localizedTitle != "" else { return }
            setTitle(newValue.map { .localized($0) } , for: .normal)
        }
        get { title(for: .normal) }
    }
    
}