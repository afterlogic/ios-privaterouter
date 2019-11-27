//
// Created by Александр Цикин on 18.11.2019.
// Copyright (c) 2019 PrivateRouter. All rights reserved.
//

import Foundation

struct Strings {
    
    static var starred: String { .localized("starred") }
    
    static var noMessages: String { .localized("noMessages") }
    
    static var showMoreMessages: String { .localized("showMoreMessages") }

    static var userLimitsDescription: String { .localized("userLimitsDescription") }
    
    static var upgradeNow: String { .localized("upgradeNow") }
    
    static var backToLogin: String { .localized("backToLogin") }
    
    static var cantCompleteAction: String { .localized("cantCompleteAction") }
    
    static var failedToEditContact: String { .localized("failedToEditContact") }
    
    static var failedToSaveContact: String { .localized("failedToSaveContact") }
    
    static var somethingGoesWrong: String { .localized("somethingGoesWrong") }
    
    static var failedToDownloadFile: String { .localized("failedToDownloadFile") }
    
    static var wrongUrl: String { .localized("wrongUrl") }
    
    static var cantDeleteMessage: String { .localized("cantDeleteMessage") }
    
    static var error: String { .localized("error") }

}

extension String {
    
    public static func localized(_ name: String, comment: String = "") -> String {
        #if TARGET_INTERFACE_BUILDER
        let bundle = Bundle(for: Strings.Type)
        return NSLocalizedString(name, bundle: bundle, comment: comment)
        #else
        return NSLocalizedString(name, comment: comment)
        #endif
    }
    
}