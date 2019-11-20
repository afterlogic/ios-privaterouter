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
        removeCookies()
        
        createTask(module: "Core", method: "Login", parameters: parameters) { (result, error) in
            
            if let error = error {
                completionHandler(false, error)
                return
            }
            
            if let result = result["Result"] {
                let res = result as! [String: String]
                let token = res["AuthToken"]
                
                keychain["AccessToken"] = token
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
                
                for i in 0 ..< updatedFolders.count {
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
                            
                            if oldHash != hash
                                && (systemFolders.contains(folderName)
                                    || folderName == currentFolder) || (folderName == currentFolder && SettingsModelController.shared.currentSyncingPeriodMultiplier > 1.1) {
                                
                                if !StorageProvider.shared.syncingFolders.contains(folderName) {
                                    StorageProvider.shared.getMails(text: "", folder: folderName, limit: nil, additionalPredicate: nil, completionHandler: { (result) in
                                        MenuModelController.shared.setMailsForFolder(mails: result, folder: folderName)
                                        
                                        StorageProvider.shared.syncFolderIfNeeded(folder: folderName, expectedHash: hash, oldMails: result, beganSyncing: {
                                        })
                                    })
                                }
                            } else {
                                if folderName == currentFolder {
                                    API.shared.getMailsInfo(folder: folderName, completionHandler: { (result, error) in
                                        if let result = result {
                                            let sortedResult = result.sorted(by: { (first, second) -> Bool in
                                                let firstUID = Int(first["uid"] as? String ?? "-1") ?? -1
                                                let secondUID = Int(second["uid"] as? String ?? "-1") ?? -1
                                                
                                                return firstUID > secondUID
                                            })
                                            
                                            var index = 0
                                            var mails = MenuModelController.shared.mailsForFolder(name: folderName)
                                            
                                            for item in sortedResult {
                                                var uid = item["uid"] as? Int

                                                if uid == nil {
                                                    if let uidText = item["uid"] as? String {
                                                        uid = Int(uidText)
                                                    }
                                                }
                                                
                                                if uid != nil {
                                                    let flags = item["flags"] as? [String] ?? []
                                                    
                                                    for i in index ..< mails.count {
                                                        if mails[i].uid == uid {
                                                            let isSeen = flags.contains("\\seen")
                                                            let isFlagged = flags.contains("\\flagged")
                                                            let isAnswered = flags.contains("\\answered")
                                                            let isForwarded = flags.contains("$forwarded")
                                                            let isDeleted = flags.contains("\\deleted")
                                                            let isDraft = flags.contains("\\draft")
                                                            let isRecent = flags.contains("\\recent")
                                                            
                                                            var threadUID = item["threadUID"] as? Int
                                                            
                                                            if threadUID == nil {
                                                                let threadUIDText = item["threadUID"] as? String
                                                                threadUID = Int(threadUIDText ?? "")
                                                            }

                                                            if mails[i].isSeen != isSeen
                                                                || mails[i].isFlagged != isFlagged
                                                                || mails[i].threadUID != threadUID
                                                                || mails[i].isAnswered != isAnswered
                                                                || mails[i].isForwarded != isForwarded
                                                                || mails[i].isDeleted != isDeleted
                                                                || mails[i].isDraft != isDraft
                                                                || mails[i].isRecent != isRecent
                                                            {
                                                                mails[i].isSeen = isSeen
                                                                mails[i].isFlagged = isFlagged
                                                                mails[i].threadUID = threadUID
                                                                mails[i].isAnswered = isAnswered
                                                                mails[i].isForwarded = isForwarded
                                                                mails[i].isDeleted = isDeleted
                                                                mails[i].isDraft = isDraft
                                                                mails[i].isRecent = isRecent
                                                                
                                                                let group = DispatchGroup()
                                                                group.enter()
                                                                
                                                                StorageProvider.shared.updateMailFlags(mail: mails[i], completionHandler: {
                                                                    group.leave()
                                                                })
                                                                
                                                                group.wait()
                                                            }
                                                                
                                                            index = i + 1
                                                            break
                                                        } else if mails[i].uid ?? -1 > uid ?? -1 {
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
    
    func getMailsInfo(folder: String, completionHandler: @escaping ([[String: Any]]?, Error?) -> Void) {
        var searchString = ""
        
        if let syncingPeriod = SettingsModelController.shared.getValueFor(.syncPeriod) as? Double, syncingPeriod > 0.0 {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy.MM.dd"
            
            let date = Date(timeIntervalSinceNow: -syncingPeriod * 60.0 * SettingsModelController.shared.currentSyncingPeriodMultiplier)

            searchString = "date:\(dateFormatter.string(from: date))/"
        }
        
        let parameters = [
            "AccountID": currentUser.id,
            "Folder": folder,
            "Search": searchString,
            "UseThreading": true,
//            "SortBy": "date"
            ] as [String : Any]
        
        createTask(module: "Mail", method: "GetMessagesInfo", parameters: parameters) { (result, error) in
            if let result = result["Result"] as? [[String: Any]] {
                var unthreaded: [[String: Any]] = []
                
                for var item in result {
                    if let thread = item["thread"] as? [[String: Any]] {
                        for var mail in thread {
                            mail["threadUID"] = item["uid"]
                            unthreaded.append(mail)
                        }
                        
                        item["threadUID"] = item["uid"]
                    }
                    
                    item.removeValue(forKey: "thread")
                    unthreaded.append(item)
                }
                
                completionHandler(unthreaded, nil)
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
    
    func getContactsInfo(group: String = "", completionHandler: @escaping ([APIContact]?, ContactsGroupDB?, Error?) -> Void) {
        let groupDB = ContactsGroupDB()
        groupDB.accountID = currentUser.id
        groupDB.uuid = group
        
        let parameters = [
            "Storage": "Personal",
            "GroupUUID": group
        ]
        
        createTask(module: "Contacts", method: "GetContactsInfo", parameters: parameters) { (result, error) in
            if let result = result["Result"] as? [String: Any] {
                if let cTag = result["CTag"] as? Int {
                    groupDB.cTag = cTag
                }
                
                var contacts: [APIContact] = []
                
                if let info = result["Info"] as? [[String: Any]] {
                    for item in info {
                        contacts.append(APIContact(input: item))
                    }
                }
                
                completionHandler(contacts, groupDB, nil)
            } else {
                completionHandler(nil, nil, error)
            }
        }
    }
    
    func getContacts(contacts: [APIContact], group: ContactsGroupDB, completionHandler: @escaping ([APIContact]?, Error?) -> Void) {
        var uids: [String] = []
        
        for contact in contacts {
            if let uuid = contact.uuid {
                uids.append(uuid)
            }
        }
        
        let parameters = [
            "Storage": "Personal",
            "Uids": uids,
            "GroupUUID": group.uuid
            ] as [String : Any]
        
        createTask(module: "Contacts", method: "GetContactsByUids", parameters: parameters) { (result, error) in
            if let result = result["Result"] as? [[String: Any]] {
                var contacts: [APIContact] = []
                
                for item in result {
                    contacts.append(APIContact(input: item))
                }
                
                completionHandler(contacts, nil)
            } else {
                completionHandler(nil, error)
            }
        }
    }
    
    func getContactGroups(completionHandler: @escaping ([ContactsGroupDB]?, Error?) -> Void) {
        createTask(module: "Contacts", method: "GetGroups", parameters: [:]) { (result, error) in
            if let result = result["Result"] as? [[String: Any]] {
                var groups: [ContactsGroupDB] = []
                
                for item in result {
                    let group = ContactsGroupDB()
                    
                    if let value = item["UserID"] as? Int {
                        group.userID = value
                    }
                    
                    if let name = item["Name"] as? String {
                        group.name = name
                    }
                    
                    if let uuid = item["UUID"] as? String {
                        group.uuid = uuid
                    }
                    
                    if let uuid = item["ParentUUID"] as? String {
                        group.parentUuid = uuid
                    }
                    
                    if let isOrganization = item["IsOrganization"] as? Bool {
                        group.isOrganization = isOrganization
                    }
                    
                    if let value = item["Email"] as? String {
                        group.email = value
                    }
                    
                    if let value = item["Company"] as? String {
                        group.company = value
                    }
                    
                    if let value = item["Street"] as? String {
                        group.street = value
                    }
                    
                    if let value = item["City"] as? String {
                        group.city = value
                    }
                    
                    if let value = item["State"] as? String {
                        group.state = value
                    }
                    
                    if let value = item["Zip"] as? String {
                        group.zip = value
                    }
                    
                    if let value = item["Country"] as? String {
                        group.county = value
                    }
                    
                    if let value = item["Phone"] as? String {
                        group.phone = value
                    }
                    
                    if let value = item["Fax"] as? String {
                        group.fax = value
                    }

                    if let value = item["Web"] as? String {
                        group.web = value
                    }
                    
                    groups.append(group)
                }
                
                completionHandler(groups, error)
            } else {
                completionHandler(nil, error)
            }
        }
    }
    
    func sendMail(mail: APIMail, isSaving: Bool = false, completionHandler: @escaping (Bool?, Error?) -> Void) {
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
            "Attachments": mail.attachmentsToSend ?? [:],
            "InReplyTo": "",
            "References": "",
            "Sensitivity": 0,
            "SentFolder": "Sent",
            "DraftFolder": "Drafts",
            "ConfirmFolder": "",
            "ConfirmUid": ""
            ] as [String : Any]
        
        createTask(module: "Mail", method: isSaving ? "SaveMessage" : "SendMessage", parameters: parameters) { (result, error) in
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
    
    func moveMessage(mail: APIMail, toFolder: String, completionHandler: @escaping (Bool?, Error?) -> Void) {
        moveMessages(mails: [mail], toFolder: toFolder, completionHandler: completionHandler)
    }

    func moveMessages(mails: [APIMail], toFolder: String, completionHandler: @escaping (Bool?, Error?) -> Void) {
        if mails.count == 0 {
            completionHandler(false, nil)
        }
        
        var uids: [String] = []
        
        for mail in mails {
            if let uid = mail.uid {
                uids.append(String(uid))
            }
        }
        
        let parameters = [
            "AccountID": currentUser.id,
            "Folder": mails[0].folder ?? "",
            "ToFolder": toFolder,
            "Uids": uids.joined(separator: ", "),
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
    
    func saveContact(contact: APIContact, edit: Bool, completionHandler: @escaping ([String: String]?, Error?) -> Void) {
        let parameters = [
            "Contact": contact.asJSON
            ] as [String : Any]
        
        let method = edit ? "UpdateContact" : "CreateContact"
        
        createTask(module: "Contacts", method: method, parameters: parameters) { (result, error) in
            if let result = result["Result"] as? [String: String] {
                completionHandler(result, error)
            } else {
                completionHandler(nil, error)
            }
        }
    }
    
    func saveGroup(group: ContactsGroupDB, edit: Bool, completionHandler: @escaping ([String: String]?, Error?) -> Void) {
        let parameters = [
            "Group": group.asJSON()
            ] as [String : Any]
        
        let method = edit ? "UpdateGroup" : "CreateGroup"
        
        createTask(module: "Contacts", method: method, parameters: parameters) { (result, error) in
            if let result = result["Result"] as? [String: String] {
                completionHandler(result, error)
            } else {
                completionHandler(nil, nil)
            }
        }
    }
    
    func deleteMessage(mail: APIMail, completionHandler: @escaping (Bool?, Error?) -> Void) {
        deleteMessages(mails: [mail], completionHandler: completionHandler)
    }
    
    func deleteMessages(mails: [APIMail], completionHandler: @escaping (Bool?, Error?) -> Void) {
        if mails.count == 0 {
            completionHandler(false, nil)
        }
        
        var uids: [String] = []
        
        for mail in mails {
            if let uid = mail.uid {
                uids.append(String(uid))
            }
        }
        
        let parameters = [
            "AccountID": currentUser.id,
            "Folder": mails[0].folder ?? "",
            "Uids": uids.joined(separator: ", "),
            ] as [String : Any]
        
        createTask(module: "Mail", method: "DeleteMessages", parameters: parameters) { (result, error) in
            if let result = result["Result"] as? Bool {
                completionHandler(result, error)
            } else {
                completionHandler(nil, error)
            }
        }
    }

    func deleteGroup(group: ContactsGroupDB, completionHandler: @escaping ([String: String]?, Error?) -> Void) {
        let parameters = [
            "UUID": group.uuid
            ] as [String : Any]
                
        createTask(module: "Contacts", method: "DeleteGroup", parameters: parameters) { (result, error) in
            if let result = result["Result"] as? [String: String] {
                completionHandler(result, error)
            } else {
                completionHandler(nil, nil)
            }
        }
    }
    
    func uploadAttachment(fileName: String, completionHandler: @escaping ([String: Any]?, Error?) -> Void) {
        guard let token = keychain["AccessToken"] else {
            completionHandler(nil, nil)
            return
        }
        
        let boundary = "----Boundary-\(UUID().uuidString)"
        
        let parameters = [
            [
                "name": "Module",
                "value": "Mail"
            ],
            [
                "name": "Method",
                "value": "UploadAttachment"
            ],
            [
                "name": "Parameters",
                "value": "{\"AccountID\": \(currentUser.id)}"
            ],
            [
                "name": "jua-uploader",
                "fileName": fileName,
                "content-type": "image/*"
            ]
        ]
        
        do {
            let body = NSMutableData()
            
            for param in parameters {
                let paramName = param["name"]!
                body.appendString("--\(boundary)\r\n")
                body.appendString("Content-Disposition:form-data; name=\"\(paramName)\"")
                
                if let filename = param["fileName"] {
                    let contentType = param["content-type"]!
                    
                    let fileContent = try Data(contentsOf: URL(string: fileName)!)

                    body.appendString("; filename=\"\(filename)\"\r\n")
                    body.appendString("Content-Type: \(contentType)\r\n\r\n")
                    body.append(fileContent)
                    body.appendString("\r\n")
                } else if let paramValue = param["value"] {
                    body.appendString("\r\n\r\n\(paramValue)\r\n")
                }
            }
            
            body.appendString("--\(boundary)")
            
            let request = NSMutableURLRequest(url: URL(string: "\(Urls.baseURL)?/Api/")!,
                                              cachePolicy: .useProtocolCachePolicy,
                                              timeoutInterval: 10.0)
            
            let headers = [
                "Authorization": "Bearer \(token)",
                "Accept": "*/*",
                "Cache-Control": "no-cache",
                "Accept-Encoding": "gzip, deflate",
                "Content-Type": "multipart/form-data; boundary=\(boundary)",
                "Content-Length": "\(body.length)",
                "Connection": "keep-alive",
                "cache-control": "no-cache"
            ]
            
            
            request.httpMethod = "POST"
            request.allHTTPHeaderFields = headers
            request.httpBody = body as Data
            
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            
            let session = URLSession.shared
            let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
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
            })
            
            dataTask.resume()
        } catch {
            completionHandler(nil, nil)
            return
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
    
    func setCookie(key: String, value: AnyObject) {
        let cookieProps = [
            .domain: Urls.domain,
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
        guard let cookies = HTTPCookieStorage.shared.cookies else {
            return
        }
        
        for cookie in cookies {
            if cookie.domain == Urls.domain {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
    }
    
    func generateRequest(module: String, method: String, parameters: [String: Any]) -> URLRequest? {
        var request = URLRequest(url: URL(string: "\(Urls.baseURL)?/Api/")!)
        
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
                
                guard var data = data else { return }
                
                #if DEBUG
                if let dataString = String(data: data, encoding: .utf8),
                   let jsonOpenIndex = dataString.range(of: "{\"")?.lowerBound {
                    
                    var jsonString = dataString[jsonOpenIndex...]
                    data = jsonString.data(using: .utf8)!
                }
                #endif
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as! [String: Any]
        
                    if let errorCode = json["ErrorCode"] as? Int {
            
                        if errorCode == 101 || errorCode == 102 {
                            keychain["AccessToken"] = nil
                            NotificationCenter.default.post(name: .failedToLogin, object: nil)
                        }
                        
                        let errorMessage = json["ErrorMessage"] as? String
                        
                        let error = APIError(code: errorCode, message: errorMessage)
                        
                        completionHandler([:], error)
                        return
                    } else {
                        completionHandler(json, nil)
                    }
        
                } catch let error as NSError {
                    #if DEBUG
                    if let rawDataString = String(data: data, encoding: .utf8) {
                        print("Response parsing failed. Response:\n\(rawDataString)")
                    }
                    #endif
                    completionHandler([:], error)
                }
                
            }.resume()
        } else {
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
            
            completionHandler([:], nil)
        }
        
    }
    
    func createBody(data: String, mimeType: String, filename: String) -> Data {
        let body = NSMutableData()
        
        let boundary = "Boundary-\(UUID().uuidString)"
        let boundaryPrefix = "--\(boundary)\r\n"
        
        body.appendString(boundaryPrefix)
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
//        body.append(data)
        body.appendString("\r\n")
        body.appendString("--".appending(boundary.appending("--")))
        
        return body as Data
    }
}


extension NSMutableData {
    func appendString(_ string: String) {
        let data = string.data(using: String.Encoding.utf8, allowLossyConversion: false)
        append(data!)
    }
}

struct APIError: Error {
    
    let code: Int
    let message: String?
    
    var localizedDescription: String {
        message ?? "\(code) Error has occurred."
    }
    
}
