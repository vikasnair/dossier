//
//  ArticleTableViewCell.swift
//  News App
//
//  Created by Vikas Nair on 5/14/18.
//  Copyright © 2018 Vikas Nair. All rights reserved.
//

import UIKit
import Firebase
import Alamofire

class ArticleTableViewCell: UITableViewCell {

    // MARK: Outlets
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var sourceLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    // MARK: Properties
    
    var article: Article!
    
    // MARK: UITableViewCell Delegate
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    @IBAction func openInSafari(_ sender: Any) {
        UIApplication.shared.open(self.article.url, options: [:], completionHandler: nil)
    }
    
    @IBAction func saveArticle(_ sender: Any) {
        Auth.auth().currentUser?.getIDToken(completion: { (token, error) in
            guard error == nil, token != nil else { return }
            
            let headers: HTTPHeaders = [
                "Authorization" : "Bearer \(token!)",
                "Content-Type" : "application/json"
            ]
            
            do {
                let parameters: [String : Any] = [
                    "article" : try String(data: JSONEncoder().encode(self.article), encoding: String.Encoding.utf8)
                ]
                
                var request = try URLRequest(url: "https://us-central1-dossier-ace51.cloudfunctions.net/saveArticle?userID=\(Auth.auth().currentUser!.uid)", method: .post, headers: headers)
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
                
                Alamofire.request(request).response(completionHandler: { (response) in
                    guard response.error == nil, response.data != nil else {
                        print(String(describing: response.error))
                        return
                    }
                    
                    print("successfully saved article")
                })
            } catch {
                print(String(describing: error))
            }
        })
    }
}
