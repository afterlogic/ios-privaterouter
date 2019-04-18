//
//  API.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

extension Notification.Name {
    static let failedToLogin = Notification.Name("failedToLogin")
    static let didRecieveUser = Notification.Name("didRecieveUser")
}

class API: NSObject {
    
    static let shared = API()
    
    var currentUser: APIUser = APIUser()
    
    let delay = 0.4
    
    
    // MARK: - API Methods
    
    func login(login: String, password: String, completionHandler: @escaping (Bool, Error?) -> Void) {
        let parameters = ["Login": login, "Password": password]
        
        createTask(module: "Core", method: "Login", parameters: parameters) { (result, error) in
            
            if let error = error {
                completionHandler(false, error)
                return
            }
            
            if let result = result["Result"] {
                let res = result as! [String: String]
                let token = res["AuthToken"]
                
                keychain["AccessToken"] = token
                completionHandler(true, nil)
            } else {
                completionHandler(false, nil)
            }
        }
        
    }
    
    func logout(completionHandler: @escaping (Bool?, Error?) -> Void) {
        StorageProvider.shared.deleteAllMails()
        StorageProvider.shared.removeCurrentUserInfo()
        
        createTask(module: "Core", method: "Logout", parameters: [:]) { (result, error) in
            keychain["AccessToken"] = nil
            
            if let success = result["Result"] as? Bool {
                completionHandler(success, nil)
            } else {
                completionHandler(nil, error)
            }
        }
    }
    
    func getAccounts(completionHandler: @escaping ([[String: Any]]?, Error?) -> Void) {
        createTask(module: "Mail", method: "GetAccounts", parameters: [:]) { (result, error) in
            if let result = result["Result"] as? [[String: Any]] {
                self.currentUser = APIUser(input: result[0])
                StorageProvider.shared.saveCurrentUser(user: result[0])
                
                NotificationCenter.default.post(name: .didRecieveUser, object: self.currentUser)
                
                completionHandler(result, nil)
            } else {
                completionHandler(nil, error)
            }
        }
    }
    
    func getFolders(completionHandler: @escaping ([APIFolder]?, Error?) -> Void) {
        let parameters = [
            "AccountID": currentUser.id
            ] as [String : Any]
        
        createTask(module: "Mail", method: "GetFolders", parameters: parameters) { (result, error) in
            if let result = result["Result"] as? [String: Any] {
                if let folders = result["Folders"] as? [String: Any] {
                    if let collection = folders["@Collection"] as? [[String: Any]] {
                        var folders: [APIFolder] = []
                        
                        for item in collection {
                            let folder = APIFolder(input: item)
                            folders.append(folder)
                        }
                        
                        completionHandler(folders, nil)
                        return
                    }
                }
            }
            
            completionHandler(nil, error)
        }
    }
    
    func getFoldersInfo(folders: [APIFolder], completionHandler: @escaping ([APIFolder]?, Error?) -> Void) {
        
        var foldersName: [String] = []
        
        for folder in folders {
            if let folderName = folder.name {
                foldersName.append(folderName)
            }
        }
        
        let parameters = [
            "AccountID": currentUser.id,
            "Folders": foldersName
            ] as [String : Any]
        
        createTask(module: "Mail", method: "GetRelevantFoldersInformation", parameters: parameters) { (result, error) in
            if let result = result["Result"] as? [String: Any],
                let counts = result["Counts"] as? [String: [Any]] {
                
                var updatedFolders = folders
                
                for i in 0 ..< updatedFolders.count {
                    if let name = folders[i].name, let item = counts[name] {
                        if let totalCount = item[0] as? Int {
                            updatedFolders[i].messagesCount = totalCount
                        }
                        
                        if let unreadCount = item[1] as? Int {
                            updatedFolders[i].unreadCount = unreadCount
                        }
                        
                        if let hash = item[3] as? String {
                            updatedFolders[i].hash = hash
                        }
                    }
                }
                
                completionHandler(updatedFolders, nil)
            } else {
                completionHandler(nil, error)
            }
        }
    }
    
