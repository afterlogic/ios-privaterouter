//
//  MailHTMLBodyTableViewCell.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import SwiftTheme

class MailHTMLBodyTableViewCell: UITableViewCell {

    @IBOutlet var webView: UIWebView!
    @IBOutlet var heightConstraint: NSLayoutConstraint!
    
    var isEditor = false
    
    weak open var delegate: UITableViewDelegateExtensionProtocol?
    
    var htmlText: String {
        get {
            guard webView != nil else {
                return ""
            }
            return getTextFromWebView()
        }
        set {
            guard webView != nil else {
                return
            }
            webView.loadHTMLString(wrapTextWithHtml(text: newValue), baseURL: nil)
        }
    }
    
    var isAllowTheming: Bool = true {
        didSet {
            guard oldValue != isAllowTheming, webView != nil else {
                return
            }
            
            if isAllowTheming {
                theme_backgroundColor = .surface
            } else {
                theme_backgroundColor = nil
                backgroundColor = .white
            }
            
            webView.loadHTMLString(wrapTextWithHtml(text: htmlText), baseURL: nil)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        theme_backgroundColor = .surface
        
        webView.isOpaque = false
        webView.backgroundColor = .clear
        
        webView.scrollView.bounces = false
        webView.delegate = self
        
        webView.loadHTMLString(wrapTextWithHtml(text: ""), baseURL: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIApplication.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateTheme), name: .themeUpdate, object: nil)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    func updateHeight(withAction: Bool) {
        let height = webView.stringByEvaluatingJavaScript(from: "document.body.offsetHeight;") ?? "100"
        
        heightConstraint.constant = max(CGFloat((height as NSString).floatValue), 200.0)
        
        if isEditor {
            ComposeMailModelController.shared.mail.htmlBody = getTextFromWebView()
        }
            
        if withAction {
            delegate?.cellSizeDidChanged()
        }
    }
    
    private func getTextFromWebView() -> String {
        let script = "document.body.innerHTML;"
        let text = webView.stringByEvaluatingJavaScript(from: script) ?? ""
        return text
    }
    
    @objc func keyboardWillHide(notification: Notification) {
        updateHeight(withAction: true)
    }
    
    @objc func updateTheme() {
        htmlText = getTextFromWebView()
    }
    
    private func updateStyle(_ update: [String: Any]) {
        update.forEach { (key, value) in
            webView.stringByEvaluatingJavaScript(from: "document.getElementsByTagName('body')[0].style.\(key)=\"\(value)\"")
        }
    }
    
    private func wrapTextWithHtml(text: String) -> String {
        """
        <style>
        #editor {
            font-family: -apple-system;
            font-size: 14pt;
            color: \(textColorHex());
            
            .element:read-write:focus {
                outline: none;
            }
        }
        </style>
        <body id="editor" contenteditable="true">\(text)</body>
        """
    }
    
    private func textColorHex() -> String {
        isAllowTheming
            ? ThemeManager.string(for: "OnSurfaceMajorTextColor") ?? "#000"
            : "#000"
    }
}


extension MailHTMLBodyTableViewCell: UITableViewCellExtensionProtocol {
    static func cellID() -> String {
        return "MailHTMLBodyTableViewCell"
    }
}


extension MailHTMLBodyTableViewCell: UIWebViewDelegate {
    func webViewDidFinishLoad(_ webView: UIWebView) {
        updateStyle([
            "color": textColorHex(),
            "fontFamily": "-apple-system",
            "fontSize": 14
        ])
        updateHeight(withAction: true)
    }
}
