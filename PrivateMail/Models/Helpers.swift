//
//  Helpers.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import Foundation
import UIKit

protocol UITableViewCellExtensionProtocol: NSObjectProtocol {
   static func cellID() -> String
}

protocol UITableViewDelegateExtensionProtocol: NSObjectProtocol {
    func cellSizeDidChanged()
}

protocol UITextViewDelegateExtensionProtocol: NSObjectProtocol {
    func textViewDidChanged(textView: UITextView)
}


extension UITableView {
    func register<T: UITableViewCellExtensionProtocol>(cellClass: T) {
        register(UINib.init(nibName: T.cellID(), bundle: Bundle.main), forCellReuseIdentifier: T.cellID())
    }
}

extension UIRefreshControl {
    func beginRefreshing(in tableView: UITableView) {
        DispatchQueue.main.async {
            self.beginRefreshing()
            let offsetPoint = CGPoint.init(x: 0, y: -self.frame.size.height)
            tableView.setContentOffset(offsetPoint, animated: true)
        }
    }
}

extension String {
    func height(withConstrainedWidth width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: font], context: nil)
        
        return ceil(boundingBox.height)
    }
    
    func width(withConstrainedHeight height: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: .greatestFiniteMagnitude, height: height)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: font], context: nil)
        
        return ceil(boundingBox.width)
    }
}

extension Date {
    func getDateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .none
 
        if Calendar.current.isDateInToday(self) {
            formatter.timeStyle = .short
        } else if Calendar.current.isDateInYesterday(self) {
            formatter.timeStyle = .short

            return NSLocalizedString("Yesterday \(formatter.string(from: self))", comment: "")
        } else if Calendar.current.isDate(self, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "dd MMM"
        } else {
            formatter.dateStyle = .medium
        }
    
        return formatter.string(from: self)
    }
    
    func getFullDateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .none
        
        formatter.dateFormat = "E, d MMM yyyy "
        
        let dateString = formatter.string(from: self)
        
        formatter.dateFormat = ""
        formatter.timeStyle = .short
        
        return dateString + formatter.string(from: self)
    }
}

extension UITextView {
    @IBInspectable var doneAccessory: Bool{
        get {
            return self.doneAccessory
        }
        set (hasDone) {
            if hasDone {
                addDoneButtonOnKeyboard()
            }
        }
    }
    
    func addDoneButtonOnKeyboard() {
        let doneToolbar: UIToolbar = UIToolbar(frame: CGRect.init(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50))
        doneToolbar.barStyle = .default
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done: UIBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), style: .done, target: self, action: #selector(self.doneButtonAction))
        
        let items = [flexSpace, done]
        doneToolbar.items = items
        doneToolbar.sizeToFit()
        
        self.inputAccessoryView = doneToolbar
    }
    
    @objc func doneButtonAction() {
        self.resignFirstResponder()
    }
    
}
