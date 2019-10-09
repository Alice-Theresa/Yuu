//
//  Track.swift
//  Yuu
//
//  Created by Skylar on 2019/9/25.
//  Copyright © 2019 Skylar. All rights reserved.
//

import Foundation

enum TrackType: Int {
    case unknown = -1
    case video
    case audio
    case data
    case subtitle
    case attachment
    case nb
    
    init(type: AVMediaType) {
        switch type {
        case AVMEDIA_TYPE_UNKNOWN:
            self = .unknown
        case AVMEDIA_TYPE_VIDEO:
            self = .video
        case AVMEDIA_TYPE_AUDIO:
            self = .audio
        case AVMEDIA_TYPE_DATA:
            self = .data
        case AVMEDIA_TYPE_SUBTITLE:
            self = .subtitle
        case AVMEDIA_TYPE_ATTACHMENT:
            self = .attachment
        case AVMEDIA_TYPE_NB:
            self = .nb
        default:
            self = .unknown
        }
    }
    
    var rawValue: Int {
        switch self {
        case .unknown:
            return Int(AVMEDIA_TYPE_UNKNOWN.rawValue)
        case .video:
            return Int(AVMEDIA_TYPE_VIDEO.rawValue)
        case .audio:
            return Int(AVMEDIA_TYPE_AUDIO.rawValue)
        case .data:
            return Int(AVMEDIA_TYPE_DATA.rawValue)
        case .subtitle:
            return Int(AVMEDIA_TYPE_SUBTITLE.rawValue)
        case .attachment:
            return Int(AVMEDIA_TYPE_ATTACHMENT.rawValue)
        case .nb:
            return Int(AVMEDIA_TYPE_NB.rawValue)
        }
    }
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
