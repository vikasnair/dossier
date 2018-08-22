//
//  ProgressViewController.swift
//  News App
//
//  Created by Vikas Nair on 8/21/18.
//  Copyright © 2018 Vikas Nair. All rights reserved.
//

import UIKit
import Alamofire
import Firebase

class ProgressViewController: UIViewController {
    
    // MARK: Properties
    
    let userID = Auth.auth().currentUser!.uid
    var totalReadCount: Int = 0
    var weeklyReadCount: Int = 0
    var totalReadTime: Int = 0
    
    // MARK: Outlets
    
    @IBOutlet weak var totalReadLabel: UILabel!
    @IBOutlet weak var weeklyReadLabel: UILabel!
    @IBOutlet weak var totalReadTimeLabel: UILabel!
    
    // MARK: UIViewController Delegate
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupUI()
        self.loadProgress()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setupUI()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: Functions
    
    func loadProgress() {
        Auth.auth().currentUser?.getIDToken(completion: { (token, error) in
            guard error == nil, token != nil else {
                return
            }

            let headers: HTTPHeaders = [
                "Authorization" : "Bearer \(token!)",
                "Accept" : "application/json",
                "Content-Type" : "application/json"
            ]

            Alamofire.request("https://us-central1-dossier-ace51.cloudfunctions.net/getProgress?userID=\(self.userID)", method: .get, headers: headers).responseJSON { (response) in
                guard response.error == nil, response.data != nil else {
                    print("error with alamofire response in getprogress: \(String(describing: response.error))")
                    return
                }

                DispatchQueue.global(qos: .background).async {
                    do {
                        guard let counts = try JSONSerialization.jsonObject(with: response.data!, options: .mutableContainers) as? [Int] else {
                            DispatchQueue.main.async {
                                print("failed to parse JSON")
                            }

                            return
                        }

                        DispatchQueue.main.async {
                            self.totalReadCount = counts[0]
                            self.weeklyReadCount = counts[1]
                            self.totalReadTime = counts[2]
                            self.totalReadLabel.text = "\(self.totalReadCount)"
                            self.weeklyReadLabel.text = "\(self.weeklyReadCount)"
                            self.totalReadTimeLabel.text = "\(self.totalReadTime)"
                            
                        }
                    } catch {
                        print("error parsing json: \(String(describing: error))")
                    }
                }
            }
        })
    }
    
    func setupUI() {
        navigationController!.view.layoutSubviews()
        self.view.backgroundColor = APP_COLOR
        UIApplication.shared.statusBarStyle = .lightContent
    }
}
