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
    var body: String?
    var date: Date?
    var isFlagged: Bool?
    var isSeen: Bool?
    var hasAttachments: Bool?
    var attachments: [[String: Any]]?
    var to: [String]?
    var from: [String]?
    var cc: [String]?
    var bcc: [String]?
    
    var input: [String: Any]?

    init() {
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
            self.body = body
        }
        
        if let attachments = input["Attachments"] as? [String: Any] {
            if let list = attachments["@Collection"] as? [[String: Any]] {
                self.attachments = list
            }
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
    var hash: String?
    var messagesCount: Int?
    var unreadCount: Int?

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
        
        if let isSubscribed = input["IsSubscribed"] as? Bool {
            self.isSubscribed = isSubscribed
        }
        
        if let isSelectable = input["IsSelectable"] as? Bool {
            self.isSelectable = isSelectable
        }
    }
}
