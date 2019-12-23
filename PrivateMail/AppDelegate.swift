//
//  AppDelegate.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import KeychainAccess
import SVProgressHUD
import BouncyCastle_ObjC

let keychain = Keychain(service: "com.PrivateRouter.PrivateMail")

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
            
        SVProgressHUD.setMaximumDismissTimeInterval(0.6)
        StorageProvider.migrateIfNeeded()
        
        NotificationCenter.default.addObserver(self, selector: #selector(presentLoginViewController(notification:)), name: .failedToLogin, object: nil)
        
        JavaSecuritySecurity.addProvider(with: BCJceProviderBouncyCastleProvider())
        
        if keychain["AccessToken"] == nil {
            NotificationCenter.default.post(name: .failedToLogin, object: false)
        } else {
            if let currentUser = StorageProvider.shared.getCurrentUser() {
                API.shared.currentUser = currentUser
                NotificationCenter.default.post(name: .didRecieveUser, object: currentUser)
            }
            
            API.shared.getAccounts{(result, error) in
                if let error = error {
                    SVProgressHUD.showError(withStatus: error.localizedDescription)
                    return
                }
            }
        }
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {

    }

    func applicationDidEnterBackground(_ application: UIApplication) {

    }

    func applicationWillEnterForeground(_ application: UIApplication) {

    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        
    }

    func applicationWillTerminate(_ application: UIApplication) {

    }
    
    @objc func presentLoginViewController(notification: Notification) {
        DispatchQueue.main.async {
            if let loginVC = UIStoryboard.init(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController {
                DispatchQueue.main.async {
                    if let rootVC = self.window?.rootViewController as? UINavigationController {
                        rootVC.popToRootViewController(animated: false)
                        
                        self.window?.makeKeyAndVisible()
                        rootVC.present(loginVC, animated: notification.object == nil, completion: nil)
                    }
                }
            }
        }
    }
    
}

