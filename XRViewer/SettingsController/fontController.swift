//
//  fontController.swift
//  iQ3ConnectXRViewer
//
//  Created by IQ3 on 3/5/25.
//  Copyright © 2025 Mozilla. All rights reserved.
//

extension UITraitEnvironment {
    func printCurrentContentSizeCategory() {
        switch traitCollection.preferredContentSizeCategory {
        case .extraSmall:
            print("extra small")
        case .small:
            print("small")
        case .medium:
            print("medium")
        case .large:
            print("large")
        case .extraLarge:
            print("extra large")
        case .extraExtraLarge:
            print("extra extra large")
        case .extraExtraExtraLarge:
            print("extra extra extra large")
        case .accessibilityMedium:
            print("accessibility medium")
        case .accessibilityLarge:
            print("accessibility large")
        case .accessibilityExtraLarge:
            print("accessibility extra large")
        case .accessibilityExtraExtraLarge:
            print("accessibility extra extra large")
        case .accessibilityExtraExtraExtraLarge:
            print("accessibility extra extra extra large")
        default:
            print("Unspecified")
        }
    }
    
//    func calculateHeightForText(_ text: String) -> CGFloat {
//        let font = UIFont.systemFont(ofSize: 13)
//        let label = UILabel(frame: CGRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude))
//        label.text = text
//        label.font = font
//        label.numberOfLines = 0
//        label.lineBreakMode = .byWordWrapping
//        label.sizeToFit()
//        
//        return label.frame.height + 16 // Add padding
//    }
}
