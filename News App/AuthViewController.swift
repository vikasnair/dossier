//
//  AuthViewController.swift
//  News App
//
//  Created by Vikas Nair on 5/14/18.
//  Copyright © 2018 Vikas Nair. All rights reserved.
//

import UIKit
import Firebase

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
                    guard error == nil, let document = document, document.exists else {
                        self.signOut()
                        return user!.delete(completion: { (error) in
                            guard error != nil else { return print("how did it fuck up this badly" )}
                            print("user deleted")
                        })
                    }

                    self.enterApp()
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
            try Auth.auth().signOut()
        } catch {
            print("error signing out: \(String(describing: error))")
        }
    }
    
    func setupUI() {
        guard let navigationBar = self.navigationController?.navigationBar else { return }
        
        navigationBar.titleTextAttributes = [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 24, weight: UIFont.Weight.heavy), NSAttributedStringKey.foregroundColor: APP_COLOR]
        navigationBar.barTintColor = .white
        navigationBar.tintColor = APP_COLOR
        navigationBar.shadowImage = UIImage()
        navigationBar.isTranslucent = false
    }
}
