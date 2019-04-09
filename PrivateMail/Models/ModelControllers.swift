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
    
    var selectedFolder: String?
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
    var loadingBodies = false
    var syncingFolder = ""
    var uids: [String: [APIMail]] = [:]
    var delegate: StorageProviderDelegate?
    
    static func migrateIfNeeded() {
        let config = Realm.Configuration(deleteRealmIfMigrationNeeded: true)
        Realm.Configuration.defaultConfiguration = config
    }
    
    func syncFolderIfNeeded(folder: String) {
        API.shared.getMailsInfo(text: "", folder: folder) { (result, error) in
            if let result = result {
                var mails: [APIMail] = []
                
                for item in result {
                    if let uidText = item["uid"] as? String, let uid = Int(uidText) {
                        var mail = APIMail()
                        mail.uid = uid
                        mails.append(mail)
                    }
                }
                
                self.syncingFolder = folder
                self.uids[folder] = mails
                self.loadingBodies = false
                
                self.loadBodiesFor(mails: mails, limit: 50, folder: folder, completionHandler: { (success) in
                })
            }
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
            if let folderName = folder.name {
                list.append(folderName)
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
    
    func loadBodiesFor(mails: [APIMail], limit: Int, folder: String, completionHandler: @escaping (Bool) -> Void) {
        if loadingBodies {
            return
        }
        
        loadingBodies = true
        
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
                    self.loadingBodies = false
                    
                    if folder == self.syncingFolder {
                        if let uids = self.uids[folder] {
                            self.loadBodiesFor(mails: uids, limit: loadingLimit, folder: folder, completionHandler: { (success) in
                            })
                        }
                    }
                    
                })
            } else {
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
