//
// Created by Александр Цикин on 18.11.2019.
// Copyright (c) 2019 PrivateRouter. All rights reserved.
//

import Foundation

extension Collection {
    
    // someVar.isNotEmpty is better reading than !someVar.isEmpty
    public var isNotEmpty: Bool { !isEmpty }
    
    public func associate<K: Hashable, V>(mapper: (Element) -> (key: K, value: V)) -> [K: V] {
        var dict = [K: V]()
        forEach {
            let entry = mapper($0)
            dict[entry.key] = entry.value
        }
        return dict
    }
    
}

extension Array {
    
    mutating func mutatingForEach(body: (inout Element) throws -> Void) rethrows  {
        for index in self.indices {
            try body(&self[index])
        }
    }
    
}