    func getMailsInfo(text: String, folder: String, completionHandler: @escaping ([[String: Any]]?, Error?) -> Void) {
        let parameters = [
            "AccountID": currentUser.id,
            "Folder": folder,
            "Search": text,
            ] as [String : Any]
        
        createTask(module: "Mail", method: "GetMessagesInfo", parameters: parameters) { (result, error) in
            if let result = result["Result"] as? [[String: Any]] {
                completionHandler(result, nil)
            } else {
                completionHandler(nil, error)
            }
        }
    }
    
    func getMailsList(text: String, folder: String, limit: Int, offset: Int, completionHandler: @escaping ([APIMail]?, Error?) -> Void) {
        let parameters = [
            "AccountID": currentUser.id,
            "Folder": folder,
            "Offset": offset,
            "Limit": limit,
            "Search": text,
            "Filters": "",
            "UseThreading": true
            ] as [String : Any]

        createTask(module: "Mail", method: "GetMessages", parameters: parameters) { (result, error) in
            if let result = result["Result"] as? [String: Any] {
                if let mailsDict = result["@Collection"] as? [[String: Any]] {
                    var mails: [APIMail] = []

                    for mailDict in mailsDict {
                        mails.append(APIMail(input: mailDict))
                    }

                    completionHandler(mails, nil)
                } else {
                    completionHandler(nil, error)
                }
            } else {
                completionHandler(nil, error)
            }
        }
    }
    
    func getMail(mail: APIMail, completionHandler: @escaping (APIMail?, Error?) -> Void) {
        let parameters = [
            "AccountID": currentUser.id,
            "Folder": mail.folder ?? "",
            "Uid": mail.uid ?? -1
            ] as [String : Any]
        
        createTask(module: "Mail", method: "GetMessage", parameters: parameters) { (result, error) in
            if let result = result["Result"] as? [String: Any] {
                let mail = APIMail(input: result)
                
                StorageProvider.shared.saveMail(mail: mail)
                completionHandler(mail, nil)
            } else {
                completionHandler(nil, error)
            }
        }
    }
    
    func getMailsBodiesList(uids: [Int], folder: String, completionHandler: @escaping ([APIMail]?, Error?) -> Void) {
        let parameters = [
            "AccountID": currentUser.id,
            "Folder": folder,
            "Uids": uids
            ] as [String : Any]
        
        if uids.count == 0 {
            completionHandler([], nil)
            return
        }
        
        createTask(module: "Mail", method: "GetMessagesBodies", parameters: parameters) { (result, error) in
            if let result = result["Result"] as? [[String: Any]] {
                var mails: [APIMail] = []
                
                for input in result {
                    let mail = APIMail(input: input)
                    mails.append(mail)
                }
                
                StorageProvider.shared.saveMails(mails: mails, completionHandler: { (finished) in
                    completionHandler(mails, nil)
                })
            } else {
                completionHandler(nil, error)
            }
        }
    }
    
    func sendMail(mail: APIMail, completionHandler: @escaping (Bool?, Error?) -> Void) {
        let parameters = [
            "AccountID": currentUser.id,
            "FetcherID": "",
            "IdentityID": currentUser.id,
            "DraftInfo": [],
            "DraftUid": "",
            "To": mail.to?.first ?? "",
            "Cc": mail.cc?.first ?? "",
            "Bcc": mail.bcc?.first ?? "",
            "Subject": mail.subject ?? "",
            "Text": mail.body ?? "",
            "IsHtml": false,
            "Importance": 3,
            "SendReadingConfirmation": false,
            "Attachments": mail.attachments ?? [],
            "InReplyTo": "",
            "References": "",
            "Sensitivity": 0,
            "SentFolder": "Sent",
            "DraftFolder": "Drafts",
            "ConfirmFolder": "",
            "ConfirmUid": ""
            ] as [String : Any]
        
        createTask(module: "Mail", method: "SendMessage", parameters: parameters) { (result, error) in
            if let result = result["Result"] as? Bool {
                completionHandler(result, nil)
            } else {
                completionHandler(false, error)
            }
        }
    }
    
