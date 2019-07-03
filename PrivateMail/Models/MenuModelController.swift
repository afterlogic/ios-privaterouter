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
        
        if result.count > 20 {
            return result
        }
        
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
        var newFolders = expandedFolders(folders: newFolders)
        let expandedFolders = self.expandedFolders(folders: folders)
        
        for i in 0..<newFolders.count {
            for folder in expandedFolders {
                if folder.fullName == newFolders[i].fullName {
                    newFolders[i].mails = folder.mails
                    newFolders[i].hash = folder.hash
                    
                    if newFolders[i].unreadCount == nil {
                        newFolders[i].unreadCount = folder.unreadCount
                    }
                    
                    if newFolders[i].messagesCount == nil {
                        newFolders[i].messagesCount = folder.messagesCount
                    }
                    
                    break
                }
            }
        }
        
        folders = compressedFolders(folders: newFolders)
    }
    
    func updateFolder(folder: String, hash: String) {
        var expandedFolders = self.expandedFolders(folders: folders)
        
        for i in 0..<expandedFolders.count {
            if expandedFolders[i].fullName == folder {
                expandedFolders[i].hash = hash
                break
            }
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
        for folder in expandedFolders(folders: folders) {
            if folder.fullName == name {
                return folder.mails
            }
        }
        
        return []
    }
    
    func setMailsForFolder(mails: [APIMail], folder: String) {
        var folders = expandedFolders(folders: self.folders)
        
        for i in 0..<folders.count {
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
