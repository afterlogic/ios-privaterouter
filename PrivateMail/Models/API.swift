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
    
    override init() {
        super.init()
        
        if let token = keychain["AccessToken"] {
            setCookie(key: "AuthToken", value: token as AnyObject)
        }
    }
    
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
                self.removeCookies()
                self.setCookie(key: "AuthToken", value: token as AnyObject)
                
                completionHandler(true, nil)
            } else {
                completionHandler(false, nil)
            }
        }
    }
    
    func logout(completionHandler: @escaping (Bool?, Error?) -> Void) {
        removeCookies()

        StorageProvider.shared.deleteAllFolders(completionHandler: {})
        StorageProvider.shared.removeCurrentUserInfo()
        MenuModelController.shared.folders = []
        StorageProvider.shared.syncingFolders = []
        
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
                StorageProvider.shared.deleteMailsNotFromUser(self.currentUser)
                
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
            if let folderName = folder.fullName {
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
                
                for i in 0..<updatedFolders.count {
                    if let folderName = updatedFolders[i].fullName, let item = counts[folderName] {
                        if let totalCount = item[0] as? Int {
                            updatedFolders[i].messagesCount = totalCount
                        }
                        
                        if let unreadCount = item[1] as? Int {
                            updatedFolders[i].unreadCount = unreadCount
                        }
                        
                        if let hash = item[3] as? String {
                            let systemFolders = ["INBOX", "Sent", "Drafts"]
                            let currentFolder = MenuModelController.shared.selectedFolder
                            
                            let oldHash = updatedFolders[i].hash ?? ""
                            
//                            print("Folder: \(folderName) Old: \(oldHash) New: \(hash)")
                            
                            if oldHash != hash
                                && (systemFolders.contains(folderName)
                                    || folderName == currentFolder) {
                                
                                if !StorageProvider.shared.syncingFolders.contains(folderName) {
                                    StorageProvider.shared.getMails(text: "", folder: folderName, limit: nil, additionalPredicate: nil, completionHandler: { (result) in
                                        MenuModelController.shared.setMailsForFolder(mails: result, folder: folderName)
                                        
                                        StorageProvider.shared.syncFolderIfNeeded(folder: folderName, expectedHash: hash, oldMails: result, beganSyncing: {
                                        })
                                    })
                                }
                            } else {
                                if folderName == currentFolder {
                                    API.shared.getMailsInfo(text: "", folder: folderName, completionHandler: { (result, error) in
                                        if let result = result {
                                            let sortedResult = result.sorted(by: { (first, second) -> Bool in
                                                let firstUID = Int(first["uid"] as? String ?? "-1") ?? -1
                                                let secondUID = Int(second["uid"] as? String ?? "-1") ?? -1
                                                
                                                return firstUID > secondUID
                                            })
                                            
                                            var index = 0
                                            var mails = MenuModelController.shared.mailsForFolder(name: folderName)
                                            
                                            for item in sortedResult {
                                                if let uidText = item["uid"] as? String,
                                                    let uid = Int(uidText),
                                                    let flags = item["flags"] as? [String] {
                                                    
                                                    for i in index ..< mails.count {
                                                        if mails[i].uid == uid {
                                                            let isSeen = flags.contains("\\seen")
                                                            let isFlagged = flags.contains("\\flagged")
                                                            
                                                            if mails[i].isSeen != isSeen || mails[i].isFlagged != isFlagged {
                                                                mails[i].isSeen = isSeen
                                                                mails[i].isFlagged = isFlagged
                                                                
                                                                let group = DispatchGroup()
                                                                group.enter()
                                                                
                                                                StorageProvider.shared.updateMailFlags(mail: mails[i], completionHandler: {
                                                                    group.leave()
                                                                })
                                                                
                                                                group.wait()
                                                            }
                                                                
                                                            index = i + 1
                                                            break
                                                        } else if mails[i].uid ?? -1 > uid {
                                                            break
                                                        }
                                                    }
                                                }
                                            }
                                            
                                            MenuModelController.shared.setMailsForFolder(mails: mails, folder: folderName)
                                            
                                            NotificationCenter.default.post(name: .mainViewControllerShouldRefreshData, object: nil)
                                        }
                                    })
                                }
                            }
                            
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
            "Text": mail.htmlBody ?? "",
            "IsHtml": true,
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
    
    func moveMessage(mail: APIMail, toFolder: String, completionHandler: @escaping (Bool?, Error?) -> Void) {
        let parameters = [
            "AccountID": currentUser.id,
            "Folder": mail.folder ?? "",
            "ToFolder": toFolder,
            "Uids": mail.uid ?? -1,
            ] as [String : Any]
        
        createTask(module: "Mail", method: "MoveMessages", parameters: parameters) { (result, error) in
            if let result = result["Result"] as? Bool {
                completionHandler(result, error)
            } else {
                completionHandler(nil, error)
            }
        }
    }

    func setEmailSafety(mail: APIMail, completionHandler: @escaping (Bool?, Error?) -> Void) {
        let parameters = [
            "AccountID": currentUser.id,
            "Email": mail.from?.first ?? ""
            ] as [String : Any]
        
        createTask(module: "Mail", method: "SetEmailSafety", parameters: parameters) { (result, error) in
            if let result = result["Result"] as? Bool {
                completionHandler(result, error)
            } else {
                completionHandler(nil, error)
            }
        }
    }
    
    func downloadAttachementWith(url: URL, completionHandler: @escaping (Data?, Error?) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        guard let token = keychain["AccessToken"] else {
            completionHandler(nil, nil)
            return
        }
        
        request.addValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        
        DispatchQueue.main.async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
        }
        
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
            completionHandler(data, error)
            }.resume()
    }
    
    
    // MARK: - Helpers
    
    func httpBodyFrom(dictionary: [String: String]) -> Data? {
        var resultParts: [String] = []
        
        for key in dictionary.keys {
            resultParts.append(key + "=" + dictionary[key]!)
        }
        
        for i in 0..<resultParts.count {
            var part = resultParts[i]
            part = part.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
            part = part.replacingOccurrences(of: "&", with: "%26")
            part = part.replacingOccurrences(of: "+", with: "%2B")
            
            resultParts[i] = part
        }
        
        let result = resultParts.joined(separator: "&")
        return result.data(using: .utf8)
    }
    
    func getServerURL() -> String {
        var server = "webmail"
        
        //        if let test = UserDefaults.standard.object(forKey: "Test") as? Bool {
        //            if test {
        server = "test"
        //            }
        //        }
        
        return "https://\(server).afterlogic.com/"
    }
    
    func setCookie(key: String, value: AnyObject) {
        let cookieProps = [
            .domain: "test.afterlogic.com",
            .path: "/",
            .name: key,
            .value: value,
            .secure: "TRUE",
            .expires: NSDate(timeIntervalSinceNow: TimeInterval(60 * 60 * 24 * 365))
            ] as [HTTPCookiePropertyKey : Any]
        
        let cookie = HTTPCookie(properties: cookieProps)
        HTTPCookieStorage.shared.setCookie(cookie!)
    }
    
    func removeCookies() {
        guard let cookies = HTTPCookieStorage.shared.cookies(for: URL(string: "test.afterlogic.com")!) else {
            return
        }
        
        for cookie in cookies {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }
    
    func generateRequest(module: String, method: String, parameters: [String: Any]) -> URLRequest? {
        var request = URLRequest(url: URL(string: "\(getServerURL())?/Api/")!)
        
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
