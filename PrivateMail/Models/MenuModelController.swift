//
//  MenuModelController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

class MenuModelController: NSObject {
    static let shared = MenuModelController()
    
    var folders: [APIFolder] = [] {
        didSet {
            expandedFoldersMap = expandedFolders(folders: folders).associate {
                (key: $0.fullName ?? "", value: $0)
            }
        }
    }
    private var expandedFoldersMap: [String: APIFolder] = [:]
    
    var selectedMenuItem: FolderMenuItem = FolderMenuItem(fullName: "INBOX",name:"INBOX")
    
    var selectedFolder: String {
        return selectedMenuItem.fullName
    }
    
    
    func folder(byFullName fullName: String) -> APIFolder? {
        expandedFoldersMap[fullName]
    }
    
    func menuItems() -> [FolderMenuItem] {
        var folders = foldersToShow()
        
        guard folders.isNotEmpty else {
            return []
        }
        
        var menuItems = [FolderMenuItem]()
        
        if let inboxIndex = folders.firstIndex(where: { $0.fullName == "INBOX" }) {
            folders.remove(at: inboxIndex)
            menuItems.append(FolderMenuItem())
            menuItems.append(FolderMenuItem(custom:true))
        }
        
        let recentFolderItems = folders
            .map{(folder:APIFolder) in
                return FolderMenuItem(fullName: folder.fullName ?? "", name: folder.name ?? "")}
        menuItems.append(contentsOf: recentFolderItems)
        
        return menuItems
    }
    
    private func foldersToShow() -> [APIFolder] {
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

        }
        
        return result
    }
    
    func compressedFolders(folders: [APIFolder]) -> [APIFolder] {
        var result: [APIFolder] = folders
        
        var index = -1
        var deepestFolder: APIFolder = APIFolder()
        deepestFolder.depth = -1
        
        if result.count > 20 {
            return result
        }
        
        for i in 0 ..< result.count {
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
            
            for i in 0 ..< result.count {
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
        var newFolders = expandedFolders(folders: newFolders)
        let expandedFoldersMap = expandedFolders(folders: folders)
            .filter { $0.fullName != nil }
            .associate(mapper: { (key: $0.fullName!, value: $0) })
        
        newFolders.mutatingForEach { newFolder in
            guard
                let fullName = newFolder.fullName,
                let folder = expandedFoldersMap[fullName]
                else { return }
            
            newFolder.mails = folder.mails
            newFolder.hash = folder.hash
            
            if newFolder.unreadCount == nil {
                newFolder.unreadCount = folder.unreadCount
            }
            
            if newFolder.messagesCount == nil {
                newFolder.messagesCount = folder.messagesCount
            }
        }
        
        folders = compressedFolders(folders: newFolders)
    }
    
    func updateFolder(folder: String, hash: String) {
        var expandedFolders = self.expandedFolders(folders: folders)
        
        for i in 0 ..< expandedFolders.count {
            if expandedFolders[i].fullName == folder {
                expandedFolders[i].hash = hash
                break
            }
        }
        
        folders = compressedFolders(folders: expandedFolders)
        
        StorageProvider.shared.saveFolders(folders: folders)
    }
    
    func resetAllHashes() {
        var expandedFolders = self.expandedFolders(folders: folders)
        
        for i in 0 ..< expandedFolders.count {
            expandedFolders[i].hash = nil
        }
        
        folders = compressedFolders(folders: expandedFolders)
        
        StorageProvider.shared.saveFolders(folders: folders)
    }
    
    func currentFolder() -> APIFolder? {
        let folders = expandedFolders(folders: self.folders)
        
        for folder in folders {
            if folder.fullName == selectedFolder {
                return folder
            }
        }
        
        return nil
    }
    
    func mailsForCurrentFolder() -> [APIMail] {
        return mailsForFolder(name: selectedFolder)
    }
    
    func mailsForFolder(name: String?) -> [APIMail] {
        if(name?.isEmpty==true){
          for folder in expandedFolders(folders: folders) {
                if folder.type == 1 {
                    return folder.mails.filter { (mail) -> Bool in
                       return mail.isFlagged==true
                    }
                }
            }
        }
        
        for folder in expandedFolders(folders: folders) {
            if folder.fullName == name {
                return folder.mails
            }
        }
        
        return []
    }
    
    func setMailsForFolder(mails: [APIMail], folder: String) {
        var folders = expandedFolders(folders: self.folders)
        
        for i in 0 ..< folders.count {
            if folders[i].fullName == folder {
                folders[i].mails = mails
                
                self.folders = compressedFolders(folders: folders)
                return
            }
        }
    }
    
    func setMailsForCurrentFolder(mails: [APIMail]) {
        setMailsForFolder(mails: mails, folder: selectedFolder)
    }
    
    func removeMail(mail: APIMail) {
        var folders = expandedFolders(folders: self.folders)
        
        for i in 0 ..< folders.count {
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

struct FolderMenuItem {
    var fullName: String
    var name: String
    var custom=false
    
    init(){
        self.fullName="INBOX"
        self.name="INBOX"
        self.custom=false
    }
    
    init(custom:Bool){
        self.fullName=""
        self.name=""
        self.custom=custom
    }
    
    init( fullName: String, name: String){
        self.fullName=fullName
        self.name=name
    }
    
    
}
