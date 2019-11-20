//
// Created by Александр Цикин on 20.11.2019.
// Copyright (c) 2019 PrivateRouter. All rights reserved.
//

import Foundation

struct Urls {
    
    static var domain: String {
        "test.afterlogic.com" //"webmail.afterlogic.com" //"privatemail.com"
    }
    
    static var baseURL: URL {
        URL(string: "https://\(domain)/")!
    }
    
    static var upgradePlan: URL {
        URL(string: "\(baseURL)supporttickets.php")!
    }
    
}