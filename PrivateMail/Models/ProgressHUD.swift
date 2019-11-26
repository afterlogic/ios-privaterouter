//
// Created by Александр Цикин on 26.11.2019.
// Copyright (c) 2019 PrivateRouter. All rights reserved.
//

import Foundation
import SVProgressHUD

public struct ProgressHUD {
    
    public enum Result {
        case error(String)
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
            case .error(let message):
                SVProgressHUD.showError(withStatus: message)
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
                completion(.error(error.localizedDescription))
            } else {
                completion(.dismiss)
            }
        }
    }
    
}