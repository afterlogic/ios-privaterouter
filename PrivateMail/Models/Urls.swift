//
// Created by Александр Цикин on 20.11.2019.
// Copyright (c) 2019 PrivateRouter. All rights reserved.
//

import Foundation

struct Urls {
    
    static var domain: String {
        baseURL.host ?? ""
    }
    
    static var baseURL: URL = URL(string: "https://test.afterlogic.com")!
    
    static var upgradePlan: URL {
        URL(string: "\(baseURL)supporttickets.php")!
    }
    
}