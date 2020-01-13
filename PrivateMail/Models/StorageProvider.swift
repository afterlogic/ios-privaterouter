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
    @objc dynamic var threadUID = -1
    @objc dynamic var accountID = -1
    @objc dynamic var folder = ""
    @objc dynamic var subject = ""
    @objc dynamic var body = ""
    @objc dynamic var sender = ""
    @objc dynamic var isSeen = true
    @objc dynamic var isFlagged = false
    @objc dynamic var isAnswered = false
    @objc dynamic var isForwarded = false
    @objc dynamic var isDeleted = false
    @objc dynamic var isDraft = false
    @objc dynamic var isRecent = false
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

class PGPKeyDB: Object {
    @objc dynamic var accountID = -1
    @objc dynamic var isPrivate = false
    @objc dynamic var email = ""
}

class PGPKey: NSObject {
    var accountID = -1
    var isPrivate = false
    var email = ""
    var armoredKey = ""
    var length = 0
}

class ContactsGroupDB: Object {
    @objc dynamic var accountID = -1
    @objc dynamic var name = ""
    @objc dynamic var cTag = -1
    @objc dynamic var uuid = ""
    @objc dynamic var parentUuid = ""
    @objc dynamic var userID = -1
    @objc dynamic var isOrganization = false
    @objc dynamic var email = ""
    @objc dynamic var company = ""
    @objc dynamic var street = ""
    @objc dynamic var city = ""
    @objc dynamic var state = ""
    @objc dynamic var zip = ""
    @objc dynamic var county = ""
    @objc dynamic var phone = ""
    @objc dynamic var fax = ""
    @objc dynamic var web = ""
    
    func asJSON() -> [String: Any] {
        let result: [String: Any] = [
            "UUID": uuid,
            "Name": name,
            "IsOrganization": isOrganization ? "1" : "0",
            "Email": email,
            "Country": county,
            "City": city,
            "Company": company,
            "Fax": fax,
            "Phone": phone,
            "State": state,
            "Street": street,
            "Web": web,
            "Zip": zip,
            "Contacts": [],
        ]
        
        return result
    }
}

class ContactDB: Object {
    @objc dynamic var accountID = -1
    @objc dynamic var uuid = ""
    @objc dynamic var group = ""
    @objc dynamic var fullName = ""
    @objc dynamic var eTag = ""
    @objc dynamic var viewEmail = ""
    @objc dynamic var personalEmail = ""
    @objc dynamic var otherEmail = ""
    @objc dynamic var primaryEmail = 0
    @objc dynamic var primaryPhone = 0
    @objc dynamic var primaryAddress = 0
    @objc dynamic var skype = ""
    @objc dynamic var facebook = ""
    @objc dynamic var personalMobile = ""
    @objc dynamic var personalAddress = ""
    @objc dynamic var firstName = ""
    @objc dynamic var lastName = ""
    @objc dynamic var nickName = ""
    @objc dynamic var personalPhone = ""
    @objc dynamic var data = NSData()
    @objc dynamic var businessEmail = ""
    @objc dynamic var businessStreet = ""
    @objc dynamic var businessCity = ""
    @objc dynamic var businessState = ""
    @objc dynamic var businessZip = ""
    @objc dynamic var businessCountry = ""
    @objc dynamic var businessWeb = ""
    @objc dynamic var businessFax = ""
    @objc dynamic var businessAddress = ""
    @objc dynamic var businessDepartment = ""
    @objc dynamic var businessOffice = ""
    @objc dynamic var businessCompany = ""
    @objc dynamic var businessJobTitle = ""
    @objc dynamic var businessPhone = ""
    @objc dynamic var birthDay = 0
    @objc dynamic var birthMonth = 0
    @objc dynamic var birthYear = 0
    @objc dynamic var notes = ""
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

struct SyncingItem {
    var folder: APIFolder?
    var priority: Int = 0
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
    
