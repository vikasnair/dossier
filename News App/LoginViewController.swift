//
//  LoginViewController.swift
//  News App
//
//  Created by Vikas Nair on 5/14/18.
//  Copyright © 2018 Vikas Nair. All rights reserved.
//

import UIKit
import Firebase
import PhoneNumberKit
import TransitionButton

class LoginViewController: UIViewController {
    
    // MARK: Outlets

    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var phoneField: PhoneNumberTextField!
    @IBOutlet weak var switchButton: UIButton!
    @IBOutlet weak var loginButton: TransitionButton!
    
    // MARK: UIViewController Delegate
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: Actions
    
    @IBAction func login(_ sender: Any) {
        loginButton.startAnimation()
        
        if emailField.isEnabled {
            guard let email = emailField.text, let password = passwordField.text else {
                loginButton.stopAnimation(animationStyle: .shake, revertAfterDelay: 1, completion: nil)
                return
            }
           
            loginWithEmail(email, password)
        } else {
            guard phoneField.isValidNumber else {
                loginButton.stopAnimation(animationStyle: .shake, revertAfterDelay: 1, completion: nil)
                return
            }
            
            do {
                let formatter = PhoneNumberKit()
                let phone = try formatter.parse(self.phoneField.nationalNumber, withRegion: self.phoneField.currentRegion, ignoreType: true)
                let number = formatter.format(phone, toType: .international)
                loginWithPhone(number)
            } catch {
                loginButton.stopAnimation(animationStyle: .shake, revertAfterDelay: 1, completion: nil)
                print("error parsing phone: \(error)")
            }
        }
    }
    
    @IBAction func switchUI(_ sender: Any) {
        if phoneField.isEnabled {
            phoneField.text = nil
            phoneField.isEnabled = false
            phoneField.isHidden = true
            emailField.isEnabled = true
            emailField.isHidden = false
            passwordField.isEnabled = true
            passwordField.isHidden = false
            switchButton.setTitle("Continua con cellulare", for: .normal)
        } else {
            emailField.text = nil
            emailField.isEnabled = false
            emailField.isHidden = true
            passwordField.text = nil
            passwordField.isEnabled = false
            passwordField.isHidden = true
            phoneField.isEnabled = true
            phoneField.isHidden = false
            switchButton.setTitle("Continua con email", for: .normal)
        }
    }
    // MARK: Functions
    
    func logInWithCredential(_ credential: AuthCredential) {
        Auth.auth().signIn(with: credential, completion: { (user, error) in
            guard error == nil else {
                self.loginButton.stopAnimation(animationStyle: .shake, revertAfterDelay: 1, completion: nil)
                print("error in sign up w credential \(error!)")
                return
            }
            
            print("logged in with phone")
            
            self.loginButton.stopAnimation(animationStyle: .expand, revertAfterDelay: 1, completion: nil)
        })
    }
    
    func loginWithPhone(_ number: String) {
        PhoneAuthProvider.provider().verifyPhoneNumber(number, uiDelegate: nil) { (verification, error) in
            guard error == nil, let verification = verification else {
                self.loginButton.stopAnimation(animationStyle: .shake, revertAfterDelay: 1, completion: nil)
                print ("error in phone verify: \(error!)")
                return
            }
            
            let alert = UIAlertController(title: "Verify Phone", message: "We sent a text to your phone, enter below the code you received.", preferredStyle: .alert)
            alert.addTextField(configurationHandler: nil)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action: UIAlertAction!) in
                alert.dismiss(animated: true, completion: {
                    self.loginButton.stopAnimation(animationStyle: .shake, revertAfterDelay: 1, completion: nil)
                })
            }))
            
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action) in
                let code = alert.textFields!.first!.text!
                let credential = PhoneAuthProvider.provider().credential(withVerificationID: verification, verificationCode: code)
                
                self.logInWithCredential(credential)
            }))
            
            self.present(alert, animated: true, completion: nil)
            
            alert.view.tintColor = APP_COLOR
        }
    }
    
    func loginWithEmail(_ email: String, _ password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { (user, error) in
            guard error == nil, user != nil else {
                self.loginButton.stopAnimation(animationStyle: .shake, revertAfterDelay: 1, completion: nil)
                return
            }
            
            self.loginButton.stopAnimation(animationStyle: .expand, revertAfterDelay: 1, completion: nil)
            print("logged in with email")
        }
    }

    func setupUI() {
        formatTextField(phoneField, placeholder: "Cellulare")
        formatTextField(emailField, placeholder: "Email")
        formatTextField(passwordField, placeholder: "Password")
        
        emailField.isEnabled = false
        emailField.isHidden = true
        passwordField.isEnabled = false
        passwordField.isHidden = true
        
        addStyleTo(loginButton)
        
        guard let navigationBar = self.navigationController?.navigationBar else { return }
        
        navigationBar.titleTextAttributes = [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 24, weight: UIFont.Weight.heavy), NSAttributedStringKey.foregroundColor: APP_COLOR]
        navigationBar.barTintColor = .white
        navigationBar.tintColor = APP_COLOR
        navigationBar.shadowImage = UIImage()
        navigationBar.isTranslucent = false
    }
    
    func addStyleTo(_ button: TransitionButton) {
        button.spinnerColor = .white
        button.backgroundColor = APP_COLOR
        button.disabledBackgroundColor = APP_COLOR
        button.cornerRadius = button.frame.height / 2
    }
    
    func formatTextField(_ textField: UITextField, placeholder: String) {
        textField.layer.sublayerTransform = CATransform3DMakeTranslation(10, 0, 0)
        textField.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        textField.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [NSAttributedStringKey.foregroundColor: UIColor.darkGray])
        textField.textColor = APP_COLOR
        addUnderlineTo(textField, with: UIColor.darkGray.cgColor)
    }
    
    func addUnderlineTo(_ textField: UITextField, with color: CGColor) {
        let border = CALayer()
        let width = CGFloat(2.0)
        border.borderColor = color
        border.frame = CGRect(x: 0, y: textField.frame.size.height - width, width:  textField.frame.size.width, height: textField.frame.size.height)
        border.borderWidth = width
        textField.layer.addSublayer(border)
        textField.layer.masksToBounds = true
    }
}
