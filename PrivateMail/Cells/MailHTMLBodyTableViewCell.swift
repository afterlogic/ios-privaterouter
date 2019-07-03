//
//  MailHTMLBodyTableViewCell.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit

class MailHTMLBodyTableViewCell: UITableViewCell {

    @IBOutlet var webView: UIWebView!
    @IBOutlet var heightConstraint: NSLayoutConstraint!
    
    var isEditor = false
    
    weak open var delegate: UITableViewDelegateExtensionProtocol?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        webView.isOpaque = false
        webView.backgroundColor = .clear
        
        webView.scrollView.alwaysBounceVertical = false
        webView.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIApplication.keyboardWillHideNotification, object: nil)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    func updateHeight(withAction: Bool) {
        let height = webView.stringByEvaluatingJavaScript(from: "document.body.offsetHeight;") ?? "100"
        
        heightConstraint.constant = max(CGFloat((height as NSString).floatValue) + 25.0, 200.0)
        
        if isEditor {
            ComposeMailModelController.shared.mail.htmlBody = getText()
        }
            
        if withAction {
            delegate?.cellSizeDidChanged()
        }
    }
    
    func getText() -> String {
        let script = "document.body.innerHTML;"
        let text = webView.stringByEvaluatingJavaScript(from: script) ?? ""
        return text
    }
    
    @objc func keyboardWillHide(notification: Notification) {
        updateHeight(withAction: true)
    }
}


extension MailHTMLBodyTableViewCell: UITableViewCellExtensionProtocol {
    static func cellID() -> String {
        return "MailHTMLBodyTableViewCell"
    }
}


extension MailHTMLBodyTableViewCell: UIWebViewDelegate {
    func webViewDidFinishLoad(_ webView: UIWebView) {
        webView.stringByEvaluatingJavaScript(from: "document.getElementsByTagName('body')[0].style.fontFamily =\"-apple-system\"")
        webView.stringByEvaluatingJavaScript(from: "document.getElementsByTagName('body')[0].style.fontSize =\"14\"")
        updateHeight(withAction: true)
    }
}
