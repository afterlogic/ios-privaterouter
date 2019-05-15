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
    var hasAttachments: Bool?
    var attachments: [[String: Any]]?
    var to: [String]?
    var from: [String]?
    var cc: [String]?
    var bcc: [String]?
    var hasExternals: Bool
    var safety: Bool
    
    var input: [String: Any]?
    
    init() {
        self.hasExternals = false
        self.safety = false
    }
    
    init(input: [String: Any]) {
        self = APIMail()
        self.input = input
        
        if let timestamp = input["TimeStampInUTC"] as? TimeInterval {
            self.date = Date(timeIntervalSince1970: timestamp)
        }
        
        if let from = input["From"] as? [String: Any], let senders = from["@Collection"] as? [[String: Any]] {
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
        
        if let from = input["From"] as? [String: Any] {
            if let collection = from["@Collection"] as? [[String: Any]] {
                for item in collection {
                    if let email = item["Email"] as? String {
                        self.from?.append(email)
                    }
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
    
    func body(_ safe: Bool) -> String {
        let divString = "<div style=\"width: 100%; word-break: break-word;\">"
        
        if var body = htmlBody, body.count > 0 {
            
            if hasExternals && (safety || !safe) {
                body = body.replacingOccurrences(of: "data-x-src", with: "width=\"100%\" src")
            }
            
            body = body.replacingOccurrences(of: "<blockquote>", with: "<blockquote style=\"border-left: solid 2px #000000; margin: 4px 2px; padding-left: 6px;\">")
            
            return divString + body + "</div>"
        }
        
        var plainBody = self.plainBody ?? ""
        plainBody = plainBody.replacingOccurrences(of: "\n", with: "<br>")
        
        return divString + plainBody + "</div>"
    }
    
    func plainedBody(_ safe: Bool) -> String {
        return body(safe).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
    }
    
    func showInlineWarning() -> Bool {
        return hasExternals && !safety
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
