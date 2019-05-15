//
//  StorageProvider.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import RealmSwift

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

class FolderDB: Object {
    @objc dynamic var type = -1
    @objc dynamic var name = ""
    @objc dynamic var fullName = ""
    @objc dynamic var isSubscribed = false
    @objc dynamic var isSelectable = false
    @objc dynamic var subFoldersCount = 0
    @objc dynamic var hashString = ""
    @objc dynamic var messagesCount = 0
    @objc dynamic var unreadCount = 0
    @objc dynamic var depth = 0
    @objc dynamic var data = NSData()
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

    
    //MARK: - Syncing
    
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
    
    
    // MARK: - Fetching
    
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
    
    func getFolders(completionHandler: @escaping ([APIFolder]) -> Void)  {
        DispatchQueue.main.async {
            var folders: [APIFolder] = []
            let result = self.realm.objects(FolderDB.self)
            
            for i in 0..<result.count {
                let object = result[i]
                let input = NSKeyedUnarchiver.unarchiveObject(with: Data(referencing: object.data))
                
                if let input = input as? [String : Any] {
                    var folder = APIFolder(input: input)
                    folder.subFolders = nil
                    
                    folder.subFoldersCount = object.subFoldersCount
                    folder.hash = object.hashString
                    folder.messagesCount = object.messagesCount
                    folder.unreadCount = object.unreadCount
                    folder.depth = object.depth
                    
                    folders.append(folder)
                }
            }
            
            completionHandler(folders)
        }
    }
    
    func getCurrentUser() -> APIUser? {
        if let currentUser = UserDefaults.standard.object(forKey: "currentUser") as? [String: Any] {
            let user = APIUser(input: currentUser)
            
            return user
        }
        
        return nil
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
    
    
    //MARK: - Saving
    
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
    
    func saveCurrentUser(user: [String: Any]) {
        UserDefaults.standard.set(user, forKey: "currentUser")
    }
    
    func saveFolders(folders: [APIFolder]) {
        deleteAllFolders {
            var foldersDB: [FolderDB] = []
            
            for folder in folders {
                if  let type = folder.type,
                    let name = folder.name,
                    let fullName = folder.fullName,
                    let isSubscribed = folder.isSubscribed,
                    let isSelectable = folder.isSelectable,
                    let hashString = folder.hash,
                    let messagesCount = folder.messagesCount,
                    let unreadCount = folder.unreadCount,
                    let input = folder.input {

                    let subFoldersCount = folder.subFoldersCount ?? 0
                    
                    let folderDB = FolderDB()
                    folderDB.type = type
                    folderDB.name = name
                    folderDB.fullName = fullName
                    folderDB.isSubscribed = isSubscribed
                    folderDB.isSelectable = isSelectable
                    folderDB.subFoldersCount = subFoldersCount
                    folderDB.hashString = hashString
                    folderDB.messagesCount = messagesCount
                    folderDB.unreadCount = unreadCount
                    folderDB.depth = folder.depth
                    
                    let data = NSKeyedArchiver.archivedData(withRootObject: input)
                    folderDB.data = NSData(data: data)
                    foldersDB.append(folderDB)
                }
            }
            
            DispatchQueue.main.async {
                try! self.realm.write {
                    self.realm.add(foldersDB)
                }
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
    
    
    //MARK: - Deleting
    
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
    
    func deleteAllFolders(completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async {
            let result = self.realm.objects(FolderDB.self)
            
            self.realm.writeAsync(obj: result, block: { (realm, result) in
                if let result = result {
                    realm.delete(result)
                }
                
                completionHandler()
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
    
    func removeCurrentUserInfo() {
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "folders")
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
    
}
