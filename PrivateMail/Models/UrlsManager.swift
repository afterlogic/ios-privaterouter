//
// Created by Александр Цикин on 20.11.2019.
// Copyright (c) 2019 PrivateRouter. All rights reserved.
//

import Foundation

class UrlsManager {
    
    static var shared: UrlsManager = UrlsManager()
    
    var baseUrl: URL? {
        set {
            if let url = newValue {
                keychain["Host"] = "\(url)"
            } else {
                try? keychain.remove("Host")
            }
            NotificationCenter.default.post(name: .baseUrlChanged, object: self)
        }
        get {
            if let urlString = keychain["Host"] {
                return URL(string: urlString)
            } else {
                return nil
            }
        }
    }
    
    var domain: String {
        baseUrl?.host ?? ""
    }
    
    var upgradePlan: URL? {
        guard let baseUrl = baseUrl else {
            return nil
        }
        return URL(string: "\(baseUrl)supporttickets.php")!
    }
    
}

extension Notification.Name {
    
    static var baseUrlChanged: Notification.Name {
        Notification.Name(rawValue: "UrlsManager.baseUrlChanged")
    }
    
}