//
//  ArticleTableViewCell.swift
//  News App
//
//  Created by Vikas Nair on 5/14/18.
//  Copyright © 2018 Vikas Nair. All rights reserved.
//

import UIKit

class ArticleTableViewCell: UITableViewCell {

    // MARK: Outlets
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var sourceLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    // MARK: UITableViewCell Delegate
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

}
