//
//  LoginViewController.swift
//  PrivateMail
//
//  Created by Артём Абрамов
//  Copyright © 2019 PrivateRouter. All rights reserved.
//

import UIKit
import SVProgressHUD

class LoginViewController: UIViewController {
    
    @IBOutlet var emailTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var loginButton: UIButton!
    @IBOutlet var loginView: UIView!
    @IBOutlet var passwordView: UIView!
    @IBOutlet var hostView: UIView!
    @IBOutlet var hostTextField: UITextField!
    @IBOutlet var hostConstraint: NSLayoutConstraint!
    
    @IBOutlet var bottomConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        hostConstraint.isActive = false
        hostView.isHidden = true
        
        navigationController?.isNavigationBarHidden = true
        
        emailTextField.delegate = self
        passwordTextField.delegate = self
        
        emailTextField.placeholder = Strings.login
        passwordTextField.placeholder = Strings.password
        hostTextField.placeholder = Strings.host
        loginButton.setTitle(Strings.login, for: .normal)
        
        loginButton.layer.cornerRadius = loginButton.frame.size.height / 2.0
        loginView.layer.cornerRadius = loginView.frame.size.height / 2.0
        passwordView.layer.cornerRadius = passwordView.frame.size.height / 2.0
        hostView.layer.cornerRadius = passwordView.frame.size.height / 2.0
        
        #if DEBUG
        emailTextField.text = "test@afterlogic.com"
        passwordTextField.text = "p12345q"
        #endif
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIApplication.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIApplication.keyboardWillHideNotification, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Buttons
    
    @IBAction func loginButtonAction(_ sender: Any) {
        guard let login = emailTextField.text, login.isNotEmpty else {
            SVProgressHUD.showInfo(withStatus: Strings.pleaseEnterEmail)
            return
        }
        
        guard let password = passwordTextField.text, password.isNotEmpty else {
            SVProgressHUD.showInfo(withStatus: Strings.pleaseEnterPassword)
            return
        }
        
        if hostView.isHidden {
            proceedLogin(login: login, password: password)
        } else {
            guard let urlString = hostTextField.text, let url = URL(string: urlString) else {
                SVProgressHUD.showInfo(withStatus: Strings.specifyYourServerUrl)
                return
            }
            
            proceedLogin(login: login, password: password, baseUrl: url)
        }
    }
    
    private func proceedLogin(login: String, password: String) {
        setIsUserInteractionEnabled(false)
        
        let progressCompletion = ProgressHUD.showWithCompletion()
        
        API.shared.autoDiscover(email: login) { (url, error) in
            guard let url = url, error == nil else {
                self.autoDiscoverFailed(withError: error, progressCompletion: progressCompletion)
                return
            }
            
            self.proceedLogin(login: login, password: password, baseUrl: url, progressCompletion: progressCompletion)
        }
    }
    
    private func autoDiscoverFailed(withError error: Error?,
                                    progressCompletion: @escaping ProgressHUD.CompletionHandler) {
        UrlsManager.shared.baseUrl = nil
    
        self.setIsUserInteractionEnabled(true)
    
        if let error = error {
            if error is AutodiscoverError {
                progressCompletion(.error(Strings.specifyYourServerUrl))
                DispatchQueue.main.async {
                    self.hostView.isHidden = false
                    self.hostConstraint.isActive = true
                }
            } else {
                progressCompletion(.error(error.localizedDescription))
            }
        } else {
            progressCompletion(.dismiss)
        }
    }
    
    private func proceedLogin(login: String,
                              password: String,
                              baseUrl: URL,
                              progressCompletion: ProgressHUD.CompletionHandler? = nil) {
        let progressCompletion = progressCompletion ?? ProgressHUD.showWithCompletion()
    
        setIsUserInteractionEnabled(false)
        
        UrlsManager.shared.baseUrl = baseUrl
    
        API.shared.login(login: login, password: password) { (success, error) in
            self.setIsUserInteractionEnabled(true)
        
            guard success, error == nil else {
                self.loginDidFailed(withError: error, progressCompletion: progressCompletion)
                return
            }
        
            API.shared.getAccounts { (result, error) in
                if let error = error {
                    progressCompletion(.error(error.localizedDescription))
                } else {
                    progressCompletion(.dismiss)
                }
            
                DispatchQueue.main.async {
                    self.dismiss(animated: true, completion: nil)
                }
            }
        }
    }
    
    private func loginDidFailed(withError error: Error?, progressCompletion: @escaping ProgressHUD.CompletionHandler) {
        if let error = error {
            if let apiError = error as? APIError {
                switch apiError.code {
                case 101, 102:
                    progressCompletion(.error(Strings.loginFailedInvalidCredentials))
                case 108: // User limits
                    progressCompletion(.dismiss)
                    DispatchQueue.main.async {
                        self.performSegue(withIdentifier: "showUserLimits", sender: nil)
                    }
                default:
                    progressCompletion(.error(error.localizedDescription))
                }
            } else {
                progressCompletion(.error(error.localizedDescription))
            }
        } else {
            progressCompletion(.dismiss)
        }
    }
    
    private func setIsUserInteractionEnabled(_ isEnabled: Bool) {
        if Thread.isMainThread {
            view.isUserInteractionEnabled = isEnabled
        } else {
            DispatchQueue.main.async {
                self.view.isUserInteractionEnabled = isEnabled
            }
        }
    }
    
    private func extractDomainFromLogin(_ login: String) -> String? {
        guard let indexOfEmailChar = login.firstIndex(of: "@") else {
            return nil
        }
        
        let startDomainIndex = login.index(after: indexOfEmailChar)
        return login[startDomainIndex...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    @IBAction func eyeButtonAction(_ sender: UIButton) {
        passwordTextField.isSecureTextEntry = !passwordTextField.isSecureTextEntry
        
        let icon = UIImage(named: passwordTextField.isSecureTextEntry ? "password_eye_closed" : "password_eye_opened")
        sender.setImage(icon, for: .normal)
    }
    
    
    // MARK: - Text Fields
    
    @IBAction func textFieldDidChanged(_ sender: UITextField) {
        sender.text = sender.text?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    @IBAction func hostEditingDidBegin(_ sender: UITextField) {
        if sender.text?.isEmpty ?? true {
            let initialText = "https://"
            sender.text = initialText
            
            if let position = sender.position(from: sender.beginningOfDocument, offset: initialText.count) {
                sender.selectedTextRange = sender.textRange(from: position, to: position)
            }
        }
    }
    
    // MARK: - Keyboard
    
    @objc func keyboardWillShow(notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            bottomConstraint.constant = keyboardSize.height + 50.0
            
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: {
                self.view.layoutIfNeeded()
            }, completion: nil)
        }
    }
    
    @objc func keyboardWillHide(notification: Notification) {
        bottomConstraint.constant = 0.0
        
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    
    // MARK: - Other
    
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
    }
    
}


extension LoginViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if textField == emailTextField {
            passwordTextField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            loginButtonAction(self)
        }
        
        return false
    }
    
}
