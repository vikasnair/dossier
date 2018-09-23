//
//  AuthViewController.swift
//  News App
//
//  Created by Vikas Nair on 5/14/18.
//  Copyright © 2018 Vikas Nair. All rights reserved.
//

import UIKit
import Firebase
import Pastel

class AuthViewController: UIViewController {
    
    // MARK: Properties
    
    var db: Firestore!
    var handle: AuthStateDidChangeListenerHandle?

    override func viewDidLoad() {
        super.viewDidLoad()
        db = Firestore.firestore()
        setupUI()
//        signOut()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        autoLogin()
        setupUI()
    }
    
    // MARK: Functions
    
    func enterApp() {
        self.navigationController?.popToRootViewController(animated: false)
        let controller = self.storyboard?.instantiateViewController(withIdentifier: "MenuController")
        self.present(controller!, animated: false)
    }
    
    func autoLogin() {
        if handle != nil {
            Auth.auth().removeStateDidChangeListener(handle!)
        }
        
        handle = Auth.auth().addStateDidChangeListener { (auth, user) in
            print("CHECKING")
            if user != nil {
                print("User is signed in.")
                print(user!.uid)
                
                self.db.collection("users").document(user!.uid).getDocument(completion: { (document, error) in
                    guard error == nil else {
                        self.signOut()
                        return
                    }
                    
                    if !(document != nil && document!.exists) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
                            self.autoLogin()
                        })
                    } else {
                        self.enterApp()
                    }
                })
            } else {
                print("User is NOT signed in.")
            }
        }
    }
    
    func signOut() {
        do {
            UserDefaults.standard.removeObject(forKey: "feed")
            UserDefaults.standard.removeObject(forKey: "ToS")
            UserDefaults.standard.removeObject(forKey: "preferences")
            try Auth.auth().signOut()
        } catch {
            print("error signing out: \(String(describing: error))")
        }
    }
    
    func initializeGradient() {
        let pastelView = PastelView(frame: view.bounds)
        
        pastelView.startPastelPoint = .bottomLeft
        pastelView.endPastelPoint = .topRight
        
        pastelView.animationDuration = 3
        pastelView.setColors([APP_COLOR, SECONDARY_COLOR, TERTIARY_COLOR, UIColor.white])
        
        pastelView.startAnimation()
        view.insertSubview(pastelView, at: 0)
    }
    
    func setupUI() {
        guard let navigationBar = self.navigationController?.navigationBar else { return }
        
        navigationBar.titleTextAttributes = [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 24, weight: UIFont.Weight.heavy), NSAttributedStringKey.foregroundColor: APP_COLOR]
        navigationBar.barTintColor = .white
        navigationBar.tintColor = APP_COLOR
        navigationBar.shadowImage = UIImage()
        navigationBar.isTranslucent = false
        navigationBar.isHidden = true
        
        UIApplication.shared.statusBarStyle = .lightContent
        initializeGradient()
    }
}
