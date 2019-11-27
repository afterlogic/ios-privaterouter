//
// Created by Александр Цикин on 27.11.2019.
// Copyright (c) 2019 PrivateRouter. All rights reserved.
//

import Foundation

struct Config {
    
    let autodiscoverUrl: URL
    
    static var standard: Config {
        fromPlist(name: "Config")
    }
    
    static func fromPlist(name: String, in bundle: Bundle = .main) -> Config {
        let fileUrl = bundle.url(forResource: name, withExtension: "plist")!
        let data = try! Data(contentsOf: fileUrl)
        let result = try! PropertyListSerialization.propertyList(from: data, options: [], format: nil) as! [String: Any]
        
        return Config(
            autodiscoverUrl: URL(string: result["AutodiscoverUrl"] as! String)!)
    }
    
}