    func setMailSeen(mail: APIMail, completionHandler: @escaping (Bool?, Error?) -> Void) {
        let parameters = [
            "AccountID": currentUser.id,
            "Folder": mail.folder ?? "",
            "Uids": mail.uid ?? -1,
            "SetAction": true
            ] as [String : Any]
        
        createTask(module: "Mail", method: "SetMessagesSeen", parameters: parameters) { (result, error) in
            if let result = result["Result"] as? Bool {
                completionHandler(result, error)
            } else {
                completionHandler(nil, error)
            }
        }
    }
    
    func setMailFlagged(mail: APIMail, flagged: Bool, completionHandler: @escaping (Bool?, Error?) -> Void) {
        let parameters = [
            "AccountID": currentUser.id,
            "Folder": mail.folder ?? "",
            "Uids": mail.uid ?? -1,
            "SetAction": flagged
            ] as [String : Any]
        
        createTask(module: "Mail", method: "SetMessageFlagged", parameters: parameters) { (result, error) in
            if let result = result["Result"] as? Bool {
                completionHandler(result, error)
            } else {
                completionHandler(nil, error)
            }
        }
    }
    
    func deleteMessage(mail: APIMail, completionHandler: @escaping (Bool?, Error?) -> Void) {
        let parameters = [
            "AccountID": currentUser.id,
            "Folder": mail.folder ?? "",
            "Uids": mail.uid ?? -1,
            ] as [String : Any]
        
        createTask(module: "Mail", method: "DeleteMessages", parameters: parameters) { (result, error) in
            if let result = result["Result"] as? Bool {
                completionHandler(result, error)
            } else {
                completionHandler(nil, error)
            }
        }
    }
    
    
    // MARK: - Helpers
    
    func httpBodyFrom(dictionary: [String: String]) -> Data? {
        var resultParts: [String] = []
        
        for key in dictionary.keys {
            resultParts.append(key + "=" + dictionary[key]!)
        }
        
        for i in 0 ..< resultParts.count {
            var part = resultParts[i]
            part = part.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
            part = part.replacingOccurrences(of: "&", with: "%26")
            part = part.replacingOccurrences(of: "+", with: "%2B")
            
            resultParts[i] = part
        }
        
        let result = resultParts.joined(separator: "&")
        return result.data(using: .utf8)
    }
    
    func generateRequest(module: String, method: String, parameters: [String: Any]) -> URLRequest? {
        
        var server = "webmail"
        
//        if let test = UserDefaults.standard.object(forKey: "Test") as? Bool {
//            if test {
                server = "test"
//            }
//        }
        
        var request = URLRequest(url: URL(string: "https://\(server).afterlogic.com/?/Api/")!)
        
        request.httpMethod = "POST"
        
        if let token = keychain["AccessToken"] {
            request.addValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        }
        
        var body = ["Module": module, "Method": method]
        
        var success = false
        
        if let parametersData = try? JSONSerialization.data(withJSONObject: parameters, options: []) {
            if let parametersText = String(data: parametersData, encoding: .utf8) {
                body["Parameters"] = parametersText
                success = true
            }
        }
        
        if !success {
            return nil
        }
        
        if let bodyData = httpBodyFrom(dictionary: body) {
            request.httpBody = bodyData
            return request
        }
        
        return nil
    }
    
    func createTask(module: String, method: String, parameters: [String: Any], completionHandler: @escaping ([String: Any], Error?) -> Void) {
        
        DispatchQueue.main.async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
        }
        
        if let request = generateRequest(module: module, method: method, parameters: parameters) {
            URLSession.shared.dataTask(with: request) { (data, response, error) in
                DispatchQueue.main.async {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                }
                
                if let error = error {
                    completionHandler([:], error)
                    return
                }
                
                if let data = data {
                    do {
                        let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String: Any]
                        
                        if let result = json["ErrorCode"] {
                            let res = result as! Int
                            
                            if res == 101 || res == 102 {
                                keychain["AccessToken"] = nil
                                NotificationCenter.default.post(name: .failedToLogin, object: nil)
                            }
                            
                            completionHandler([:], nil)
                            return
                        }
                        
                        completionHandler(json, nil)
                        
                    } catch let error as NSError {
                        completionHandler([:], error)
                    }
                }
                
                }.resume()
        } else {
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
            
            completionHandler([:], nil)
        }
        
    }
}
