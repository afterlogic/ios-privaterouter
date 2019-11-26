//
// Created by Александр Цикин on 26.11.2019.
// Copyright (c) 2019 PrivateRouter. All rights reserved.
//

import Foundation
import SVProgressHUD

public struct ProgressHUD {
    
    public enum Result {
        case error(Error)
        case dismiss
        case info(String)
    }
    
    public typealias CompletionHandler = (_ result: ProgressHUD.Result) -> Void
    
    public typealias ErrorCompletionHandler = (_ error: Error?) -> Void
    
    public static func showWithCompletion() -> CompletionHandler {
        SVProgressHUD.show()
        
        return { (result) in
            SVProgressHUD.dismiss()
            
            switch result {
            case .error(let error):
                SVProgressHUD.showError(withStatus: error.localizedDescription)
            case .info(let message):
                SVProgressHUD.showInfo(withStatus: message)
            default:
                break
            }
            
        }
    }
    
    public static func showWithErrorCompletion() -> ErrorCompletionHandler {
        let completion = showWithCompletion()
        return {
            if let error = $0 {
                completion(.error(error))
            } else {
                completion(.dismiss)
            }
        }
    }
    
}