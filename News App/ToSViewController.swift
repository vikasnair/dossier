//
//  ToSViewController.swift
//  News App
//
//  Created by Vikas Nair on 7/23/18.
//  Copyright © 2018 Vikas Nair. All rights reserved.
//

import UIKit
import Firebase

class ToSViewController: UIViewController {
    
    // MARK: Properties
    
    let db = Firestore.firestore()
    
    // MARK: UIViewController Delegate

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: Actions
    
    @IBAction func disagree(_ sender: Any) {
        logout()
//        fatalError("lol")
        self.dismiss(animated: true, completion: nil)
    }
    
    func logout() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("error in signout \(String(describing: error))")
        }
    }
    
    @IBAction func agree(_ sender: Any) {
        UserDefaults.standard.set(true, forKey: "ToS")
        self.dismiss(animated: true, completion: nil)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
