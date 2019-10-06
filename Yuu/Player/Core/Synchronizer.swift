//
//  Synchronizer.swift
//  Yuu
//
//  Created by Skylar on 2019/9/25.
//  Copyright © 2019 Skylar. All rights reserved.
//

import Foundation

class Synchronizer {
    
    private var audioFramePlayTime: CMTime = .zero
    private var audioFramePosition: CMTime = .zero
    private let semaphore = DispatchSemaphore(value: 1)
    
    func updateAudioClock(position: CMTime) {
        semaphore.wait()
        defer {
            semaphore.signal()
        }
        audioFramePlayTime = currentCMTime()
        audioFramePosition = position
    }
    
    func shouldRenderVideoFrame(position: CMTime, duration: CMTime) -> Bool {
        semaphore.wait()
        defer {
            semaphore.signal()
        }
        let diffTime = CMTimeSubtract(currentCMTime(), audioFramePlayTime)
        return CMTimeAdd(audioFramePosition, diffTime) >= CMTimeAdd(position, duration) ? true : false
    }
    
    private func currentCMTime() -> CMTime {
        return CMTime(seconds: Date().timeIntervalSince1970, preferredTimescale: AV_TIME_BASE)
    }

}