    func syncFolderIfNeeded(folder: String, expectedHash: String, oldMails: [APIMail], beganSyncing: @escaping () -> Void) {
        if syncingFolders.contains(folder) {
            beganSyncing()
            return
        }
        
        syncingFolders.append(folder)
        
        NotificationCenter.default.post(name: .shouldRefreshFoldersInfo, object: nil)
        
        let progress = NSLocalizedString("Syncing...", comment: "")
        delegate?.updateHeaderWith(progress: progress, folder: folder)

        API.shared.getMailsInfo(folder: folder) { (result, error) in
            if let result = result {
                var mails: [APIMail] = []
                
                for item in result {
                    var uid = item["uid"] as? Int
                    
                    if uid == nil {
                        if let uidText = item["uid"] as? String {
                            uid = Int(uidText)
                        }
                    }
                    
                    if uid != nil {
                        var mail = APIMail()
                        mail.uid = uid
                        mail.folder = folder
                        
                        if let flags = item["flags"] as? [String] {
                            mail.isSeen = flags.contains("\\seen")
                            mail.isFlagged = flags.contains("\\flagged")
                            mail.isAnswered = flags.contains("\\answered")
                            mail.isForwarded = flags.contains("$forwarded")
                            mail.isDeleted = flags.contains("\\deleted")
                            mail.isDraft = flags.contains("\\draft")
                            mail.isRecent = flags.contains("\\recent")
                        }
                        
                        var threadUID = item["threadUID"] as? Int
                        
                        if threadUID == nil {
                            let threadUIDText = item["threadUID"] as? String
                            threadUID = Int(threadUIDText ?? "")
                        }

                        mail.threadUID = threadUID
                        
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
                
                DispatchQueue.main.sync {
                    self.removeDeletedMails(mails: mails, folder: folder, completionHandler: { (deletedUids) in
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
                var c = 0
                
                for i in 0 ..< mails.count {
                    let mail = mails[i]
                    var isFound = false

                    if c < newMails.count {
                        
                        while mail.uid ?? -1 < newMails[c].uid ?? -1 {
                            if (c + 1) < newMails.count {
                                c += 1
                            } else {
                                break
                            }
                        }
                        
                        if mail.uid == newMails[c].uid {
                            var shouldUpdateFlags = false
                            
                            if let isSeen = mail.isSeen {
                                if newMails[c].isSeen != isSeen {
                                    newMails[c].isSeen = isSeen
                                    shouldUpdateFlags = true
                                }
                            }
                            
                            if let isFlagged = mail.isFlagged {
                                if newMails[c].isFlagged != isFlagged {
                                    newMails[c].isFlagged = isFlagged
                                    shouldUpdateFlags = true
                                }
                            }
                            
                            if let isForwarded = mail.isForwarded {
                                if newMails[c].isForwarded != isForwarded {
                                    newMails[c].isForwarded = isForwarded
                                    shouldUpdateFlags = true
                                }
                            }
                            
                            if let isDeleted = mail.isDeleted {
                                if newMails[c].isDeleted != isDeleted {
                                    newMails[c].isDeleted = isDeleted
                                    shouldUpdateFlags = true
                                }
                            }
                            
                            if let isDraft = mail.isDraft {
                                if newMails[c].isDraft != isDraft {
                                    newMails[c].isDraft = isDraft
                                    shouldUpdateFlags = true
                                }
                            }
                            
                            if let isRecent = mail.isRecent {
                                if newMails[c].isRecent != isRecent {
                                    newMails[c].isRecent = isRecent
                                    shouldUpdateFlags = true
                                }
                            }
                            
                            if newMails[c].threadUID != mail.threadUID {
                                newMails[c].threadUID = mail.threadUID
                                shouldUpdateFlags = true
                            }
                            
                            if shouldUpdateFlags {
                                group.enter()
                                
                                self.updateMailFlags(mail: mail, completionHandler: {
                                    group.leave()
                                })
                                
                                group.wait()
                            }
                            
                            isFound = true
                        }
                    }

                    isEqual = isEqual && isFound
                }
                
                beganSyncing()
                
                // Finish syncing if nothing to update
                if isEqual {
                    if let index = self.syncingFolders.firstIndex(of: folder) {
                        self.syncingFolders.remove(at: index)
                        MenuModelController.shared.setMailsForFolder(mails: newMails, folder: folder)
                        MenuModelController.shared.updateFolder(folder: folder, hash: expectedHash)
                        NotificationCenter.default.post(name: .shouldRefreshFoldersInfo, object: nil)
                    }
                    
                    self.delegate?.updateHeaderWith(progress: nil, folder: folder)
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

                var oldUIDS: [Int] = []
                
                for mail in mailsDB {
                    oldUIDS.append(mail.uid ?? -1)
                }
                
                var newUIDS: [Int] = []

                for mail in mails {
                    newUIDS.append(mail.uid ?? -1)
                }
                
                let setA = Set(oldUIDS)
                let setB = Set(newUIDS)
                let uidsToDownload = setB.subtracting(setA).sorted { (a, b) -> Bool in
                    return a > b
                }
                
                var uids: [Int] = []
                
                for uid in uidsToDownload {
                    uids.append(uid)
                    
                    if uids.count == 50 || uid == uidsToDownload.last {
                        parts.append(uids)
                        uids = []
                    }
                }

                DispatchQueue.global(qos: .default).async {
                    var progress: String?
                    var totalCount = mailsDB.count
                    
                    if totalCount != mails.count {
                        progress = NSLocalizedString("Syncing... (\(totalCount)/\(mails.count))", comment: "")
                    }
                    
                    self.delegate?.updateHeaderWith(progress: progress, folder: folder)
                    
                    var success = true
                    
                    for part in parts {
                        totalCount += part.count
                        
                        if self.syncingFolders.contains(folder)  {
                            group.enter()
                            
                            API.shared.getMailsBodiesList(uids: part, folder: folder, completionHandler: { (result, error) in
                                if var result = result {
                                    for i in 0 ..< result.count {
                                        for mail in mails {
                                            if mail.uid == result[i].uid {
                                                result[i].threadUID = mail.threadUID
                                                break
                                            }
                                        }
                                    }
                                    
                                    newMails.append(contentsOf: result)
                                    newMails.sort(by: { (a, b) -> Bool in
                                        return (a.uid ?? -1) > (b.uid ?? -1)
                                    })
                                } else {
                                    success = false
                                }
                                
                                group.leave()
                            })
                            
                            group.wait()
                            
                            totalCount = newMails.count
                            progress = NSLocalizedString("Syncing... (\(totalCount)/\(mails.count))", comment: "")
                            
                            if self.syncingFolders.contains(folder) {
                                self.delegate?.updateHeaderWith(progress: progress, folder: folder)
                                self.delegate?.updateTableView(mails: newMails, folder: folder)
                            }
                        } else {
                            if let index = self.syncingFolders.firstIndex(of: folder) {
                                self.syncingFolders.remove(at: index)
                                NotificationCenter.default.post(name: .shouldRefreshFoldersInfo, object: nil)
                            }
                            
                            progress = nil
                            break
                        }
                    }
                    
                    if let index = self.syncingFolders.firstIndex(of: folder) {
                        self.syncingFolders.remove(at: index)

                        if success {
                            MenuModelController.shared.updateFolder(folder: folder, hash: expectedHash)
                        }
                        
                        NotificationCenter.default.post(name: .shouldRefreshFoldersInfo, object: nil)
                    }
                    
                    self.delegate?.updateHeaderWith(progress: nil, folder: folder)
                }
            } else {
                if let index = self.syncingFolders.firstIndex(of: folder) {
                    self.syncingFolders.remove(at: index)
                    NotificationCenter.default.post(name: .shouldRefreshFoldersInfo, object: nil)
                }
                
                self.delegate?.updateHeaderWith(progress: nil, folder: folder)
                beganSyncing()
            }
        }
        
    }
    
    func stopSyncingFolder(_ name: String) {
        if let index = syncingFolders.firstIndex(of: name) {
            syncingFolders.remove(at: index)
            NotificationCenter.default.post(name: .shouldRefreshFoldersInfo, object: nil)
        }
    }
    
    func stopSyncingCurrentFolder() {
        stopSyncingFolder(MenuModelController.shared.selectedFolder)
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
                    NotificationCenter.default.post(name: .shouldRefreshFoldersInfo, object: nil)
                }
                
                progress = nil
                completionHandler(true)
            }
            
            self.delegate?.updateHeaderWith(progress: progress, folder: folder)
        }
    }
    
    
    // MARK: - Fetching
    
    func getMails(text: String, folder: String, limit: Int?, additionalPredicate: String?, completionHandler: @escaping ([APIMail]) -> Void) {
//        let referenceDate = Date()
//        let fetchID = fetchingID
//        fetchingID += 1
        
//        print("Fetching began: ID\(fetchID)")
        
        isFetching = true
        var mails: [APIMail] = []
        
        DispatchQueue.main.async {
            var predicate = """
            (
            folder = \"\(folder)\"
            AND accountID = \(API.shared.currentUser.id)
            )
            """
            
            let groups = text.groups(for: "email:\\s*((([^\\s]+)\\s*)+)")
            
            if groups.count > 0 {
                let combinedEmails = groups[0][1]
                let emailGroups = combinedEmails.groups(for: "[^,\\s]+")
                var predicateParts: [String] = []
                
                for email in emailGroups {
                    predicateParts.append("sender CONTAINS[cd] \"\(email[0])\"")
                }
                
                predicate += " AND (\(predicateParts.joined(separator: " OR ")))"
            } else if text.count > 0 {
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
            
            for i in 0 ..< min(result.count, limit ?? result.count) {
                let object = result[i]
                
                let mail = APIMail(mail: object)
                mails.append(mail)
            }
            
            self.isFetching = false
            
            completionHandler(mails)
//            print("Fetching ID\(fetchID) time: \(Date().timeIntervalSince(referenceDate))")
        }
    }
    
    func getFolders(completionHandler: @escaping ([APIFolder]) -> Void)  {
        DispatchQueue.main.async {
            var folders: [APIFolder] = []
            let result = self.realm.objects(FolderDB.self)
            
            for i in 0 ..< result.count {
                let object = result[i]
                let input = NSKeyedUnarchiver.unarchiveObject(with: Data(referencing: object.data))
                
                if let input = input as? [String : Any] {
                    var folder = APIFolder(input: input,namespace: nil)
                    folder.subFolders = nil
                    
                    folder.subFoldersCount = object.subFoldersCount
                    folder.hash = object.hashString
                    folder.messagesCount = object.messagesCount
                    folder.unreadCount = object.unreadCount
                    folder.depth = object.depth
                    
                    folders.append(folder)
            
                    folder.subFolders?.forEach({ (fodler:APIFolder) in
                        
                    })
                
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
    
    func getPGPKeys(_ isPrivate: Bool) -> [PGPKey] {
        let keys = self.realm.objects(PGPKeyDB.self).filter("isPrivate = \(isPrivate) AND accountID = \(API.shared.currentUser.id)")
        var result: [PGPKey] = []
        
        for key in keys {
            let newKey = PGPKey()
            newKey.accountID = key.accountID
            newKey.email = key.email
            newKey.isPrivate = key.isPrivate
            
            if newKey.isPrivate {
                newKey.armoredKey = keychain["PrivateKey\(API.shared.currentUser.id)-\(key.email)"] ?? ""
            } else {
                newKey.armoredKey = keychain["PublicKey\(API.shared.currentUser.id)-\(key.email)"] ?? ""
            }
            
            result.append(newKey)
        }
        
        return result
    }
    
    func getPGPKey(_ email: String, isPrivate: Bool) -> PGPKey? {
        let keys = self.realm.objects(PGPKeyDB.self).filter("isPrivate = \(isPrivate) AND accountID = \(API.shared.currentUser.id)")
        if let key = keys.first(where: { (key:PGPKeyDB) -> Bool in
            return key.email.contains(email)
        })
        {
      
        let newKey = PGPKey()
        newKey.accountID = key.accountID
        newKey.email = key.email
        newKey.isPrivate = key.isPrivate
        
        if newKey.isPrivate {
            newKey.armoredKey = keychain["PrivateKey\(API.shared.currentUser.id)-\(key.email)"] ?? ""
        } else {
            newKey.armoredKey = keychain["PublicKey\(API.shared.currentUser.id)-\(key.email)"] ?? ""
        }
        
        return newKey
        }
         return nil
    }
    
    func getContactGroups() -> [ContactsGroupDB] {
        let results = realm.objects(ContactsGroupDB.self)//.filter("accountID = \(API.shared.currentUser.id)")
        var groups: [ContactsGroupDB] = []
        
        for group in results {
            groups.append(group)
        }
        
        return groups
    }
    
    func getContactsGroup(_ name: String? = nil) -> ContactsGroupDB? {
        let groups = realm.objects(ContactsGroupDB.self).filter("name = \"\(name ?? "personal")\" AND accountID = \(API.shared.currentUser.id)")
        return groups.first
    }
    
    func getContacts(_ group: String? = nil, search: String? = nil) -> [APIContact] {
        var predicate = "(accountID = \(API.shared.currentUser.id)) "

        if let search = search, search.count > 0 {
            predicate += """
            AND (fullName CONTAINS[cd] \"\(search)\"
            OR viewEmail CONTAINS[cd] \"\(search)\")
            """
        }
        
        let result = self.realm.objects(ContactDB.self).filter(predicate)
        
        var contacts: [APIContact] = []
        
        for item in result {
            let contact = APIContact(item)
            
            if let group = group, group != "" {
                if contact.groupUUIDs?.contains(group) ?? false {
                    contacts.append(contact)
                }
            } else {
                contacts.append(contact)
            }
        }
        
        return contacts
    }
    
    
    //MARK: - Saving
    
    func saveMail(mail: APIMail) {
        if API.shared.currentUser.id > 0,
            let uid = mail.uid,
            let input = mail.input,
            let folder = mail.folder,
            let subject = mail.subject,
            let sender = mail.senders?.first,
            //            let body = mail.plainBody,
            let date = mail.date,
            let isSeen = mail.isSeen,
            let isFlagged = mail.isFlagged {
            
            let mailDB = MailDB()
            mailDB.uid = uid
            mailDB.folder = folder
            mailDB.accountID = API.shared.currentUser.id
            mailDB.body = mail.plainedBody(false)
            mailDB.sender = sender
            mailDB.subject = subject
            mailDB.date = date
            mailDB.isSeen = isSeen
            mailDB.isFlagged = isFlagged
            mailDB.threadUID = mail.threadUID ?? -1
            mailDB.isAnswered = mail.isAnswered ?? false
            mailDB.isForwarded = mail.isForwarded ?? false
            mailDB.isDeleted = mail.isDeleted ?? false
            mailDB.isDraft = mail.isDraft ?? false
            mailDB.isRecent = mail.isRecent ?? false
            
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
                            mail.isForwarded = mailDB.isForwarded
                            mail.isDeleted = mailDB.isDeleted
                            mail.isDraft = mailDB.isDraft
                            mail.isRecent = mailDB.isRecent
                        } else {
                            self.realm.add(mailDB)
                        }
                    }
                })
            }
        }
    }
    
    func saveMails(mails: [APIMail], completionHandler: @escaping (Bool) -> Void) {
        for mail in mails {
            saveMail(mail: mail)
        }
        
        completionHandler(true)
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
//                    let hashString = folder.hash,
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
                    folderDB.hashString = folder.hash ?? ""
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
    
    func savePGPKey(_ email: String, isPrivate: Bool, armoredKey: String) {
        let key = PGPKeyDB()
        key.accountID = API.shared.currentUser.id
        key.email = email
        key.isPrivate = isPrivate
        
        if isPrivate {
            keychain["PrivateKey\(API.shared.currentUser.id)-\(email)"] = armoredKey
        } else {
            keychain["PublicKey\(API.shared.currentUser.id)-\(email)"] = armoredKey
        }
        
        try! realm.write {
            realm.add(key)
        }
    }
    
    func updateMailFlags(mail: APIMail, completionHandler: @escaping () -> Void) {
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
                        
                        if let isForwarded = mail.isForwarded {
                            maildDB.isForwarded = isForwarded
                        }
                        
                        if let isDeleted = mail.isDeleted {
                            maildDB.isDeleted = isDeleted
                        }
                        
                        if let isDraft = mail.isDraft {
                            maildDB.isDraft = isDraft
                        }
                        
                        if let isRecent = mail.isRecent {
                            maildDB.isRecent = isRecent
                        }
                        
                        if let threadUID = mail.threadUID {
                            maildDB.threadUID = threadUID
                        }
                    }
                    
                    completionHandler()
                }
            }
        } else {
            completionHandler()
        }
    }
    
