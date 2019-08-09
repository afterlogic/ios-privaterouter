//
//  APIObjects.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import RealmSwift

struct APIUser {
    var id: Int
    var firstName: String?
    var lastName: String?
    var email: String?
    var dateOfBirth: Date?
    var profileImageURL: URL?
    var input: [String: Any]?
    
    init() {
        id = -1
    }
    
    init(input: [String: Any]) {
        self = APIUser()
        
        self.input = input
        
        if let id = input["AccountID"] as? Int {
            self.id = id
        }
        
        if let name = input["FriendlyName"] as? String {
            self.firstName = name
        }
        
        if let email = input["Email"] as? String {
            self.email = email
        }
    }
}

struct APIMail {
    var uid: Int?
    var senders: [String]?
    var folder: String?
    var title: String?
    var subject: String?
    var plainBody: String?
    var htmlBody: String?
    var date: Date?
    var isFlagged: Bool?
    var isSeen: Bool?
    var isAnswered: Bool?
    var isForwarded: Bool?
    var isDeleted: Bool?
    var isDraft: Bool?
    var isRecent: Bool?
    var hasAttachments: Bool?
    var attachments: [[String: Any]]?
    var to: [String]?
    var from: [String]?
    var cc: [String]?
    var bcc: [String]?
    var replyTo: [String]?
    var hasExternals: Bool
    var safety: Bool
    var threadUID: Int?
    var thread: [APIMail] = []
    
    var input: [String: Any]?
    
    init() {
        self.hasExternals = false
        self.safety = false
    }
    
    init(mail: MailDB) {
        self = APIMail()
        
        self.uid = mail.uid
        self.folder = mail.folder
        self.subject = mail.subject
//        self.htmlBody = mail.body
        self.senders = [mail.sender]
        self.isSeen = mail.isSeen
        self.isFlagged = mail.isFlagged
        self.isAnswered = mail.isAnswered
        self.isForwarded = mail.isForwarded
        self.isDeleted = mail.isDeleted
        self.isDraft = mail.isDraft
        self.isRecent = mail.isRecent
        self.hasAttachments = mail.attachments.count > 0
        self.date = mail.date
        
        if mail.threadUID > 0 {
            self.threadUID = mail.threadUID
        }
    }
    
    init(input: [String: Any]) {
        self = APIMail()
        self.input = input
        
        if let timestamp = input["TimeStampInUTC"] as? TimeInterval {
            self.date = Date(timeIntervalSince1970: timestamp)
        }
        
        if let from = input["From"] as? [String: Any],
            let senders = from["@Collection"] as? [[String: Any]] {
            self.senders = []
            
            for sender in senders {
                if let name = sender["DisplayName"] as? String {
                    if name.count > 0 {
                        self.senders?.append(name)
                    } else {
                        if let email = sender["Email"] as? String {
                            self.senders?.append(email)
                        }
                    }
                }
            }
        }
        
        self.from = []
        
        if let from = input["From"] as? [String: Any],
            let collection = from["@Collection"] as? [[String: Any]] {
            for item in collection {
                if let email = item["Email"] as? String {
                    self.from?.append(email)
                }
            }
        }
        
        self.to = []
        
        if let to = input["To"] as? [String: Any] {
            if let collection = to["@Collection"] as? [[String: Any]] {
                for item in collection {
                    if let email = item["Email"] as? String {
                        self.to?.append(email)
                    }
                }
            }
        }
        
        self.replyTo = []
        
        if let replyTo = input["ReplyTo"] as? [String: Any] {
            if let collection = replyTo["@Collection"] as? [[String: Any]] {
                for item in collection {
                    if let email = item["Email"] as? String {
                        self.replyTo?.append(email)
                    }
                }
            }
        }
        
        self.cc = []
        
        if let cc = input["Cc"] as? [String: Any],
            let collection = cc["@Collection"] as? [[String: Any]] {
            for item in collection {
                if let email = item["Email"] as? String {
                    self.cc?.append(email)
                }
            }
        }
        
        if let subject = input["Subject"] as? String {
            self.subject = subject
        }
        
        if let uid = input["Uid"] as? Int {
            self.uid = uid
        }
        
        if let folder = input["Folder"] as? String {
            self.folder = folder
        }
        
        if let hasAttachments = input["HasAttachments"] as? Bool {
            self.hasAttachments = hasAttachments
        }
        
        if let isFlagged = input["IsFlagged"] as? Bool {
            self.isFlagged = isFlagged
        }
        
        if let isSeen = input["IsSeen"] as? Bool {
            self.isSeen = isSeen
        }
        
        if let isAnswered = input["IsAnswered"] as? Bool {
            self.isAnswered = isAnswered
        }
        
        if let isForwarded = input["IsForwarded"] as? Bool {
            self.isForwarded = isForwarded
        }
        
        if let isDeleted = input["IsDeleted"] as? Bool {
            self.isDeleted = isDeleted
        }
        
        if let isDraft = input["IsDraft"] as? Bool {
            self.isDraft = isDraft
        }
        
        if let isRecent = input["IsRecent"] as? Bool {
            self.isRecent = isRecent
        }
        
        if let body = input["PlainRaw"] as? String {
            self.plainBody = body
        }
        
        if let htmlBody = input["Html"] as? String {
            self.htmlBody = htmlBody
        }
        
        if let attachments = input["Attachments"] as? [String: Any] {
            if let list = attachments["@Collection"] as? [[String: Any]] {
                self.attachments = list
            }
        }
        
        self.hasExternals = false
        
        if let hasExternals = input["HasExternals"] as? Bool {
            self.hasExternals = hasExternals
        }
        
        self.safety = false
        
        if let safety = input["Safety"] as? Bool {
            self.safety = safety
        }
    }
    
