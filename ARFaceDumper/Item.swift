//
//  Item.swift
//  ARFaceDumper
//
//  Created by Davide Monnati on 01/03/26.
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
