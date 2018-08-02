//
//  SavedTableViewController.swift
//  News App
//
//  Created by Vikas Nair on 8/2/18.
//  Copyright © 2018 Vikas Nair. All rights reserved.
//

import UIKit
import Firebase
import Alamofire
import SafariServices
import DGElasticPullToRefresh

class SavedTableViewController: UITableViewController, SFSafariViewControllerDelegate {
    
    // MARK: Properties

    let db = Firestore.firestore()
    let userID = Auth.auth().currentUser!.uid
    var saved: [Article] = []
    let loadingView = DGElasticPullToRefreshLoadingView()
    
    // MARK: UIViewController Delegate

    override func viewDidLoad() {
        super.viewDidLoad()
        self.getSaved()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupUI()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: UITableViewController Delegate

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.contentView.backgroundColor = UIColor.white
        header.textLabel?.font = UIFont.systemFont(ofSize: 17, weight: UIFont.Weight.bold)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return saved.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "articleCell", for: indexPath) as! ArticleTableViewCell
        let article = saved[indexPath.row]
        cell.article = article
        cell.titleLabel.text = article.title
        cell.sourceLabel.text = article.source
        
        if let date = self.dateFromISO(article.date) {
            cell.dateLabel.text = "· \(formatDate(date))"
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let article = saved[indexPath.row]
        let safari = SFSafariViewController(url: article.url)
        safari.delegate = self
        safari.preferredControlTintColor = APP_COLOR
        
        self.present(safari, animated: true, completion: nil)
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: Data Functions
    
    func getSaved() {
        retrieveSavedFromCache()
        
        Auth.auth().currentUser?.getIDToken(completion: { (token, error) in
            guard error == nil, token != nil else {
                self.tableView.dg_stopLoading()
                return
            }
            
            let headers: HTTPHeaders = [
                "Authorization" : "Bearer \(token!)",
                "Accept" : "application/json",
                "Content-Type" : "application/json"
            ]
            
            Alamofire.request("https://us-central1-dossier-ace51.cloudfunctions.net/getSaved?userID=\(self.userID)", method: .get, headers: headers).responseJSON { (response) in
                guard response.error == nil, response.data != nil else {
                    print("error with alamofire response in getsaved: \(String(describing: response.error))")
                    self.tableView.dg_stopLoading()
                    return
                }
                
                DispatchQueue.global(qos: .background).async {
                    do {
                        guard let items = try JSONSerialization.jsonObject(with: response.data!, options: .mutableContainers) as? [[String : Any]] else {
                            DispatchQueue.main.async {
                                print("failed to parse JSON")
                                self.tableView.dg_stopLoading()
                            }
                            
                            return
                        }
                        
                        var savedSaved: [Article] = []
                        
                        var count = 0
                        
                        items.forEach({ (item) in
                            guard let source = item["source"] as? String, let title = item["title"] as? String, let utf8 = title.replacingOccurrences(of: "\\s*(\\p{Po}\\s?)\\s*", with: "$1", options: [.regularExpression]).cString(using: .utf8), let unicodeTitle = String(utf8String: utf8), let urlStr = item["url"] as? String, let url = URL(string: urlStr), let category = item["category"] as? String, let date = item["date"] as? String else {
                                count += 1
                                print(count, item)
                                return
                            }
                            
                            // format date from string
                            
                            let article = Article(source: source, title: unicodeTitle, url: url, category: category, date: date)
                            savedSaved.append(article)
                        })
                        
                        DispatchQueue.main.async {
                            self.saved = savedSaved
                            self.cacheSaved()
                            self.tableView.reloadData()
                            self.tableView.dg_stopLoading()
                        }
                    } catch {
                        print("error parsing json: \(String(describing: error))")
                        self.tableView.dg_stopLoading()
                    }
                }
            }
        })
    }
    
    func retrieveSavedFromCache() {
        guard saved.isEmpty, let cache = UserDefaults.standard.object(forKey: "saved") as? Data, let data = NSKeyedUnarchiver.unarchiveObject(with: cache) as? Data else { return }
        
        do {
            self.saved = try PropertyListDecoder().decode([Article].self, from: data)
            tableView.reloadData()
        } catch {
            print(String(describing: error))
        }
    }
    
    func cacheSaved() {
        do {
            let data = try PropertyListEncoder().encode(self.saved)
            let cache = NSKeyedArchiver.archivedData(withRootObject: data)
            UserDefaults.standard.set(cache, forKey: "saved")
        } catch {
            print(String(describing: error))
        }
    }
    
    // MARK: UI Functions
    
    func dayDifference(from date: Date) -> Int {
        let calendar = NSCalendar.current
        
        if calendar.isDateInYesterday(date) { return -1 }
        else if calendar.isDateInToday(date) { return 0 }
        else {
            let startOfNow = calendar.startOfDay(for: Date())
            let startOfTimeStamp = calendar.startOfDay(for: date)
            let components = calendar.dateComponents([.day], from: startOfNow, to: startOfTimeStamp)
            let day = components.day!
            return day
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let difference = dayDifference(from: date)
        let formatter = DateFormatter()
        
        if difference > 0 {
            print("what the fuck")
            formatter.dateFormat = "MMM d, h:mm a"
        } else if difference == 0 {
            formatter.dateFormat = "'Oggi,' h:mm a"
        } else if difference > -7 {
            formatter.dateFormat = "E MMM d, h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }
        
        formatter.locale = Locale(identifier: "it_IT")
        formatter.timeZone = TimeZone.current
        
        return formatter.string(from: date)
    }
    
    func dateFromISO(_ str: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter.date(from: str)
    }
    
    func setupUI() {
        self.title = "Saved"
        
        initializePullToRefresh()
        
        guard let navigationBar = self.navigationController?.navigationBar else { return }
        
        //        navigationBar.setBackgroundImage(UIImage(named: "Navigation"), for: .default)
        
        navigationBar.titleTextAttributes = [NSAttributedStringKey.font: UIFont.init(name: "DIN Condensed", size: 32), NSAttributedStringKey.foregroundColor: UIColor.white]
        navigationBar.barTintColor = APP_COLOR
        navigationBar.tintColor = UIColor.white
        navigationBar.shadowImage = UIImage() // UIImage(color: APP_COLOR)
        navigationBar.isTranslucent = false
        
        UIApplication.shared.statusBarStyle = .lightContent
    }
    
    func initializePullToRefresh() {
        tableView.dg_addPullToRefreshWithActionHandler({
            self.getSaved()
        }, loadingView: self.loadingView)
        
        self.loadingView.tintColor = UIColor.white
        tableView.dg_setPullToRefreshFillColor(APP_COLOR)
    }
    
    // MARK: SFSafariViewController Delegate
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
}
