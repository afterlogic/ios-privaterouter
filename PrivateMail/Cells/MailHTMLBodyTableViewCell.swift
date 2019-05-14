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
    
    weak open var delegate: UITableViewDelegateExtensionProtocol?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        webView.isOpaque = false
        webView.backgroundColor = .clear
        
        webView.scrollView.alwaysBounceVertical = false
        webView.delegate = self
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    func updateHeight(withAction: Bool) {
        heightConstraint.constant = webView.scrollView.contentSize.height + 25.0
        
        if withAction {
            delegate?.cellSizeDidChanged()
        }
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
