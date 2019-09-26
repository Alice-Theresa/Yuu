//
//  Synchronizer.swift
//  Yuu
//
//  Created by Skylar on 2019/9/25.
//  Copyright © 2019 Skylar. All rights reserved.
//

import Foundation

class Synchronizer {
    
    private var audioFramePlayTime: TimeInterval = 0
    private var audioFramePosition: TimeInterval = 0
    private let semaphore = DispatchSemaphore(value: 1)
    
    func updateAudioClock(position: TimeInterval) {
        semaphore.wait()
        defer {
            semaphore.signal()
        }
        audioFramePlayTime = Date().timeIntervalSince1970
        audioFramePosition = position
    }
    
    func shouldRenderVideoFrame(position: TimeInterval, duration: TimeInterval) -> Bool {
        semaphore.wait()
        defer {
            semaphore.signal()
        }
        let time = Date().timeIntervalSince1970
        return audioFramePosition + time - audioFramePlayTime >= position + duration ? true : false
    }
}

