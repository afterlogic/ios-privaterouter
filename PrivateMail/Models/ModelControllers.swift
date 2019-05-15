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
