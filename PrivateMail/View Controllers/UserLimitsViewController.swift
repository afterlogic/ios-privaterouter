//
//  UserLimitsViewController.swift
//  PrivateMail
//
//  Created by Александр Цикин on 20.11.2019.
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import Foundation
import UIKit

class UserLimitsViewController: UIViewController {

    @IBOutlet weak var cancelButton: UIAccentButton!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    override func viewWillLayoutSubviews() {
        descriptionLabel.textColor = UIColor.white
        cancelButton.layer.cornerRadius = cancelButton.frame.size.height / 2.0
    }
    

    @IBAction func cancel(_ sender: Any) {
          dismiss(animated: true)
    }
    
}


