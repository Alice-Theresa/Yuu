//
//  Track.swift
//  Yuu
//
//  Created by Skylar on 2019/9/25.
//  Copyright © 2019 Skylar. All rights reserved.
//

import Foundation

enum TrackType: Int {
    case Video = 0
    case Audio = 1
    case Subtitle = 2
}

class Track {
    let type: TrackType
    let index: Int
    let metadata: [String: String]
    
    init(type: TrackType, index: Int, metadata: [String: String]) {
        self.type = type
        self.index = index
        self.metadata = metadata
    }
}
