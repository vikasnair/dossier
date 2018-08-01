//
//  FeedTableViewController.swift
//  News App
//
//  Created by Vikas Nair on 5/14/18.
//  Copyright © 2018 Vikas Nair. All rights reserved.
//

import UIKit
import Firebase
import Alamofire
import SafariServices
import DGElasticPullToRefresh
import ResearchKit

class FeedTableViewController: UITableViewController, SFSafariViewControllerDelegate, ORKTaskViewControllerDelegate {
    
    // MARK: Properties
    
    let db = Firestore.firestore()
    let userID = Auth.auth().currentUser!.uid
    var articles: [Article] = []
    var distribution: String?
    let loadingView = DGElasticPullToRefreshLoadingView()
    var resurvey = false
    var promptedForAgreement = false
    var promptedForSurvey = false

    // MARK: UIViewController Delegate
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(logHours(notification:)), name: Notification.Name.init("logHours"), object: nil)
        
        agreeToTerms()
        
        DispatchQueue.global(qos: .background).async {
            while !UserDefaults.standard.bool(forKey: "ToS") {}
            
            DispatchQueue.main.async {
                self.getFeed()
                self.survey()
                self.markVisibleArticles()
            }
        }
    }
    
    func agreeToTerms() {
        self.promptedForAgreement = true
        if !UserDefaults.standard.bool(forKey: "ToS") {
            guard let vc = storyboard?.instantiateViewController(withIdentifier: "ToSNavigationController") else { return }
            self.navigationController?.present(vc, animated: true, completion: nil)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupUI()
        
        if promptedForAgreement, !UserDefaults.standard.bool(forKey: "ToS") {
            self.dismiss(animated: true, completion: nil)
        }
        
        if promptedForSurvey {
            self.getFeed()
            promptedForSurvey = false
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.statusBarStyle = .default
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
        return articles.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "articleCell", for: indexPath) as! ArticleTableViewCell
        let article = articles[indexPath.row]
        cell.titleLabel.text = article.title
        cell.sourceLabel.text = article.source
        
        if let date = self.dateFromISO(article.date) {
            cell.dateLabel.text = "· \(formatDate(date))"
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let article = articles[indexPath.row]
        let safari = SFSafariViewController(url: article.url)
        safari.delegate = self
        safari.preferredControlTintColor = APP_COLOR
        
        self.present(safari, animated: true, completion: {
            DispatchQueue.global(qos: .background).async {
                let start = Date()
                while !safari.isBeingDismissed {}
                self.mark([article], read: true, elapsed: Date().timeIntervalSince(start))
            }
        })
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: Functions
    
    func mark(_ articles: [Article], read: Bool, elapsed: TimeInterval?) {
        Auth.auth().currentUser?.getIDToken(completion: { (token, error) in
            guard error == nil, token != nil else { return }
           
            let headers: HTTPHeaders = [
                "Authorization" : "Bearer \(token!)",
                "Content-Type" : "application/json"
            ]
            
            do {
                var parameters: [String : Any] = [
                    "articles" : try String(data: JSONEncoder().encode(articles), encoding: String.Encoding.utf8)
                ]
                
                if read, let elapsed = elapsed {
                    parameters["elapsed"] = elapsed
                }
                
                var request = try URLRequest(url: "https://us-central1-dossier-ace51.cloudfunctions.net/markArticles?read=\(read)&userID=\(self.userID)", method: .post, headers: headers)
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
                
                Alamofire.request(request).response(completionHandler: { (response) in
                    guard response.error == nil, response.data != nil else {
                        print(String(describing: response.error))
                        return
                    }
                    
                    print("successfully marked articles as read: \(read) seen: \(!read)")
                })
            } catch {
                print(String(describing: error))
            }
        })
    }
    
    func markVisibleArticles() {
        guard let visibleRows = tableView.indexPathsForVisibleRows else { return }
        
        var articlesToMark: [Article] = []
        
        for path in visibleRows {
            articlesToMark.append(self.articles[path.row])
        }
        
        mark(articlesToMark, read: false, elapsed: nil)
    }
    
    @objc func logHours(notification: Notification) {
        guard let info = notification.userInfo, let elapsed = info["elapsed"] as? TimeInterval else { return }
        
        db.collection("users").document(userID).getDocument(completion: { (document, error) in
            guard error == nil, let document = document, let data = document.data() else { return }
            
            print("logging")
            
            if let timeSpent = data["timeSpent"] as? TimeInterval {
                self.db.collection("users").document(self.userID).updateData(["timeSpent" : timeSpent + elapsed])
            } else {
                self.db.collection("users").document(self.userID).updateData(["timeSpent" : elapsed])
            }
        })
    }
    
    func getFeed() {
        retrieveFeedFromCache()
        
        guard let distribution = distribution else {
            self.tableView.dg_stopLoading()
            return
        }
        
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
            
            Alamofire.request("https://us-central1-dossier-ace51.cloudfunctions.net/sendArticlesToUser?distribution=\(distribution)", method: .get, headers: headers).responseJSON { (response) in
                guard response.error == nil, response.data != nil else {
                    print("error with alamofire response in getfeed: \(String(describing: response.error))")
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
                        
//                        print(items)
                        
                        var feed: [Article] = []
                        
                        var count = 0
                        
                        items.forEach({ (item) in
                            guard let source = item["source"] as? String, let title = item["title"] as? String, let utf8 = title.replacingOccurrences(of: "\\s*(\\p{Po}\\s?)\\s*", with: "$1", options: [.regularExpression]).cString(using: .utf8), let unicodeTitle = String(utf8String: utf8), let urlStr = item["url"] as? String, let url = URL(string: urlStr), let category = item["category"] as? String, let date = item["date"] as? String else {
                                count += 1
                                print(count, item)
                                return
                            }
                            
                            // format date from string
                            
                            let article = Article(source: source, title: unicodeTitle, url: url, category: category, date: date)
                            feed.append(article)
                        })
                        
                        DispatchQueue.main.async {
                            self.articles = feed
                            self.cacheFeed()
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
    
    func retrieveFeedFromCache() {
        guard articles.isEmpty, let cache = UserDefaults.standard.object(forKey: "feed") as? Data, let data = NSKeyedUnarchiver.unarchiveObject(with: cache) as? Data else { return }
        
        do {
            self.articles = try PropertyListDecoder().decode([Article].self, from: data)
            tableView.reloadData()
        } catch {
            print(String(describing: error))
        }
    }
    
    func cacheFeed() {
        do {
            let data = try PropertyListEncoder().encode(self.articles)
            let cache = NSKeyedArchiver.archivedData(withRootObject: data)
            UserDefaults.standard.set(cache, forKey: "feed")
        } catch {
            print(String(describing: error))
        }
    }
    
    // MARK: Survey Functions
    
    func survey() {
        db.collection("users").document(userID).getDocument { (document, error) in
            guard error == nil, let document = document, let data = document.data(), let polled = data["polled"] as? Bool, let polledAgain = data["polledAgain"] as? Bool, let dateCreated = data["dateCreated"] as? Date else { return }
            
            self.distribution = data["distribution"] as? String
            self.resurvey = polled && !polledAgain && self.dayDifference(from: dateCreated) <= -30
            
            if (!polled || self.resurvey) {
                print("surveying")
                self.promptedForSurvey = true
                self.askResearchQuestions(again: self.resurvey)
            }
            
            if let appLaunchCount = data["appLaunchCount"] as? Int {
                if appLaunchCount % 3 == 0, let allowPrompts = data["allowPrompts"] as? Bool, allowPrompts, let seen = data["seen"] as? [String : [String : Any]] {
                    print("remember?")
                    self.doYouRemember(seen)
                }
                
                self.db.collection("users").document(self.userID).updateData([
                    "appLaunchCount" : appLaunchCount + 1
                ])
            }
        }
    }
    
    func doYouRemember(_ articles: [String : [String : Any]]) {
        var unmarkedArticleID: String?
        
        for key in articles.keys {
            guard let article = articles[key] else { continue }
            if let _ = article["remembers"] as? Bool { continue }
            unmarkedArticleID = key
            break
        }
        
        guard let articleID = unmarkedArticleID else { return }
        
        db.collection("articles").document(articleID).getDocument { (document, error) in
            guard error == nil, let document = document, let data = document.data(), let title = data["title"] as? String else { return }
            
            let alert = UIAlertController(title: "Ti ricordi di aver visto questo articolo?", message: title, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Sì", style: .default, handler: { (action: UIAlertAction!) in
                var updatedArticles = articles
                
                guard var updatedArticle = articles[articleID] else {
                    alert.dismiss(animated: true, completion: nil)
                    return
                }
                
                updatedArticle["remembers"] = true
                updatedArticles[articleID] = updatedArticle
                
                self.db.collection("users").document(self.userID).updateData([
                        "seen" : updatedArticles
                    ])
                
                alert.dismiss(animated: true, completion: nil)
            }))
            
            alert.addAction(UIAlertAction(title: "No", style: .default, handler: { (action: UIAlertAction!) in
                var updatedArticles = articles
                
                guard var updatedArticle = articles[articleID] else {
                    alert.dismiss(animated: true, completion: nil)
                    return
                }
                
                updatedArticle["remembers"] = false
                updatedArticles[articleID] = updatedArticle
                
                self.db.collection("users").document(self.userID).updateData([
                        "seen" : updatedArticles
                    ])
                
                alert.dismiss(animated: true, completion: nil)
            }))
            
            alert.addAction(UIAlertAction(title: "Non chiedermelo più", style: .cancel, handler: { (action: UIAlertAction!) in
                self.db.collection("users").document(self.userID).updateData([
                        "allowPrompts" : false
                    ])
                alert.dismiss(animated: true, completion: nil)
            }))
            
            self.present(alert, animated: true, completion: nil)
            
            alert.view.tintColor = APP_COLOR
        }
    }
    
    func askResearchQuestions(again: Bool) {
        
        // intro
        
        let introStep = ORKInstructionStep(identifier: "introStep")
        introStep.title = "Benvenuto su Dossier!"
        
        if again {
            introStep.detailText = "Grazie per aver partecipato al nostro studio. Ti chiediamo, per finire, di voler rispondere a delle brevi domande."
        } else {
            introStep.detailText = "Ti preghiamo di voler spendere un paio di minuti per rispondere a delle brevi domande."
        }
        
        // Q0
        
        let q0Step1 = ORKQuestionStep(identifier: "q0Step1", title: "Eta’", text: nil, answer: ORKNumericAnswerFormat(style: .integer, unit: nil, minimum: 12, maximum: 120))
        let q0Step2 = ORKQuestionStep(identifier: "q0Step2", title: "Sesso", text: nil, answer: ORKAnswerFormat.choiceAnswerFormat(with: .singleChoice, textChoices: [
                ORKTextChoice(text: "Uomo", value: "Uomo" as NSString),
                ORKTextChoice(text: "Donna", value: "Donna" as NSString)
            ]))
        let q0Step3 = ORKQuestionStep(identifier: "q0Step3", title: "Livello di Istruzione", text: nil, answer: ORKAnswerFormat.choiceAnswerFormat(with: .singleChoice, textChoices: [
            ORKTextChoice(text: "Elementare", value: "Elementare" as NSString),
            ORKTextChoice(text: "Media", value: "Media" as NSString),
            ORKTextChoice(text: "Superiore", value: "Superiore" as NSString),
            ORKTextChoice(text: "Laurea", value: "Laurea" as NSString),
            ORKTextChoice(text: "Piu di Laurea (Master e altro)", value: "Piu di Laurea (Master e altro)" as NSString)
            ]))
        
        // Q1
        
        let q1Step = ORKQuestionStep(identifier: "q1Step", title: "In Italia esistono molti partiti ognuno dei quali vorrebbe avere il suo voto. Se ci fossero delle elezioni domani, quale partito avrebbe la piu’ alta probabilita’ di avere il suo voto?", text: nil, answer: ORKAnswerFormat.choiceAnswerFormat(with: .singleChoice, textChoices: [
            ORKTextChoice(text: "+Europa", value: "+Europa" as NSString),
            ORKTextChoice(text: "10 Volte Meglio", value: "10 Volte Meglio" as NSString),
            ORKTextChoice(text: "Autodeterminazione", value: "Autodeterminazione" as NSString),
            ORKTextChoice(text: "Blocco Nazionale Per Le Liberta’", value: "Blocco Nazionale Per Le Liberta’" as NSString),
            ORKTextChoice(text: "Casapound Italia", value: "Casapound Italia" as NSString),
            ORKTextChoice(text: "Civica Popolare Lorenzin", value: "Civica Popolare Lorenzin" as NSString),
            ORKTextChoice(text: "Forza Italia", value: "Forza Italia" as NSString),
            ORKTextChoice(text: "Fratelli D’italia Con Giorgia Meloni", value: "Fratelli D’italia Con Giorgia Meloni" as NSString),
            ORKTextChoice(text: "Grande Nord", value: "Grande Nord" as NSString),
            ORKTextChoice(text: "Il Popolo Della Famiglia", value: "Il Popolo Della Famiglia" as NSString),
            ORKTextChoice(text: "Italia Agli Italiani", value: "Italia Agli Italiani" as NSString),
            ORKTextChoice(text: "Italia Europa Insieme", value: "Italia Europa Insieme" as NSString),
            ORKTextChoice(text: "Italia Nel Cuore", value: "Italia Nel Cuore" as NSString),
            ORKTextChoice(text: "Lega", value: "Lega" as NSString),
            ORKTextChoice(text: "Lista Del Popolo Per La Costituzione", value: "Lista Del Popolo Per La Costituzione" as NSString),
            ORKTextChoice(text: "Movimento 5 Stelle", value: "Movimento 5 Stelle" as NSString),
            ORKTextChoice(text: "Noi Con L’italia - Udc", value: "Noi Con L’italia - Udc" as NSString),
            ORKTextChoice(text: "Partito Comunista", value: "Partito Comunista" as NSString),
            ORKTextChoice(text: "Partito Democratico", value: "Partito Democratico" as NSString),
            ORKTextChoice(text: "Partito Repubblicano Italiano - Ala", value: "Partito Repubblicano Italiano - Ala" as NSString),
            ORKTextChoice(text: "Partito Valore Umano", value: "Partito Valore Umano" as NSString),
            ORKTextChoice(text: "Patto Per L’autonomia", value: "Patto Per L’autonomia" as NSString),
            ORKTextChoice(text: "Per Una Sinistra Rivoluzionaria", value: "Per Una Sinistra Rivoluzionaria" as NSString),
            ORKTextChoice(text: "Potere Al Popolo!", value: "Potere Al Popolo!" as NSString),
            ORKTextChoice(text: "Rinascimento Mir", value: "Rinascimento Mir" as NSString),
            ORKTextChoice(text: "Siamo", value: "Siamo" as NSString),
            ORKTextChoice(text: "Svp - Patt", value: "Svp - Patt" as NSString),
            ORKTextChoice(text: "Liberi E Uguali", value: "Liberi E Uguali" as NSString)
            ]))
        
        // Q2
        
        let q2Step = ORKQuestionStep(identifier: "q2Step", title: "In genere lei guarda il telegiornale? Se si, con che frequenza?", text: nil, answer: ORKAnswerFormat.choiceAnswerFormat(with: .singleChoice, textChoices: [
            ORKTextChoice(text: "No, mai", value: 0 as NSNumber),
            ORKTextChoice(text: "1 giorno alla settimana", value: 1 as NSNumber),
            ORKTextChoice(text: "2 giorni alla settimana", value: 2 as NSNumber),
            ORKTextChoice(text: "3 giorni alla settimana", value: 3 as NSNumber),
            ORKTextChoice(text: "4 giorni alla settimana", value: 4 as NSNumber),
            ORKTextChoice(text: "5 giorni alla settimana", value: 5 as NSNumber),
            ORKTextChoice(text: "6 giorni alla settimana", value: 6 as NSNumber),
            ORKTextChoice(text: "Tutti i giorni", value: 7 as NSNumber)
            ]))
        
        // Q3
        
        let q3Step = ORKQuestionStep(identifier: "q3Step", title: "Qual il telegiornale che lei abitualmente vede di pi`u?", text: nil, answer: ORKAnswerFormat.choiceAnswerFormat(with: .multipleChoice, textChoices: [
            ORKTextChoice(text: "Tg1 (RAI1)", value: "Tg1 (RAI1)" as NSString),
            ORKTextChoice(text: "Tg2 (RAI2)", value: "Tg2 (RAI2)" as NSString),
            ORKTextChoice(text: "Tg3 (RAI3)", value: "Tg3 (RAI3)" as NSString),
            ORKTextChoice(text: "Tg4 (Rete4)", value: "Tg4 (Rete4)" as NSString),
            ORKTextChoice(text: "Tg5 (Canale5)", value: "Tg5 (Canale5)" as NSString),
            ORKTextChoice(text: "Studio Aperto (Italia1)", value: "Studio Aperto (Italia1)" as NSString),
            ORKTextChoice(text: "LA 7 News (La7)", value: "LA 7 News (La7)" as NSString),
            ORKTextChoice(text: "SKY TG 24 - Satellite", value: "SKY TG 24 - Satellite" as NSString),
            ORKTextChoice(text: "Telegiornale locale", value: "Telegiornale locale" as NSString),
            ORKTextChoice(text: "Altro telegiornale", value: "Altro telegiornale" as NSString)
            ]))
        
        // Q4
        
        let q4Step = ORKQuestionStep(identifier: "q4Step", title: "Lei cerca informazioni e notizie politiche navigando in internet?", text: nil, answer: ORKAnswerFormat.choiceAnswerFormat(with: .singleChoice, textChoices: [
            ORKTextChoice(text: "Si, frequentemente (almeno una volta al giorno)", value: "Si, frequentemente (almeno una volta al giorno)" as NSString),
            ORKTextChoice(text: "Si, raramente (qualche volta a settimana)", value: "Si, raramente (qualche volta a settimana)" as NSString),
            ORKTextChoice(text: "No, mai", value: "No, mai" as NSString)
            ]))
        
        // Q5
        
        let q5Step = ORKQuestionStep(identifier: "q5Step", title: "In generale lei legge un giornale quotidiano (esclusi i giornali sportivi)? Se si, con quale frequenza?", text: nil, answer: ORKAnswerFormat.choiceAnswerFormat(with: .singleChoice, textChoices: [
            ORKTextChoice(text: "No, mai", value: 0 as NSNumber),
            ORKTextChoice(text: "1 giorno alla settimana", value: 1 as NSNumber),
            ORKTextChoice(text: "2 giorno alla settimana", value: 2 as NSNumber),
            ORKTextChoice(text: "3 giorno alla settimana", value: 3 as NSNumber),
            ORKTextChoice(text: "4 giorno alla settimana", value: 4 as NSNumber),
            ORKTextChoice(text: "5 giorno alla settimana", value: 5 as NSNumber),
            ORKTextChoice(text: "6 giorno alla settimana", value: 6 as NSNumber),
            ORKTextChoice(text: "Tutti i giorni", value: 7 as NSNumber)
            ]))
        
        // Q6
        
        let q6Step = ORKQuestionStep(identifier: "q6Step", title: "Quale giornale legge? (Max due risposte)", text: "Prima Scelta", answer: ORKAnswerFormat.choiceAnswerFormat(with: .singleChoice, textChoices: [
            ORKTextChoice(text: "Avanti!", value: "Avanti!" as NSString),
            ORKTextChoice(text: "Avvenire", value: "Avvenire" as NSString),
            ORKTextChoice(text: "Corriere della Sera", value: "Corriere della Sera" as NSString),
            ORKTextChoice(text: "Europa", value: "Europa" as NSString),
            ORKTextChoice(text: "Il Foglio", value: "Il Foglio" as NSString),
            ORKTextChoice(text: "Il Gazzettino", value: "Il Gazzettino" as NSString),
            ORKTextChoice(text: "Il Giornale", value: "Il Giornale" as NSString),
            ORKTextChoice(text: "Il Giornale di Sicilia", value: "Il Giornale di Sicilia" as NSString),
            ORKTextChoice(text: "Il Giorno", value: "Il Giorno" as NSString),
            ORKTextChoice(text: "Il Lavoro", value: "Il Lavoro" as NSString),
            ORKTextChoice(text: "Il Manifesto", value: "Il Manifesto" as NSString),
            ORKTextChoice(text: "Il Mattino", value: "Il Mattino" as NSString),
            ORKTextChoice(text: "Il Messaggero", value: "Il Messaggero" as NSString),
            ORKTextChoice(text: "Il Piccolo", value: "Il Piccolo" as NSString),
            ORKTextChoice(text: "Il Popolo", value: "Il Popolo" as NSString),
            ORKTextChoice(text: "Il Resto del Carlino", value: "Il Resto del Carlino" as NSString),
            ORKTextChoice(text: "Il Riformista", value: "Il Riformista" as NSString),
            ORKTextChoice(text: "Il Secolo XIX", value: "Il Secolo XIX" as NSString),
            ORKTextChoice(text: "Il Secolo d’Italia", value: "Il Secolo d’Italia" as NSString),
            ORKTextChoice(text: "Il Sole-24 Ore", value: "Il Sole-24 Ore" as NSString),
            ORKTextChoice(text: "Il Tempo", value: "Il Tempo" as NSString),
            ORKTextChoice(text: "Italia Oggi", value: "Italia Oggi" as NSString),
            ORKTextChoice(text: "La Gazzetta del Mezzogiorno", value: "La Gazzetta del Mezzogiorno" as NSString),
            ORKTextChoice(text: "La Nazione", value: "La Nazione" as NSString),
            ORKTextChoice(text: "La Padania", value: "La Padania" as NSString),
            ORKTextChoice(text: "La Repubblica", value: "La Repubblica" as NSString),
            ORKTextChoice(text: "La Stampa", value: "La Stampa" as NSString),
            ORKTextChoice(text: "Liberazione", value: "Liberazione" as NSString),
            ORKTextChoice(text: "Libero", value: "Libero" as NSString),
            ORKTextChoice(text: "L’Unione Sarda", value: "L’Unione Sarda" as NSString),
            ORKTextChoice(text: "L’Unita’", value: "L’Unita’" as NSString),
            ORKTextChoice(text: "Free Press (Metro, City, Leggo)", value: "Free Press (Metro, City, Leggo)" as NSString)
            ]))
        
        // Q7
        
        let q7Step = ORKQuestionStep(identifier: "q7Step", title: "Quale giornale legge? (Max due risposte)", text: "Seconda Scelta", answer: ORKAnswerFormat.choiceAnswerFormat(with: .singleChoice, textChoices: [
            ORKTextChoice(text: "Avanti!", value: "Avanti!" as NSString),
            ORKTextChoice(text: "Avvenire", value: "Avvenire" as NSString),
            ORKTextChoice(text: "Corriere della Sera", value: "Corriere della Sera" as NSString),
            ORKTextChoice(text: "Europa", value: "Europa" as NSString),
            ORKTextChoice(text: "Il Foglio", value: "Il Foglio" as NSString),
            ORKTextChoice(text: "Il Gazzettino", value: "Il Gazzettino" as NSString),
            ORKTextChoice(text: "Il Giornale", value: "Il Giornale" as NSString),
            ORKTextChoice(text: "Il Giornale di Sicilia", value: "Il Giornale di Sicilia" as NSString),
            ORKTextChoice(text: "Il Giorno", value: "Il Giorno" as NSString),
            ORKTextChoice(text: "Il Lavoro", value: "Il Lavoro" as NSString),
            ORKTextChoice(text: "Il Manifesto", value: "Il Manifesto" as NSString),
            ORKTextChoice(text: "Il Mattino", value: "Il Mattino" as NSString),
            ORKTextChoice(text: "Il Messaggero", value: "Il Messaggero" as NSString),
            ORKTextChoice(text: "Il Piccolo", value: "Il Piccolo" as NSString),
            ORKTextChoice(text: "Il Popolo", value: "Il Popolo" as NSString),
            ORKTextChoice(text: "Il Resto del Carlino", value: "Il Resto del Carlino" as NSString),
            ORKTextChoice(text: "Il Riformista", value: "Il Riformista" as NSString),
            ORKTextChoice(text: "Il Secolo XIX", value: "Il Secolo XIX" as NSString),
            ORKTextChoice(text: "Il Secolo d’Italia", value: "Il Secolo d’Italia" as NSString),
            ORKTextChoice(text: "Il Sole-24 Ore", value: "Il Sole-24 Ore" as NSString),
            ORKTextChoice(text: "Il Tempo", value: "Il Tempo" as NSString),
            ORKTextChoice(text: "Italia Oggi", value: "Italia Oggi" as NSString),
            ORKTextChoice(text: "La Gazzetta del Mezzogiorno", value: "La Gazzetta del Mezzogiorno" as NSString),
            ORKTextChoice(text: "La Nazione", value: "La Nazione" as NSString),
            ORKTextChoice(text: "La Padania", value: "La Padania" as NSString),
            ORKTextChoice(text: "La Repubblica", value: "La Repubblica" as NSString),
            ORKTextChoice(text: "La Stampa", value: "La Stampa" as NSString),
            ORKTextChoice(text: "Liberazione", value: "Liberazione" as NSString),
            ORKTextChoice(text: "Libero", value: "Libero" as NSString),
            ORKTextChoice(text: "L’Unione Sarda", value: "L’Unione Sarda" as NSString),
            ORKTextChoice(text: "L’Unita’", value: "L’Unita’" as NSString),
            ORKTextChoice(text: "Free Press (Metro, City, Leggo)", value: "Free Press (Metro, City, Leggo)" as NSString)
            ]))
        
        // Q8
        
        let q8Step = ORKQuestionStep(identifier: "q8Step", title: "Secondo lei quali sono le tre questioni piu’ importanti per gli italiani in questo momento?", text: nil, answer: ORKAnswerFormat.choiceAnswerFormat(with: .multipleChoice, textChoices: [
            ORKTextChoice(text: "Immigrazione", value: "Immigrazione" as NSString),
            ORKTextChoice(text: "L’Unione Europea", value: "L’Unione Europea" as NSString),
            ORKTextChoice(text: "Tasse", value: "Tasse" as NSString),
            ORKTextChoice(text: "Disoccupazione", value: "Disoccupazione" as NSString),
            ORKTextChoice(text: "Inquinamento", value: "Inquinamento" as NSString),
            ORKTextChoice(text: "Corruzione politica", value: "Corruzione politica" as NSString),
            ORKTextChoice(text: "Arretratezza del mezzogiorno", value: "Arretratezza del mezzogiorno" as NSString),
            ORKTextChoice(text: "Le Pensioni", value: "Le Pensioni" as NSString),
            ORKTextChoice(text: "La riforma della sanita’", value: "La riforma della sanita’" as NSString),
            ORKTextChoice(text: "La riforma della giustizia", value: "La riforma della giustizia" as NSString),
            ORKTextChoice(text: "Il reddito di cittadinanza", value: "Il reddito di cittadinanza" as NSString),
            ORKTextChoice(text: "Inflazione", value: "Inflazione" as NSString),
            ORKTextChoice(text: "Evasione fiscale", value: "Evasione fiscale" as NSString),
            ORKTextChoice(text: "Scuola", value: "Scuola" as NSString)
            ]))
        
        // Q9
        
        let q9Step = ORKQuestionStep(identifier: "q9Step", title: "Quanto e’ interessato alla politica italiana e locale?", text: nil, answer: ORKAnswerFormat.choiceAnswerFormat(with: .singleChoice, textChoices: [
            ORKTextChoice(text: "Molto", value: "Molto" as NSString),
            ORKTextChoice(text: "Abbastanza", value: "Abbastanza" as NSString),
            ORKTextChoice(text: "Poco", value: "Poco" as NSString),
            ORKTextChoice(text: "Per niente", value: "Per niente" as NSString)
            ]))
        
        // Q10
        
        let q10Step = ORKQuestionStep(identifier: "q10Step", title: "Quanto pensa influisca la politica sulla propria vita e quella della propria famiglia?", text: nil, answer: ORKAnswerFormat.choiceAnswerFormat(with: .singleChoice, textChoices: [
            ORKTextChoice(text: "Molto", value: "Molto" as NSString),
            ORKTextChoice(text: "Abbastanza", value: "Abbastanza" as NSString),
            ORKTextChoice(text: "Poco", value: "Poco" as NSString),
            ORKTextChoice(text: "Per niente", value: "Per niente" as NSString)
            ]))
        
        // Q11
        
//        let q11Step1 = ORKQuestionStep(identifier: "q11Step1", title: "Conoscenza della politica", text: "Bandiera dell’islam", answer: ORKAnswerFormat.scale(withMaximumValue: 10, minimumValue: 0, defaultValue: 0, step: 1, vertical: false, maximumValueDescription: nil, minimumValueDescription: nil))
//        let q11Step2 = ORKQuestionStep(identifier: "q11Step2", title: "Conoscenza della politica", text: "Mario Draghi", answer: ORKAnswerFormat.scale(withMaximumValue: 10, minimumValue: 0, defaultValue: 0, step: 1, vertical: false, maximumValueDescription: nil, minimumValueDescription: nil))
//        let q11Step3 = ORKQuestionStep(identifier: "q11Step3", title: "Conoscenza della politica", text: "Il PIL procapite italiano e’ 27 700 Euro", answer: ORKAnswerFormat.scale(withMaximumValue: 10, minimumValue: 0, defaultValue: 0, step: 1, vertical: false, maximumValueDescription: nil, minimumValueDescription: nil))
//        let q11Step4 = ORKQuestionStep(identifier: "q11Step4", title: "Conoscenza della politica", text: "Mattarella dalla foto", answer: ORKAnswerFormat.scale(withMaximumValue: 10, minimumValue: 0, defaultValue: 0, step: 1, vertical: false, maximumValueDescription: nil, minimumValueDescription: nil))
//        let q11Step5 = ORKQuestionStep(identifier: "q11Step5", title: "Conoscenza della politica", text: "Macron dalla foto", answer: ORKAnswerFormat.scale(withMaximumValue: 10, minimumValue: 0, defaultValue: 0, step: 1, vertical: false, maximumValueDescription: nil, minimumValueDescription: nil))
//        let q11Step6 = ORKQuestionStep(identifier: "q11Step6", title: "Conoscenza della politica", text: "Simbolo Movimento 5 stelle", answer: ORKAnswerFormat.scale(withMaximumValue: 10, minimumValue: 0, defaultValue: 0, step: 1, vertical: false, maximumValueDescription: nil, minimumValueDescription: nil))
        
        // Q12
        
        let q11Step1 = ORKQuestionStep(identifier: "q11Step1", title: "A quale di queste figure corrisponde il simbolo di...", text: "Bandiera dell’Islam", answer: ORKAnswerFormat.choiceAnswerFormat(with: [
                ORKImageChoice(normalImage: UIImage(named: "islam0"), selectedImage: UIImage(named: "islam0_selected"), text: nil, value: 1 as NSNumber),
                ORKImageChoice(normalImage: UIImage(named: "islam1"), selectedImage: UIImage(named: "islam1_selected"), text: nil, value: 0 as NSNumber),
                ORKImageChoice(normalImage: UIImage(named: "islam2"), selectedImage: UIImage(named: "islam2_selected"), text: nil, value: 0 as NSNumber),
                ORKImageChoice(normalImage: UIImage(named: "islam3"), selectedImage: UIImage(named: "islam3_selected"), text: nil, value: 0 as NSNumber),
                ORKImageChoice(normalImage: UIImage(named: "islam4"), selectedImage: UIImage(named: "islam4_selected"), text: nil, value: 0 as NSNumber)
            ]))
        let q11Step2 = ORKQuestionStep(identifier: "q11Step2", title: "A quale di queste figure corrisponde l'immagine di...", text: "Mario Draghi (Presidente ECB)", answer: ORKAnswerFormat.choiceAnswerFormat(with: [
                ORKImageChoice(normalImage: UIImage(named: "draghi0"), selectedImage: UIImage(named: "draghi0_selected"), text: nil, value: 1 as NSNumber),
                ORKImageChoice(normalImage: UIImage(named: "draghi1"), selectedImage: UIImage(named: "draghi1_selected"), text: nil, value: 0 as NSNumber),
                ORKImageChoice(normalImage: UIImage(named: "draghi2"), selectedImage: UIImage(named: "draghi2_selected"), text: nil, value: 0 as NSNumber),
                ORKImageChoice(normalImage: UIImage(named: "draghi3"), selectedImage: UIImage(named: "draghi3_selected"), text: nil, value: 0 as NSNumber)
            ]))
        let q11Step3 = ORKQuestionStep(identifier: "q11Step3", title: "A quale di queste figure corrisponde l'immagine di...", text: "Emmanuel Macron (Presidente Francese)", answer: ORKAnswerFormat.choiceAnswerFormat(with: [
                ORKImageChoice(normalImage: UIImage(named: "macron0"), selectedImage: UIImage(named: "macron0_selected"), text: nil, value: 1 as NSNumber),
                ORKImageChoice(normalImage: UIImage(named: "macron1"), selectedImage: UIImage(named: "macron1_selected"), text: nil, value: 0 as NSNumber),
                ORKImageChoice(normalImage: UIImage(named: "macron2"), selectedImage: UIImage(named: "macron2_selected"), text: nil, value: 0 as NSNumber),
                ORKImageChoice(normalImage: UIImage(named: "macron3"), selectedImage: UIImage(named: "macron3_selected"), text: nil, value: 0 as NSNumber)
            ]))
        let q11Step4 = ORKQuestionStep(identifier: "q11Step4", title: "A quale di queste figure corrisponde il simbolo del ...", text: "Movimento 5 stelle", answer: ORKAnswerFormat.choiceAnswerFormat(with: [
                ORKImageChoice(normalImage: UIImage(named: "star0"), selectedImage: UIImage(named: "star0_selected"), text: nil, value: 1 as NSNumber),
                ORKImageChoice(normalImage: UIImage(named: "star1"), selectedImage: UIImage(named: "star1_selected"), text: nil, value: 0 as NSNumber),
                ORKImageChoice(normalImage: UIImage(named: "star2"), selectedImage: UIImage(named: "star2_selected"), text: nil, value: 0 as NSNumber),
                ORKImageChoice(normalImage: UIImage(named: "star3"), selectedImage: UIImage(named: "star3_selected"), text: nil, value: 0 as NSNumber)
            ]))
        let q11Step5 = ORKQuestionStep(identifier: "q11Step5", title: "Qual'e' il reddito medio procapite in Italia?", text: nil, answer: ORKAnswerFormat.choiceAnswerFormat(with: .singleChoice, textChoices: [
                ORKTextChoice(text: "10-15 mila", value: 0 as NSNumber),
                ORKTextChoice(text: "15-20 mila", value: 0 as NSNumber),
                ORKTextChoice(text: "20-25 mila", value: 0 as NSNumber),
                ORKTextChoice(text: "25-30 mila", value: 1 as NSNumber),
                ORKTextChoice(text: "35 mila", value: 0 as NSNumber)
            ]))
        
        // conclusion
        
        let conclusionStep = ORKInstructionStep(identifier: "conclusionStep")
        conclusionStep.title = "Grazie infinite!"
        conclusionStep.detailText = "Apprezziamo moltissimo la tua participazione."
        
        // present the VC
        
        let task = ORKOrderedTask(identifier: "introTask", steps: [introStep, q0Step1, q0Step2, q0Step3, q1Step, q2Step, q3Step, q4Step, q5Step, q6Step, q7Step, q8Step, q9Step, q10Step, q11Step1, q11Step2, q11Step3, q11Step4, q11Step5,conclusionStep])
        let taskVC = ORKTaskViewController(task: task, taskRun: nil)
        taskVC.delegate = self
        present(taskVC, animated: true, completion: nil)
    }
    
    func parseAnswers(_ results: [ORKStepResult]) -> [String : Any] {
        var answers: [String : Any] = [:]
        
        for result in results {
            if result.identifier == "introStep" || result.identifier == "conclusionStep" { continue }
            
            if let stepResults = result.results as? [ORKChoiceQuestionResult] {
                if let answer = stepResults.first?.choiceAnswers as? [NSString] {
                    if answer.count > 1 {
                        answers[result.identifier] = answer
                    } else if answer.count == 1 {
                        answers[result.identifier] = answer.first!
                    }
                } else if let answer = stepResults.first?.choiceAnswers as? [NSNumber] {
                    if answer.count > 1 {
                        answers[result.identifier] = answer
                    } else if answer.count == 1 {
                        answers[result.identifier] = answer.first!
                    }
                } else {
                    answers[result.identifier] = NSNull()
                }
            } else if let stepResults = result.results as? [ORKScaleQuestionResult] {
                if let answer = stepResults.first?.scaleAnswer {
                    answers[result.identifier] = answer
                } else {
                    answers[result.identifier] = NSNull()
                }
            } else {
                answers[result.identifier] = NSNull()
            }
        }
        
        return answers
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
        self.title = "Dossier"
        
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
            self.getFeed()
        }, loadingView: self.loadingView)
        
        self.loadingView.tintColor = UIColor.white
        tableView.dg_setPullToRefreshFillColor(APP_COLOR)
    }
    
    // MARK: ORKTaskViewController Delegate
    
    func taskViewController(_ taskViewController: ORKTaskViewController, didFinishWith reason: ORKTaskViewControllerFinishReason, error: Error?) {
        guard error == nil, reason.rawValue == 2, let results = taskViewController.result.results as? [ORKStepResult] else {
            db.collection("users").document(userID).updateData([
                    "polled" : true,
                    "polledAgain" : self.resurvey,
                    (self.resurvey ? "secondSurvey" : "initialSurvey") : nil
                ])
            dismiss(animated: true, completion: nil)
            return
        }
        
        let answers = parseAnswers(results)
        print(answers)
        
        // store answers, mark as polled
        
        db.collection("users").document(userID).updateData([
                "polled" : true,
                "polledAgain" : self.resurvey,
                (self.resurvey ? "secondSurvey" : "initialSurvey") : answers
            ])
        
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: SFSafariViewController Delegate
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    // MARK: UIScrollView Delegate
    
    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        print("end decelerating")
        markVisibleArticles()
    }
    
    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        print("end dragging", decelerate)
        guard !decelerate else { return }
        markVisibleArticles()
    }
}
