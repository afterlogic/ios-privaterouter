//
//  TwoFactorAuthController.swift
//  PrivateMail
//
//  Created by Alexander Orlov on 20.01.2020.
//  Copyright © 2020 PrivateRouter. All rights reserved.
//

import Foundation
import UIKit
import SVProgressHUD

class TwoFactorAuthConroller: UIViewController {
    
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var pinView: UIView!
    @IBOutlet var pinField: UITextField!
    @IBOutlet var verifyButton: UIAccentButton!
    @IBOutlet var cancelButton: UIAccentButton!
    var complete:(()->Void)?
    var login:String?
    var password:String?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillLayoutSubviews() {
        [pinView,verifyButton,cancelButton].forEach { (view) in
            view.layer.cornerRadius=view.frame.size.height / 2.0
        }
        cancelButton.backgroundColor = UIColor.gray
        descriptionLabel.textColor = UIColor.white
    }
    @IBAction func onVerify(_ sender: Any) {
        
        let pin = pinField.text
        SVProgressHUD.dismiss()
        if(pin?.isNotEmpty != true){
            SVProgressHUD.showInfo(withStatus: "Pin is Empty")
            return
        }
        SVProgressHUD.show()
        API.shared.twoFactorAuth(login: login!, password: password!, pin: pin!) { (success, error) in
            SVProgressHUD.dismiss()
            if let error = error {
                SVProgressHUD.showError(withStatus: error.localizedDescription)
            } else {
                if(success){
                    SVProgressHUD.show()
                    API.shared.getAccounts { (result, error) in
                        SVProgressHUD.dismiss()
                        if let error = error {
                            SVProgressHUD.showError(withStatus: error.localizedDescription)
                            return
                        }
                        
                        DispatchQueue.main.async {
                            self.dismiss(animated: false, completion:nil)
                            self.complete!()
                        }
                    }
                    
                }else{
                    SVProgressHUD.showInfo(withStatus: "Invalid PIN")
                }
            }
            
        }
    }
    
    @IBAction func onCancel(_ sender: Any) {
        DispatchQueue.main.async {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
}
