//
//  PreferencesViewController.swift
//  News App
//
//  Created by Vikas Nair on 9/23/18.
//  Copyright © 2018 Vikas Nair. All rights reserved.
//

import UIKit
import BEMCheckBox
import Firebase

class PreferencesViewController: UIViewController {
    
    // MARK: Outlets
    
    @IBOutlet weak var nationalBox: BEMCheckBox!
    @IBOutlet weak var entertainmentBox: BEMCheckBox!
    @IBOutlet weak var sportBox: BEMCheckBox!
    @IBOutlet weak var worldBox: BEMCheckBox!
    @IBOutlet weak var cultureBox: BEMCheckBox!
    
    // MARK: Properties
    
    let db = Firestore.firestore()
    
    // MARK: UIViewController Delegate
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: Functions
    
    func setupUI() {
        for box in [nationalBox, entertainmentBox, sportBox, worldBox, cultureBox] {
            box?.onAnimationType = .bounce
            box?.offAnimationType = .bounce
        }
    }
    
    // don't look at this
    func save() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        var preference = 0
        
        if nationalBox.isEnabled {
            preference += 1
        }
        
        if entertainmentBox.isEnabled {
            preference -= 1
        }
        
        if sportBox.isEnabled {
            preference -= 1
        }
        
        if worldBox.isEnabled {
            preference += 1
        }
        
        if cultureBox.isEnabled {
            preference -= 1
        }
        
        db.collection("users").document(userID).updateData([
            "choice": preference != 0 ? (preference > 0 ? "hard" : "soft") : "even"
        ])
    }
    
    // MARK: Actions
    
    @IBAction func enterApp(_ sender: Any) {
        save()
        UserDefaults.standard.set(true, forKey: "preferences")
        self.dismiss(animated: true, completion: nil)
    }
}
