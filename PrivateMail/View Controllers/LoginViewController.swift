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
    
    @IBOutlet var bottomConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.isNavigationBarHidden = true
        
        emailTextField.delegate = self
        passwordTextField.delegate = self
        
        emailTextField.placeholder = NSLocalizedString("Email", comment: "")
        passwordTextField.placeholder = NSLocalizedString("Password", comment: "")
        loginButton.setTitle(NSLocalizedString("LOGIN", comment: ""), for: .normal)
        
        loginButton.layer.cornerRadius = loginButton.frame.size.height / 2.0
        loginView.layer.cornerRadius = loginView.frame.size.height / 2.0
        passwordView.layer.cornerRadius = passwordView.frame.size.height / 2.0
        
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
        if let login = emailTextField.text {
            if login.count > 0 {
                if let password = passwordTextField.text {
                    if password.count > 0 {
                        view.isUserInteractionEnabled = false
                        proceedLogin(login: login, password: password)
                    } else {
                        SVProgressHUD.showInfo(withStatus: NSLocalizedString("Please enter password", comment: ""))
                    }
                }
            } else {
                SVProgressHUD.showInfo(withStatus: NSLocalizedString("Please enter email", comment: ""))
            }
        }
    }
    
    private func proceedLogin(login: String, password: String) {
        guard let domain = extractDomainFromLogin(login) else {
            return
        }
    
        let progressCompletion = ProgressHUD.showWithCompletion()
        
        API.shared.autoDiscover(domain: domain) { (url, error) in
            guard let url = url, error == nil else {
                if let error = error {
                    progressCompletion(.error(error.localizedDescription))
                } else {
                    progressCompletion(.dismiss)
                }
                DispatchQueue.main.async {
                    self.view.isUserInteractionEnabled = true
                }
                return
            }
            
            Urls.baseURL = url
            API.shared.cancelAllRequests()
            API.shared.removeCookies()
    
            API.shared.login(login: login, password: password) { (success, error) in
                DispatchQueue.main.async {
                    self.view.isUserInteractionEnabled = true
                }
                
                guard success, error == nil else {
                    if let error = error {
                        if let apiError = error as? APIError, apiError.code == 108 {
                            progressCompletion(.dismiss)
                            DispatchQueue.main.async {
                                self.performSegue(withIdentifier: "showUserLimits", sender: nil)
                            }
                        } else {
                            progressCompletion(.error(error.localizedDescription))
                        }
                    } else {
                        progressCompletion(.dismiss)
                    }
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
