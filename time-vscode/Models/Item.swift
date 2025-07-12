//
//  Item.swift
//  time-vscode
//
//  Created by seven on 2025/7/1.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
