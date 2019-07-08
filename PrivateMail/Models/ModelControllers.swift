//
//  MenuModelController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

class ComposeMailModelController: NSObject {
    static let shared = ComposeMailModelController()
    var mail: APIMail = APIMail()
}


enum SettingsParameter {
    case timeFormat
    case syncFrequency
    case syncPeriod
    case lastRefresh
}

class SettingsModelController: NSObject {
    static let shared = SettingsModelController()
    
    override init() {
        if UserDefaults.standard.object(forKey: "userSettings") as? [String: Any] == nil {
            UserDefaults.standard.set([:] as! [String: Any], forKey: "userSettings")
        }
    }
    
    func getKeyFor(_ parameter: SettingsParameter) -> String {
        switch parameter {
        case .timeFormat:
            return "timeFormat"
        case .syncFrequency:
            return "syncFrequency"
        case .syncPeriod:
            return "syncPeriod"
        case .lastRefresh:
            return "lastRefresh"
        }
    }
    
    func getValueFor(_ parameter: SettingsParameter) -> Any? {
        let settings = UserDefaults.standard.object(forKey: "userSettings") as? [String: Any]
        let key = getKeyFor(parameter)
        
        return settings?[key]
    }
    
    func setValue(_ value: Any, for parameter: SettingsParameter) {
        var settings = UserDefaults.standard.object(forKey: "userSettings") as? [String: Any] ?? [:]
        let key = getKeyFor(parameter)
        
        settings[key] = value
        UserDefaults.standard.setValue(settings, forKey: "userSettings")
    }
}
