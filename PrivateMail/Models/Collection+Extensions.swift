//
// Created by Александр Цикин on 18.11.2019.
// Copyright (c) 2019 PrivateRouter. All rights reserved.
//

import Foundation

extension Collection {
    
    // someVar.isNotEmpty is better reading than !someVar.isEmpty
    var isNotEmpty: Bool { !isEmpty }
    
}