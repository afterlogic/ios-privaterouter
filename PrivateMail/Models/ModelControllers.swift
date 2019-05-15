//
//  MenuModelController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import RealmSwift

class MenuModelController: NSObject {
    static let shared = MenuModelController()
    
    var folders: [APIFolder] = []
    
    var selectedFolder: String = "INBOX"
    
    func foldersToShow() -> [APIFolder] {
        var result: [APIFolder] = []
        
        for folder in expandedFolders(folders: folders) {
            if folder.isSubscribed ?? true {
                result.append(folder)
            }
        }
        
        return result
    }
    
    func expandedFolders(folders: [APIFolder]) -> [APIFolder] {
        var result: [APIFolder] = []
        
        for folder in folders {
            var newFolder = folder
            newFolder.subFolders = nil
            
            result.append(newFolder)
            
            if let subfolders = folder.subFolders {
                let expandedFoldersList = expandedFolders(folders: subfolders)
                
                for i in 0..<expandedFoldersList.count {
                    var subfolder = expandedFoldersList[i]
                    subfolder.depth += 1
                    result.append(subfolder)
                }
            }
        }
        
        return result
    }
    
    func compressedFolders(folders: [APIFolder]) -> [APIFolder] {
        var result: [APIFolder] = folders
        
        var index = -1
        var deepestFolder: APIFolder = APIFolder()
        deepestFolder.depth = -1
        
        for i in 0..<result.count {
            let folder = result[i]
            
            if folder.depth > deepestFolder.depth {
                deepestFolder = folder
                index = i
            }
        }
        
        if deepestFolder.depth > 0 {
            result.remove(at: index)
            
            var pathComponents = deepestFolder.fullName?.components(separatedBy: "/")
            pathComponents?.removeLast()
            let expectedFolderPath = pathComponents?.joined(separator: "/")
            
            for i in 0..<result.count {
                var folder = result[i]
                
                if folder.fullName == expectedFolderPath {
                    deepestFolder.depth = 0
                    
                    if var subFolders = folder.subFolders {
                        subFolders.append(deepestFolder)
                        folder.subFolders = subFolders
                    } else {
                        folder.subFolders = [deepestFolder]
                    }
                    
                    result[i] = folder
                    break
                }
            }
            
            return compressedFolders(folders: result)
        }
        
        return result
    }
    
    func updateFolders(newFolders: [APIFolder]) {
        var newFolders = newFolders
        
        for i in 0..<newFolders.count {
            newFolders[i].mails = mailsForFolder(name: newFolders[i].name)
        }
        
        folders = newFolders
    }
    
    func mailsForCurrentFolder() -> [APIMail] {
        return mailsForFolder(name: selectedFolder)
    }
    
    func mailsForFolder(name: String?) -> [APIMail] {
        for folder in expandedFolders(folders: folders) {
            if folder.fullName == name {
                return folder.mails
            }
        }
        
        return []
    }
    
    func setMailsForCurrentFolder(mails: [APIMail]) {
        var folders = expandedFolders(folders: self.folders)
        
        for i in 0..<folders.count {
            if folders[i].fullName == selectedFolder {
                folders[i].mails = mails
                
                self.folders = compressedFolders(folders: folders)
                return
            }
        }
    }
    
    func removeMail(mail: APIMail) {
        var folders = expandedFolders(folders: self.folders)
        
        for i in 0..<folders.count {
            var folder = folders[i]
            
            if folder.fullName == mail.folder {
                var mails = folder.mails
                
                mails.removeAll { (item) -> Bool in
                    return item.uid == mail.uid
                }
                
                folder.mails = mails
                folders[i] = folder
            }
        }
        
        self.folders = compressedFolders(folders: folders)
    }
    
}


class ComposeMailModelController: NSObject {
    static let shared = ComposeMailModelController()
    var mail: APIMail = APIMail()
}

class MailDB: Object {
    @objc dynamic var uid = -1
    @objc dynamic var accountID = -1
    @objc dynamic var folder = ""
    @objc dynamic var subject = ""
    @objc dynamic var body = ""
    @objc dynamic var sender = ""
    @objc dynamic var isSeen = true
    @objc dynamic var isFlagged = false
    @objc dynamic var date = Date()
    @objc dynamic var attachments = ""
    @objc dynamic var data = NSData()
}

protocol StorageProviderDelegate: NSObjectProtocol {
    func updateHeaderWith(progress: String?, folder: String)
    
    func updateTableView(mails: [APIMail], folder: String)
}


