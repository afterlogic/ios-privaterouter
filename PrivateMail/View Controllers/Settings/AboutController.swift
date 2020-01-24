//
//  AboutController.swift
//  PrivateMail
//
//  Created by Alexander Orlov on 24.01.2020.
//  Copyright © 2020 PrivateRouter. All rights reserved.
//

import Foundation
import UIKit
import SwiftTheme
import QuartzCore

class AboutController: UIViewController {
    
    @IBOutlet weak var appImage: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var termsLabel: UILabel!
    @IBOutlet weak var privacyLabel: UILabel!
    override func viewDidLoad() {
        navigationItem.title = NSLocalizedString("Common", comment: "")
        let bundle = Bundle.main
        let version = bundle.infoDictionary!["CFBundleShortVersionString"] as! String
        let build = bundle.infoDictionary!["CFBundleVersion"] as! String
        versionLabel.text="Version \(version)+\(build)"
    }
    override func viewWillLayoutSubviews() {
        let onPrivacy = UITapGestureRecognizer(target: self, action: #selector(AboutController.onPrivacy))
        privacyLabel.isUserInteractionEnabled = true
        privacyLabel.addGestureRecognizer(onPrivacy)
        
        let onTerms = UITapGestureRecognizer(target: self, action: #selector(AboutController.onTerms))
        termsLabel.isUserInteractionEnabled = true
        termsLabel.addGestureRecognizer(onTerms)
        
        privacyLabel.textColor = UIColor.purple
        termsLabel.textColor = UIColor.purple
        versionLabel.textColor = UIColor.gray
    }
 
    @objc
    func onPrivacy(sender:UITapGestureRecognizer) {
        let url=URL(string:"https://privatemail.com/privacy.php")!
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    @objc
    func onTerms(sender:UITapGestureRecognizer) {
        let url=URL(string:"https://privatemail.com/terms.php")!
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