    init(data: NSData) {
        let input = NSKeyedUnarchiver.unarchiveObject(with: Data(referencing: data))
        
        if let input = input as? [String : Any] {
            self = APIMail(input: input)
        } else {
            self = APIMail()
        }
    }
    
    func body(_ safe: Bool) -> String {
        let divString = "<div style=\"width: 100%; word-break: break-word;\">"
        
        if var body = htmlBody, body.count > 0 {
            
            if hasExternals && (safety || !safe) {
                body = body.replacingOccurrences(of: "data-x-src=", with: "width=\"100%\" src=")
            }
            
//            body = body.replacingOccurrences(of: "<blockquote>", with: "<blockquote style=\"border-left: solid 2px #000000; margin: 4px 2px; padding-left: 6px;\">")
            
            if let attachments = attachments {
                for attachment in attachments {
                    if let isInline = attachment["IsInline"] as? Bool,
                        let cid = attachment["CID"] as? String,
                        let actions = attachment["Actions"] as? [String: [String: String]],
                        let url = actions["view"]?["url"] {
                        
                        if isInline {
                            body = body.replacingOccurrences(of: "data-x-src-cid=\"\(cid)\"", with: "width=\"100%\" src=\"\(API.shared.getServerURL())\(url)\"")
                        }
                    }
                }
            }
            
            return divString + body + "</div>"
        }
        
        var plainBody = self.plainBody ?? ""
        plainBody = plainBody.replacingOccurrences(of: "\n", with: "<br>")
        
        return divString + plainBody + "</div>"
    }
    
    func plainedBody(_ safe: Bool) -> String {
        var result = body(safe).replacingOccurrences(of: "<br>", with: "\n")
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
        return result
    }
    
    func attachmentsToShow() -> [[String: Any]] {
        var attachmentsToShow: [[String: Any]] = []

        guard let attachments = self.attachments else {
            return attachmentsToShow
        }

        for attachment in attachments {
            if let isInline = attachment["IsInline"] as? Bool,
                let cid = attachment["CID"] as? String {
                if isInline {
                    var contains = false
                    
                    if let htmlBody = htmlBody {
                        contains = htmlBody.contains("data-x-src-cid=\"\(cid)\"")
                    } else if let plainBody = plainBody {
                        contains = plainBody.contains("data-x-src-cid=\"\(cid)\"")
                    }
                    
                    if !contains {
                        attachmentsToShow.append(attachment)
                    }
                } else {
                    attachmentsToShow.append(attachment)
                }
            }
        }

        return attachmentsToShow
    }
    
    func showInlineWarning() -> Bool {
        return hasExternals && !safety
    }
    
    func reSubject() -> String {
        let subject = self.subject ?? ""
        
        let groups = subject.groups(for: "^Re(\\[(\\d+)])?:")
        
        if groups.count > 0 {
            var updatedSubject = subject
            
            if let range = updatedSubject.range(of: groups[0][0]) {
                updatedSubject.removeSubrange(range)
            }
            
            if groups[0].count > 2 {
                let index = (Int(groups[0][2]) ?? 1) + 1
                
                return "Re[\(index)]:" + updatedSubject
            } else {
                return "Re[2]:" + updatedSubject
            }
        } else {
            return "Re: " + subject
        }
    }
}

struct APIFolder {
    var type: Int?
    var name: String?
    var fullName: String?
    var fullNameRaw: String?
    var fullNameHash: String?
    var delimiter: String?
    var isSubscribed: Bool?
    var isSelectable: Bool?
    var exists: Bool?
    var extended: Bool?
    var subFolders: [APIFolder]?
    var subFoldersCount: Int?
    var hash: String?
    var messagesCount: Int?
    var unreadCount: Int?
    var mails: [APIMail] = []
    var depth: Int = 0
    
