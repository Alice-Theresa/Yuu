//
//  CodecDescriptor.swift
//  Yuu
//
//  Created by Skylar on 2019/10/6.
//  Copyright © 2019 Skylar. All rights reserved.
//

import Foundation

class CodecDescriptor {
    
    let timebase: AVRational
    let trackType: TrackType
    
    init(timebase: AVRational,trackType: TrackType) {
        self.timebase = timebase
        self.trackType = trackType
    }
}