class StorageProvider: NSObject {
    static let shared = StorageProvider()
    
    let realm = try! Realm()
    var notificationToken: NotificationToken?
    var syncingFolders: [String] = []
    var uids: [String: [APIMail]] = [:]
    var delegate: StorageProviderDelegate?
    var results: Results<MailDB>?
    var isFetching = false
    var fetchingID = 0
    
    static func migrateIfNeeded() {
        let config = Realm.Configuration(deleteRealmIfMigrationNeeded: true)
        Realm.Configuration.defaultConfiguration = config
    }
    
    func syncFolderIfNeeded(folder: String, oldMails: [APIMail], beganSyncing: @escaping () -> Void) {
        if syncingFolders.contains(folder) {
            beganSyncing()
            return
        }
        
        syncingFolders.append(folder)
        
        API.shared.getMailsInfo(text: "", folder: folder) { (result, error) in
            if let result = result {
                var mails: [APIMail] = []
                
                for item in result {
                    if let uidText = item["uid"] as? String, let uid = Int(uidText) {
                        var mail = APIMail()
                        mail.uid = uid
                        mail.folder = folder
                        
                        if let flags = item["flags"] as? [String] {
                            mail.isSeen = flags.contains("\\seen")
                            mail.isFlagged = flags.contains("\\flagged")
                        }
                        
                        mails.append(mail)
                    }
                }
                
                mails = mails.sorted(by: { (first, second) -> Bool in
                    return (first.uid ?? -1) > (second.uid ?? -1)
                })
                
                var newMails = oldMails
                
                newMails.removeAll(where: { (mail) -> Bool in
                    return mail.folder != folder
                })
                
                var uidsToDelete: [Int] = []
                
                let group = DispatchGroup()
                group.enter()
                
                DispatchQueue.main.async {
                    self.removeDeletedMails(mails: mails, completionHandler: { (deletedUids) in
                        uidsToDelete = deletedUids
                        group.leave()
                    })
                }
                
                group.wait()
                
                for uid in uidsToDelete {
                    newMails.removeAll(where: { (mail) -> Bool in
                        return mail.uid ?? -1 == uid
                    })
                }
                
                self.uids[folder] = mails
                
                // Check if not need to sync
                var isEqual = true
                
                for mail in mails {
                    var isFound = false
                    
                    for i in 0..<newMails.count {
                        if mail.uid == newMails[i].uid {
                            var shouldUpdateFlags = false
                            
                            if let isSeen = mail.isSeen {
                                if newMails[i].isSeen != isSeen {
                                    newMails[i].isSeen = isSeen
                                    shouldUpdateFlags = true
                                }
                            }
                            
                            if let isFlagged = mail.isFlagged {
                                if newMails[i].isFlagged != isFlagged {
                                    newMails[i].isFlagged = isFlagged
                                    shouldUpdateFlags = true
                                }
                            }
                            
                            if shouldUpdateFlags {
                                self.updateMailFlags(mail: mail)
                            }
                            
                            isFound = true
                            break
                        }
                    }
                    
                    isEqual = isEqual && isFound
                }
                
                beganSyncing()
                
                // Finish syncing if nothing to update
                if isEqual {
                    if let index = self.syncingFolders.firstIndex(of: folder) {
                        self.syncingFolders.remove(at: index)
                    }
                    
                    self.delegate?.updateTableView(mails: newMails, folder: folder)
                    return
                }
                
                var mailsDB: [APIMail] = []
                
                group.enter()
                
                self.getMails(text: "", folder: folder, limit: nil, additionalPredicate: nil) { (res) in
                    mailsDB = res
                    group.leave()
                }
                
                group.wait()
                
                newMails = mailsDB
                self.delegate?.updateTableView(mails: newMails, folder: folder)
                
                var parts: [[Int]] = []
                var uids: [Int] = []
                
                for mail in mails {
                    var found = false
                    
                    if mailsDB.count > 0 {
                        if let first = mailsDB.first {
                            if mail.uid ?? -1 > first.uid ?? -1 {
                                found = true
                            }
                        }
                        
                        if let last = mailsDB.last {
                            if mail.uid ?? -1 < last.uid ?? -1 {
                                found = true
                            }
                        }
                    } else {
                        found = true
                    }
                    
                    if found {
                        uids.append(mail.uid ?? -1)
                        
                        if uids.count == 50 {
                            parts.append(uids)
                            uids = []
                        }
                    }
                }
                
                if uids.count > 0 {
                    parts.append(uids)
                }
                
                DispatchQueue.global(qos: .background).async {
                    var progress: String?
                    var totalCount = mailsDB.count
                    
                    if totalCount != mails.count {
                        progress = NSLocalizedString("Syncing... (\(totalCount)/\(mails.count))", comment: "")
                    }
                    
                    self.delegate?.updateHeaderWith(progress: progress, folder: folder)
                    
                    for part in parts {
                        totalCount += part.count
                        
                        if self.syncingFolders.contains(folder) {
                            group.enter()
                            
                            API.shared.getMailsBodiesList(uids: part, folder: folder, completionHandler: { (result, error) in
                                if let result = result {
                                    newMails.append(contentsOf: result)
                                    newMails.sort(by: { (a, b) -> Bool in
                                        return (a.uid ?? -1) > (b.uid ?? -1)
                                    })
                                }
                                
                                group.leave()
                            })
                            
                            group.wait()
                            
                            progress = NSLocalizedString("Syncing... (\(totalCount)/\(mails.count))", comment: "")
                            
                            if self.syncingFolders.contains(folder) {
                                self.delegate?.updateHeaderWith(progress: progress, folder: folder)
                                self.delegate?.updateTableView(mails: newMails, folder: folder)
                            }
                        } else {
                            if let index = self.syncingFolders.firstIndex(of: folder) {
                                self.syncingFolders.remove(at: index)
                            }
                            
                            progress = nil
                            break
                        }
                    }
                    
                    if let index = self.syncingFolders.firstIndex(of: folder) {
                        self.syncingFolders.remove(at: index)
                    }
                    
                    self.delegate?.updateHeaderWith(progress: nil, folder: folder)
                }
            } else {
                if let index = self.syncingFolders.firstIndex(of: folder) {
                    self.syncingFolders.remove(at: index)
                }
 
                beganSyncing()
            }
        }
        
    }
    