    func saveContactsGroups(groups: [ContactsGroupDB]) {
        try! self.realm.write {
            self.realm.add(groups)
        }
    }
    
    func saveContacts(contacts: [APIContact]) {
        var contactsDB: [ContactDB] = []
        
        for contact in contacts {
            let contactDB = ContactDB()
            
            contactDB.accountID = API.shared.currentUser.id
            contactDB.uuid = contact.uuid ?? ""
            contactDB.group = contact.storage ?? ""
            contactDB.fullName = contact.fullName ?? ""
            contactDB.eTag = contact.eTag ?? ""
            contactDB.viewEmail = contact.viewEmail ?? ""
            contactDB.businessEmail = contact.businessEmail ?? ""
            contactDB.otherEmail = contact.otherEmail ?? ""
            contactDB.personalEmail = contact.personalEmail ?? ""
            contactDB.primaryAddress = contact.primaryAddress ?? 0
            contactDB.primaryEmail = contact.primaryEmail ?? 0
            contactDB.primaryPhone = contact.primaryPhone ?? 0
            contactDB.skype = contact.skype ?? ""
            contactDB.facebook = contact.facebook ?? ""
            contactDB.personalMobile = contact.personalMobile ?? ""
            contactDB.personalAddress = contact.personalAddress ?? ""
            contactDB.firstName = contact.firstName ?? ""
            contactDB.lastName = contact.lastName ?? ""
            contactDB.nickName = contact.nickName ?? ""
            contactDB.personalPhone = contact.personalPhone ?? ""
            contactDB.businessEmail = contact.businessEmail ?? ""
            contactDB.businessCity = contact.businessCity ?? ""
            contactDB.businessState = contact.businessState ?? ""
            contactDB.businessZip = contact.businessZip ?? ""
            contactDB.businessCountry = contact.businessCountry ?? ""
            contactDB.businessWeb = contact.businessWeb ?? ""
            contactDB.businessFax = contact.businessFax ?? ""
            contactDB.businessAddress = contact.businessAddress ?? ""
            contactDB.businessDepartment = contact.businessDepartment ?? ""
            contactDB.businessOffice = contact.businessOffice ?? ""
            contactDB.businessCompany = contact.businessCompany ?? ""
            contactDB.businessJobTitle = contact.businessJobTitle ?? ""
            contactDB.businessPhone = contact.businessPhone ?? ""
            contactDB.birthDay = contact.birthDay ?? 0
            contactDB.birthMonth = contact.birthMonth ?? 0
            contactDB.birthYear = contact.birthYear ?? 0
            contactDB.notes = contact.notes ?? ""
            
            if let input = contact.input {
                let data = NSKeyedArchiver.archivedData(withRootObject: input)
                contactDB.data = NSData(data: data)
            }

            contactsDB.append(contactDB)
        }
        
        try! self.realm.write {
            self.realm.add(contactsDB)
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
    
    func deleteMailsNotFromUser(_ user: APIUser) {
        DispatchQueue.main.async {
            let predicate = """
            (
            NOT accountID = \(user.id)
            )
            """
            
            let result = self.realm.objects(MailDB.self).filter(predicate)
            
            self.realm.writeAsync(obj: result, block: { (realm, result) in
                if let result = result {
                    realm.delete(result)
                }
            })
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
    
    func deleteAllContacts() {
        let contacts = self.realm.objects(ContactDB.self)
//        let groups = self.realm.objects(ContactsGroupDB.self)
        
        try! self.realm.write {
            self.realm.delete(contacts)
//            self.realm.delete(groups)
        }
    }
    
    func deleteAllFolders(completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async {
            let result = self.realm.objects(FolderDB.self)
            
            try! self.realm.write {
                self.realm.delete(result)
            }
            
            completionHandler()
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
    
    func deletePGPKey(_ email: String, isPrivate: Bool) {
        let keys = self.realm.objects(PGPKeyDB.self).filter("email = \"\(email)\" AND isPrivate = \(isPrivate) AND accountID = \(API.shared.currentUser.id)")
        
        if isPrivate {
            keychain["PrivateKey\(API.shared.currentUser.id)-\(email)"] = nil
        } else {
            keychain["PublicKey\(API.shared.currentUser.id)-\(email)"] = nil
        }
        
        try! realm.write {
            realm.delete(keys)
        }
    }
    
    func deleteGroups() {
        let groups = self.realm.objects(ContactsGroupDB.self)
        
        try! self.realm.write {
            self.realm.delete(groups)
        }
    }
    
    func deleteGroup(group: ContactsGroupDB) {
        let result = self.realm.objects(ContactsGroupDB.self).filter("name = \"\(group.name)\" AND accountID = \(API.shared.currentUser.id)")
        
        try! self.realm.write {
            self.realm.delete(result)
        }
    }
    
    func deleteContact(contact: APIContact) {
        if let uuid = contact.uuid {
            let result = self.realm.objects(ContactDB.self).filter("uuid = \"\(uuid)\" AND accountID = \(API.shared.currentUser.id)")
            
            try! self.realm.write {
                self.realm.delete(result)
            }
        }
    }
    
    func removeCurrentUserInfo() {
//        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "folders")
    }
    
    func removeDeletedMails(mails: [APIMail], folder: String, completionHandler: @escaping ([Int]) -> Void) {
        var predicate = """
        (
        folder = \"\(folder)\"
        AND accountID = \(API.shared.currentUser.id)
        )
        """
        
        let result = self.realm.objects(MailDB.self).filter(predicate).sorted(byKeyPath: "uid", ascending: false)
        
//        var deletedUids: [Int] = []
//        var lastIndex = 0
        
        var oldUIDS: [Int] = []
        
        for mail in result {
            oldUIDS.append(mail.uid)
        }
        
        var newUIDS: [Int] = []

        for mail in mails {
            newUIDS.append(mail.uid ?? -1)
        }
        
        let setA = Set(newUIDS)
        let setB = Set(oldUIDS)
        let deletedUids = setB.subtracting(setA).sorted { (a, b) -> Bool in
            return a > b
        }
        
        predicate = """
        (
        folder = \"\(folder)\"
        AND accountID = \(API.shared.currentUser.id)
        AND (uid IN %@)
        )
        """
        
        let mailsToDelete = self.realm.objects(MailDB.self).filter(predicate, deletedUids).sorted(byKeyPath: "uid", ascending: false)
        
        try! self.realm.write {
            self.realm.delete(mailsToDelete)
        }
        
        completionHandler(deletedUids)
    }
    
}
