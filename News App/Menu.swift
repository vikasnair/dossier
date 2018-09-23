//
//  Menu.swift
//  News App
//
//  Created by Vikas Nair on 5/26/18.
//  Copyright © 2018 Vikas Nair. All rights reserved.
//

import UIKit
import HamburgerMenu
import Firebase

class Menu: MenuView {
    
    // MARK: Properties
    
    let db = Firestore.firestore()

    // MARK: Actions
    
    @IBAction func showProgress(_ sender: Any) {
        self.toggle(animated: true)
        NotificationCenter.default.post(name: Notification.Name("showProgress"), object: nil)
    }
    
    @IBAction func showSaved(_ sender: Any) {
        self.toggle(animated: true)
        NotificationCenter.default.post(name: Notification.Name("showSaved"), object: nil)
    }
    
    @IBAction func logout(_ sender: Any) {
        UserDefaults.standard.removeObject(forKey: "feed")
        UserDefaults.standard.removeObject(forKey: "saved")
        UserDefaults.standard.removeObject(forKey: "ToS")
        UserDefaults.standard.removeObject(forKey: "preferences")
        
        do {
            try Auth.auth().signOut()
            self.controller.dismiss(animated: true, completion: nil)
        } catch {
            print("error in signout \(String(describing: error))")
        }
    }
    
    @IBAction func deleteAccount(_ sender: Any) {
        let alert = UIAlertController(title: "Delete account?", message: nil, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action: UIAlertAction!) in
            alert.dismiss(animated: true, completion: nil)
        }))
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { (action: UIAlertAction!) in
            alert.dismiss(animated: true, completion: nil)
            
            guard let user = Auth.auth().currentUser else { return }
            
            self.db.collection("users").document(user.uid).delete()
            UserDefaults.standard.removeObject(forKey: "feed")
            UserDefaults.standard.removeObject(forKey: "saved")
            UserDefaults.standard.removeObject(forKey: "ToS")
            UserDefaults.standard.removeObject(forKey: "preferences")
            
            user.delete(completion: { (error) in
                if error != nil {
                    print("error in delete user: \(String(describing: error))")
                    
                    let errorAlert = UIAlertController(title: "Error deleting account.", message: "Try logging out and logging in again.", preferredStyle: .alert)
                    
                    errorAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action: UIAlertAction!) in
                        errorAlert.dismiss(animated: true, completion: nil)
                    }))
                    
                    self.viewContainingController()?.present(errorAlert, animated: true, completion: nil)
                    errorAlert.view.tintColor = APP_COLOR
                    
                    return
                }
                
                print("CURRENT USER AFTER DELETE", Auth.auth().currentUser)
                self.controller.dismiss(animated: true, completion: nil)
            })
        }))
        
        self.viewContainingController()?.present(alert, animated: true, completion: nil)
        
        alert.view.tintColor = APP_COLOR
    }
}