    var input: [String: Any]?
    
    init() {
    }
    
    init(input: [String: Any]) {
        self = APIFolder()
        self.input = input
        
        if let type = input["Type"] as? Int {
            self.type = type
        }
        
        if let name = input["Name"] as? String {
            self.name = name
        }

        if let fullName = input["FullName"] as? String {
            self.fullName = fullName
        }
        
        if let isSubscribed = input["IsSubscribed"] as? Bool {
            self.isSubscribed = isSubscribed
        }
        
        if let isSelectable = input["IsSelectable"] as? Bool {
            self.isSelectable = isSelectable
        }
        
        if let subfolders = input["SubFolders"] as? [String: Any] {
            subFolders = []
            
            if let folders = subfolders["@Collection"] as? [[String: Any]] {
                for folderDict in folders {
                    let folder = APIFolder(input: folderDict)
                    subFolders?.append(folder)
                }
            }
            
            subFoldersCount = subFolders?.count
        }
    }
}

struct APIContact {
    var uuid: String?
    var group: String?
    var fullName: String?
    var eTag: String?
    var viewEmail: String?
    var personalEmail: String?
    var businessEmail: String?
    var otherEmail: String?
    var primaryEmail: String?
    var skype: String?
    var facebook: String?
    var personalMobile: String?
    var personalAddress: String?
    var firstName: String?
    var lastName: String?
    var nickName: String?
    var personalPhone: String?
    
    var input: [String: Any]?
    
    var asJSON: [String: Any] {
        get {
            if let input = input {
                return input
            } else {
                let result: [String: Any] = [
                    "UUID": (uuid ?? ""),
                    "Storage": (group ?? "personal"),
                    "FullName": (fullName ?? ""),
                    "ETag": (eTag ?? ""),
                    "ViewEmail": (viewEmail ?? ""),
                    "PersonalEmail": (viewEmail ?? ""),
                    "BusinessEmail": (businessEmail ?? ""),
                    "OtherEmail": (primaryEmail ?? ""),
                    "Skype": (skype ?? ""),
                    "Facebook": (facebook ?? ""),
                    "PersonalMobile": (personalMobile ?? ""),
                    "PersonalAddress": (personalAddress ?? ""),
                    "FirstName": (firstName ?? ""),
                    "LastName": (lastName ?? ""),
                    "NickName": (nickName ?? ""),
                    "PersonalPhone": (personalPhone ?? ""),
                ]
                
                return result
            }
        }
    }
    
    init() {
        
    }
    
    init(input: [String: Any]) {
        self.input = input
        
        if let uuid = input["UUID"] as? String {
            self.uuid = uuid
        }
        
        if let group = input["Storage"] as? String {
            self.group = group
        }
        
        if let fullName = input["FullName"] as? String {
            self.fullName = fullName
        }
        
        if let eTag = input["ETag"] as? String {
            self.eTag = eTag
        }
        
        if let email = input["ViewEmail"] as? String {
            self.viewEmail = email
        }
        
        if let otherEmail = input["OtherEmail"] as? String {
            self.otherEmail = otherEmail
        }
        
        if let personalEmail = input["PersonalEmail"] as? String {
            self.personalEmail = personalEmail
        }
        
        if let primaryEmail = input["PrimaryEmail"] as? String {
            self.primaryEmail = primaryEmail
        }
        
        if let skype = input["Skype"] as? String {
            self.skype = skype
        }
        
        if let facebook = input["Facebook"] as? String {
            self.facebook = facebook
        }

        if let personalMobile = input["PersonalMobile"] as? String {
            self.personalMobile = personalMobile
        }

        if let address = input["PersonalAddress"] as? String {
            self.personalAddress = address
        }
        
        if let firstName = input["FirstName"] as? String {
            self.firstName = firstName
        }
        
        if let secondName = input["LastName"] as? String {
            self.lastName = secondName
        }
        
        if let nick = input["NickName"] as? String {
            self.nickName = nick
        }
        
        if let phone = input["PersonalPhone"] as? String {
            self.personalPhone = phone
        }

    }
    
    init(_ contact: ContactDB) {
        self.uuid = contact.uuid
        self.group = contact.group
        self.fullName = contact.fullName
        self.eTag = contact.eTag
        self.viewEmail = contact.viewEmail
        self.personalEmail = contact.primaryEmail
        self.businessEmail = contact.businessEmail
        self.otherEmail = contact.otherEmail
        self.primaryEmail = contact.primaryEmail
        self.skype = contact.skype
        self.facebook = contact.facebook
        self.personalMobile = contact.personalMobile
        self.personalAddress = contact.personalAddress
        self.firstName = contact.firstName
        self.lastName = contact.lastName
        self.nickName = contact.nickName
        self.personalPhone = contact.personalPhone
    }
}
