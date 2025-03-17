//
//  TextInputTableViewCell.swift
//  XRViewer
//
//  Created by Roberto Garrido on 29/1/18.
//  Copyright © 2018 Mozilla. All rights reserved.
//

import UIKit

class TextInputTableViewCell: UITableViewCell {

    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var labelTitle: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    
    func adjustLabelPadding() {
         // Add left padding to match standard cell text
         let padding: CGFloat = 16 // Standard cell padding
         labelTitle.frame.origin.x = padding
     }
    
}
