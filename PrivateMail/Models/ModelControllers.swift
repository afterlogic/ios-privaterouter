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
        
        for folder in folders {
            if folder.isSubscribed ?? true {
                result.append(folder)
            }
        }
        
        return result
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
    @objc dynamic var data = NSData()
}

protocol StorageProviderDelegate: NSObjectProtocol {
    func updateHeaderWith(progress: String?, folder: String)
}


class StorageProvider: NSObject {
    static let shared = StorageProvider()
    
    let realm = try! Realm()
    var syncingFolders: [String] = []
    var uids: [String: [APIMail]] = [:]
    var delegate: StorageProviderDelegate?
    
    static func migrateIfNeeded() {
        let config = Realm.Configuration(deleteRealmIfMigrationNeeded: true)
        Realm.Configuration.defaultConfiguration = config
    }
    
    func syncFolderIfNeeded(folder: String, beganSyncing: @escaping () -> Void) {
        if syncingFolders.contains(folder) {
            beganSyncing()
            return
        }
        
        syncingFolders.append(folder)
        
        API.shared.getMailsInfo(text: "", folder: folder) { (result, error) in
            beganSyncing()
            
            if let result = result {
                var mails: [APIMail] = []
                
                for item in result {
                    if let uidText = item["uid"] as? String, let uid = Int(uidText) {
                        var mail = APIMail()
                        mail.uid = uid
                        mail.folder = folder
                        
                        DispatchQueue.main.async {
                            if let flags = item["flags"] as? [String] {
                                StorageProvider.shared.updateMailFlags(mail: mail, flags: flags)
                            }
                        }
                        
                        mails.append(mail)
                    }
                }
                
                mails = mails.sorted(by: { (first, second) -> Bool in
                    if let firstUID = first.uid, let secondUID = second.uid {
                        return firstUID > secondUID
                    } else {
                        return true
                    }
                })
                
                self.removeDeletedMails(mails: mails)
                
                self.uids[folder] = mails
                
                self.loadBodiesFor(mails: mails, limit: 50, folder: folder, completionHandler: { (success) in
                })
            }
        }
    }
    
    func stopSyncingCurrentFolder() {
        if let index = syncingFolders.index(of: MenuModelController.shared.selectedFolder) {
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
            let body = mail.body,
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
                let body = mail.body,
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
                
                let data = NSKeyedArchiver.archivedData(withRootObject: input)
                mailDB.data = NSData(data: data)
                mailsDB.append(mailDB)
            }
        }
        
        DispatchQueue.main.async {
            try! self.realm.write {
                self.realm.add(mailsDB)
            }
        }
        
        completionHandler(true)
    }
    
    func loadBodiesFor(mails: [APIMail], limit: Int, folder: String, completionHandler: @escaping (Bool) -> Void) {
        var uids: [Int] = []
        let loadingLimit = limit
        
        getMails(text: "", folder: folder, limit: nil) { (result) in
            for mail in mails {
                var found = false
                
                for item in result {
                    if item.uid == mail.uid {
                        found = true
                        break
                    }
                }
                
                if !found {
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
                    
                })
            } else {
                if let index = self.syncingFolders.index(of: folder) {
                    self.syncingFolders.remove(at: index)
                }
                
                progress = nil
            }
            
            self.delegate?.updateHeaderWith(progress: progress, folder: folder)
        }
    }
    
    func getMails(text: String, folder: String, limit: Int?, completionHandler: @escaping ([APIMail]) -> Void) {
        DispatchQueue.main.async {
            var mails: [APIMail] = []
            var predicate = """
            (
            folder = \"\(folder)\"
            AND accountID = \(API.shared.currentUser.id)
            )
            """
            
            if text.count > 0 {
               predicate += """
                AND (subject CONTAINS[cd] \"\(text)\"
                    OR body CONTAINS[cd] \"\(text)\")
                """
            }
            
            let result = self.realm.objects(MailDB.self).filter(predicate).sorted(byKeyPath: "date", ascending: false)
            
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
            
            completionHandler(mails)
        }
    }
    
    func removeDeletedMails(mails: [APIMail]) {
        DispatchQueue.main.async {
            let predicate = """
            (
            folder = \"\(MenuModelController.shared.selectedFolder)\"
            AND accountID = \(API.shared.currentUser.id)
            )
            """
            
            let result = self.realm.objects(MailDB.self).filter(predicate).sorted(byKeyPath: "date", ascending: false)
            var mailsToDelete: [MailDB] = []
            
            for i in 0..<result.count {
                let object = result[i]
                
                var found = false
                
                for mail in mails {
                    if mail.uid == object.uid {
                        found = true
                        break
                    }
                }
                
                if !found {
                    mailsToDelete.append(object)
                }
            }
            
            try! self.realm.write {
                self.realm.delete(mailsToDelete)
            }
            
        }
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
            let result = self.realm.objects(MailDB.self).filter("uid = \(uid) AND folder = \"\(folder)\" AND accountID = \(API.shared.currentUser.id)")
            
            try! realm.write {
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
            try! self.realm.write {
                if let uid = mail.uid, let folder = mail.folder {
                    let result = self.realm.objects(MailDB.self).filter("uid = \(uid) AND folder = \"\(folder)\" AND accountID = \(API.shared.currentUser.id)")
                    self.realm.delete(result)
                }
            }
        }
    }
    
    func deleteAllMails() {
        DispatchQueue.main.async {
            try! self.realm.write {
                self.realm.delete(self.realm.objects(MailDB.self))
            }
        }
    }
    
    func deleteMailsFor(accountID: Int) {
        DispatchQueue.main.async {
            try! self.realm.write {
                self.realm.delete(self.realm.objects(MailDB.self).filter("accountID = \(accountID)"))
            }
        }
    }
    
}
