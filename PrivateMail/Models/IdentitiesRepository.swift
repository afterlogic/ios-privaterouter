//
// Created by Александр Цикин on 26.11.2019.
// Copyright (c) 2019 PrivateRouter. All rights reserved.
//

import Foundation

class IdentitiesRepository {
    
    static var shared = IdentitiesRepository()
    
    private(set) var identities: [APIIdentity] = []
    
    func updateIdentities(completionHandler: @escaping (Error?) -> Void) {
        API.shared.getIdentities { (identities, error) in
            defer {
                completionHandler(error)
            }
        
            guard let identities = identities else {
                return
            }
            
            self.identities = identities
            NotificationCenter.default.post(name: .identitiesChanged, object: identities)
        }
    }
    
}

extension Notification.Name {
    
    static var identitiesChanged: Notification.Name {
        Notification.Name("IdentitiesRepository.identitiesChanged")
    }
    
}