    func stopSyncingCurrentFolder() {
        if let index = syncingFolders.firstIndex(of: MenuModelController.shared.selectedFolder) {
            syncingFolders.remove(at: index)
        }
    }
    
    func saveCurrentUser(user: [String: Any]) {
        UserDefaults.standard.set(user, forKey: "currentUser")
    }
    
    func getCurrentUser() -> APIUser? {
        if let currentUser = UserDefaults.standard.object(forKey: "currentUser") as? [String: Any] {
            let user = APIUser(input: currentUser)
            
            return user
        }
        
        return nil
    }
    
    func saveFoldersList(folders: [APIFolder]) {
        var list: [String] = []
        
        for folder in folders {
            if let folderName = folder.name, let isSubscribed = folder.isSubscribed {
                if isSubscribed {
                    list.append(folderName)
                }
            }
        }
        
        UserDefaults.standard.set(list, forKey: "folders")
    }
    
    func getFoldersList() -> [APIFolder]? {
        if let folders = UserDefaults.standard.object(forKey: "folders") as? [String] {
            var result: [APIFolder] = []
            
            for item in folders {
                let folder = APIFolder(input: ["Name": item])
                result.append(folder)
            }
            
            return result
        }
        
        return nil
    }
    
    func removeCurrentUserInfo() {
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "folders")
    }
    
    func saveMail(mail: APIMail) {
        if API.shared.currentUser.id > 0,
            let uid = mail.uid,
            let input = mail.input,
            let folder = mail.folder,
            let subject = mail.subject,
            let body = mail.plainBody,
            let date = mail.date,
            let isSeen = mail.isSeen,
            let isFlagged = mail.isFlagged {
            
            let mailDB = MailDB()
            mailDB.uid = uid
            mailDB.folder = folder
            mailDB.accountID = API.shared.currentUser.id
            mailDB.body = body
            mailDB.subject = subject
            mailDB.date = date
            mailDB.isSeen = isSeen
            mailDB.isFlagged = isFlagged
            
            if let attachments = mail.attachments {
                var attachmentsNames = ""
                
                for attachment in attachments {
                    if let name = attachment["FileName"] as? String {
                        attachmentsNames += name
                    }
                }
                
                mailDB.attachments = attachmentsNames
            }
            
            let data = NSKeyedArchiver.archivedData(withRootObject: input)
            mailDB.data = NSData(data: data)
            
            DispatchQueue.main.async {
                self.containsMail(mail: mail, completionHandler: { (mail) in
                    try! self.realm.write {
                        if let mail = mail {
                            mail.isSeen = mailDB.isSeen
                            mail.isFlagged = mailDB.isFlagged
                        } else {
                            self.realm.add(mailDB)
                        }
                    }
                })
            }
        }
    }
    
    func saveMails(mails: [APIMail], completionHandler: @escaping (Bool) -> Void) {
        var mailsDB: [MailDB] = []
        
        for mail in mails {
            if API.shared.currentUser.id > 0,
                let uid = mail.uid,
                let input = mail.input,
                let folder = mail.folder,
                let subject = mail.subject,
                let body = mail.plainBody,
                let date = mail.date,
                let isSeen = mail.isSeen,
                let isFlagged = mail.isFlagged {
                
                let mailDB = MailDB()
                mailDB.uid = uid
                mailDB.folder = folder
                mailDB.accountID = API.shared.currentUser.id
                mailDB.body = body
                mailDB.subject = subject
                mailDB.date = date
                mailDB.isSeen = isSeen
                mailDB.isFlagged = isFlagged
                
                if let attachments = mail.attachments {
                    var attachmentsNames = ""
                    
                    for attachment in attachments {
                        if let name = attachment["FileName"] as? String {
                            attachmentsNames += name
                        }
                    }
                    
                    mailDB.attachments = attachmentsNames
                }
                
                let data = NSKeyedArchiver.archivedData(withRootObject: input)
                mailDB.data = NSData(data: data)
                mailsDB.append(mailDB)
            }
        }
        
        DispatchQueue.main.async {
            try! self.realm.write {
                self.realm.add(mailsDB)
                completionHandler(true)
            }
        }
    }
    
    func loadBodiesFor(mails: [APIMail], limit: Int, folder: String, completionHandler: @escaping (Bool) -> Void) {
        var uids: [Int] = []
        let loadingLimit = limit

        getMails(text: "", folder: folder, limit: nil, additionalPredicate: nil) { (result) in
            for mail in mails {
                var found = false
                
                if result.count > 0 {
                    if let first = result.first {
                        if mail.uid ?? -1 > first.uid ?? -1 {
                            found = true
                        }
                    }
                    
                    if let last = result.last {
                        if mail.uid ?? -1 < last.uid ?? -1 {
                            found = true
                        }
                    }
                } else {
                    found = true
                }
                    
                if found {
                    uids.append(mail.uid ?? -1)
                    
                    if uids.count == loadingLimit {
                        break
                    }
                }
            }

            var progress: String? = NSLocalizedString("Syncing... (\(result.count)/\(mails.count))", comment: "")
            
            if uids.count > 0 {
                API.shared.getMailsBodiesList(uids: uids, folder: folder, completionHandler: { (result, error) in
                    if self.syncingFolders.contains(folder) {
                        if let uids = self.uids[folder] {
                            self.loadBodiesFor(mails: uids, limit: loadingLimit, folder: folder, completionHandler: { (success) in
                            })
                        }
                    }
                    
                    completionHandler(true)
                })
            } else {
                if let index = self.syncingFolders.firstIndex(of: folder) {
                    self.syncingFolders.remove(at: index)
                }
                
                progress = nil
                completionHandler(true)
            }
            
            self.delegate?.updateHeaderWith(progress: progress, folder: folder)
        }
    }
    
    func getMails(text: String, folder: String, limit: Int?, additionalPredicate: String?, completionHandler: @escaping ([APIMail]) -> Void) {
        let referenceDate = Date()
        let fetchID = fetchingID
        fetchingID += 1
        
        print("Fetching began: ID\(fetchID)")
        
        isFetching = true
        var mails: [APIMail] = []
        
        DispatchQueue.main.async {
            var predicate = """
            (
            folder = \"\(folder)\"
            AND accountID = \(API.shared.currentUser.id)
            )
            """
            
            if text.count > 0 {
                predicate += """
                AND (subject CONTAINS[cd] \"\(text)\"
                OR body CONTAINS[cd] \"\(text)\"
                OR attachments CONTAINS[cd] \"\(text)\")
                """
            }
            
            if let addPart = additionalPredicate {
                predicate += " " + addPart
            }
            
            let result = self.realm.objects(MailDB.self).filter(predicate).sorted(byKeyPath: "uid", ascending: false)
            
            for i in 0..<min(result.count, limit ?? result.count) {
                let object = result[i]
                let input = NSKeyedUnarchiver.unarchiveObject(with: Data(referencing: object.data))
                
                if let input = input as? [String : Any] {
                    var mail = APIMail(input: input)
                    mail.isSeen = object.isSeen
                    mail.isFlagged = object.isFlagged
                    
                    mails.append(mail)
                }
            }
            
            self.isFetching = false
            completionHandler(mails)
            print("Fetching ID\(fetchID) time: \(Date().timeIntervalSince(referenceDate))")
        }
    }
    
    func removeDeletedMails(mails: [APIMail], completionHandler: @escaping ([Int]) -> Void) {
        var ids: [Int] = []
        
        for mail in mails {
            if let id = mail.uid {
                ids.append(id)
            }
        }
        
        let predicate = """
        (
        folder = \"\(MenuModelController.shared.selectedFolder)\"
        AND accountID = \(API.shared.currentUser.id)
        AND NOT (uid IN %@)
        )
        """
        
        let result = self.realm.objects(MailDB.self).filter(predicate, ids).sorted(byKeyPath: "date", ascending: false)
        
        var deletedUids: [Int] = []
        
        for item in result {
            deletedUids.append(item.uid)
        }
        
        try! self.realm.write {
            self.realm.delete(result)
        }
        
        completionHandler(deletedUids)
    }
    
    func containsMail(mail: APIMail, completionHandler: @escaping (MailDB?) -> Void) {
        DispatchQueue.main.async {
            if let uid = mail.uid, let folder = mail.folder {
                let result = self.realm.objects(MailDB.self).filter("uid = \(uid) AND folder = \"\(folder)\" AND accountID = \(API.shared.currentUser.id)")
                if result.count > 0 {
                    completionHandler(result.first)
                } else {
                    completionHandler(nil)
                }
            } else {
                completionHandler(nil)
            }
        }
    }
    
    func updateMailFlags(mail: APIMail) {
        if let uid = mail.uid, let folder = mail.folder {
            DispatchQueue.main.async {
                let result = self.realm.objects(MailDB.self).filter("uid = \(uid) AND folder = \"\(folder)\" AND accountID = \(API.shared.currentUser.id)")
                
                try! self.realm.write {
                    if let maildDB = result.first {
                        if let isSeen = mail.isSeen {
                            maildDB.isSeen = isSeen
                        }
                        
                        if let isFlagged = mail.isFlagged {
                            maildDB.isFlagged = isFlagged
                        }
                    }
                }
            }
        }
    }

    func updateMailFlags(mail: APIMail, flags: [String]) {
        if let uid = mail.uid, let folder = mail.folder {
            let result = self.realm.objects(MailDB.self).filter("uid = \(uid) AND folder = \"\(folder)\" AND accountID = \(API.shared.currentUser.id)")
            
            try! realm.write {
                if let maildDB = result.first {
                    maildDB.isSeen = flags.contains("\\seen")
                    maildDB.isFlagged = flags.contains("\\flagged")
                }
            }
        }
    }
    
    func deleteMail(mail: APIMail) {
        DispatchQueue.main.async {
            if let uid = mail.uid, let folder = mail.folder {
                let result = self.realm.objects(MailDB.self).filter("uid = \(uid) AND folder = \"\(folder)\" AND accountID = \(API.shared.currentUser.id)")
                
                self.realm.writeAsync(obj: result, block: { (realm, result) in
                    if let result = result {
                        realm.delete(result)
                    }
                })
            }
        }
    }
    
    func deleteAllMails() {
        DispatchQueue.main.async {
            let result = self.realm.objects(MailDB.self)
            
            self.realm.writeAsync(obj: result, block: { (realm, result) in
                if let result = result {
                    realm.delete(result)
                }
            })
        }
    }
    
    func deleteMailsFor(accountID: Int) {
        DispatchQueue.main.async {
            let result = self.realm.objects(MailDB.self).filter("accountID = \(accountID)")
            
            self.realm.writeAsync(obj: result, block: { (realm, result) in
                if let result = result {
                    realm.delete(result)
                }
            })
        }
    }
    
}


extension Realm {
    func writeAsync<T : ThreadConfined>(obj: T, errorHandler: @escaping ((_ error : Swift.Error) -> Void) = { _ in return }, block: @escaping ((Realm, T?) -> Void)) {
        let wrappedObj = ThreadSafeReference(to: obj)
        let config = self.configuration
        DispatchQueue(label: "background").async {
            autoreleasepool {
                do {
                    let realm = try Realm(configuration: config)
                    let obj = realm.resolve(wrappedObj)
                    
                    try realm.write {
                        block(realm, obj)
                    }
                }
                catch {
                    errorHandler(error)
                }
            }
        }
    }
}
