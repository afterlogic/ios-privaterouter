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
    
    @IBOutlet weak var upgradeNow: UIButton!
    @IBOutlet weak var backToLoginButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        upgradeNow.layer.cornerRadius = upgradeNow.frame.size.height / 2.0
        backToLoginButton.layer.cornerRadius = backToLoginButton.frame.size.height / 2.0
    }

    
    @IBAction func backToLoginTapped(_ sender: Any) {
        dismiss(animated: true)
    }
    
}


