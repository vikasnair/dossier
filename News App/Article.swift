//
//  Article.swift
//  News App
//
//  Created by Vikas Nair on 5/14/18.
//  Copyright © 2018 Vikas Nair. All rights reserved.
//

import Foundation

public class Article: Codable {
    
    // MARK: Properties
    
    let source: String
    let title: String
    let url: URL
    let category: String
    let date: String
    
    enum CodingKeys: String, CodingKey {
        case source
        case title
        case url
        case category
        case date
    }
    
    // MARK: Init
    
    init(source: String, title: String, url: URL, category: String, date: String) {
        self.source = source
        self.title = title
        self.url = url
        self.category = category
        self.date = date
    }
    
    // MARK: Codable Delegate
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(source, forKey: .source)
        try container.encode(title, forKey: .title)
        try container.encode(url, forKey: .url)
        try container.encode(category, forKey: .category)
        try container.encode(date, forKey: .date)
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.source = try container.decode(String.self, forKey: .source)
        self.title = try container.decode(String.self, forKey: .title)
        self.url = try container.decode(URL.self, forKey: .url)
        self.category = try container.decode(String.self, forKey: .category)
        self.date = try container.decode(String.self, forKey: .date)
    }
}
