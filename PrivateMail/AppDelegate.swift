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
import ObjectivePGP
import SwiftTheme

let keychain = Keychain(service: "com.PrivateRouter.PrivateMail")

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        #if DEBUG
        nextTheme()
        #endif
        
        applyTheme()
            
        SVProgressHUD.setMaximumDismissTimeInterval(1)
        StorageProvider.migrateIfNeeded()
        
        NotificationCenter.default.addObserver(self, selector: #selector(presentLoginViewController(notification:)), name: .failedToLogin, object: nil)
        
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
    
    private func applyTheme() {
        
        UITabBar.appearance().theme_backgroundColor = .secondarySurface
        UITabBar.appearance().theme_barTintColor = .secondarySurface
        UITabBar.appearance().theme_tintColor = .accent
        
        UIToolbar.appearance().theme_backgroundColor = .secondarySurface
        UIToolbar.appearance().theme_barTintColor = .secondarySurface
        UIToolbar.appearance().theme_tintColor = .accent
        
        UINavigationBar.appearance().theme_backgroundColor = .primary
        UINavigationBar.appearance().theme_barTintColor = .primary
        UINavigationBar.appearance().theme_tintColor = .onPrimary
        
        UILabel.appearance().theme_textColor = .onSurfaceMajorText
    
        UIButton.appearance().theme_tintColor = .accent
    
        UIAccentButton.appearance().theme_backgroundColor = .accent
        UIAccentButton.appearance().theme_tintColor = .onAccent
        UIAccentButton.appearance().theme_setTitleColor(.onAccent, forState: .normal)
        
        UISwitch.appearance().theme_onTintColor = .accent
        
        UITableView.appearance().theme_backgroundColor = .surface
        UITableView.appearance().theme_separatorColor = .surface
        UITableView.appearance().tableFooterView = nil
        
        UITableViewCell.appearance().theme_backgroundColor = .surface
        
        if #available(iOS 9.0, *) {
            UIButton.appearance(whenContainedInInstancesOf: [UINavigationBar.self]).theme_tintColor = .onPrimary
            UILabel.appearance(whenContainedInInstancesOf: [UINavigationBar.self]).theme_textColor = .onPrimary
            
            UILabel.appearance(whenContainedInInstancesOf: [UITableViewHeaderFooterView.self]).theme_textColor = .onSurfaceMajorText
            
            UILabel.appearance(whenContainedInInstancesOf: [UITextField.self]).theme_textColor = nil
            UILabel.appearance(whenContainedInInstancesOf: [UITextField.self]).textColor = .black
        }
    }
    
    #if DEBUG
    private var currentTheme = "Light"
    
    func nextTheme() {
    
        ThemeManager.setTheme(plistName: currentTheme, path: .mainBundle)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.currentTheme = self.currentTheme == "Light" ? "Dark" : "Light"
            self.nextTheme()
        }
    }
    #endif

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

