//
//  QueueManager.swift
//  Yuu
//
//  Created by Skylar on 2019/10/2.
//  Copyright © 2019 Skylar. All rights reserved.
//

import Foundation

enum QueueType {
    case packet
    case frame
}

class QueueManager {

    let videoFrameQueue  = ObjectQueue(queueType: .frame, trackType: .video)
    let audioFrameQueue  = ObjectQueue(queueType: .frame, trackType: .audio)

    private let videoTracksIndexes: [Int]
    private let audioTracksIndexes: [Int]
    
    var packetsQueue: [Int: ObjectQueue]
    
    init(context: FormatContext) {
        videoTracksIndexes = context.videoTracks.map { $0.index }
        audioTracksIndexes = context.audioTracks.map { $0.index }
        packetsQueue = [:]
        for track in context.videoTracks {
            packetsQueue[track.index] = ObjectQueue(queueType: .packet, trackType: .video)
        }
        for track in context.audioTracks {
            packetsQueue[track.index] = ObjectQueue(queueType: .packet, trackType: .audio)
        }
    }

    func queueIsFull() -> Bool {
        var total = 0
        for queue in packetsQueue {
            total += queue.value.count
        }
        return total > 20
    }

    func fetchFrameQueue(by index: Int) -> ObjectQueue {
        if videoTracksIndexes.contains(index) {
            return videoFrameQueue
        } else if audioTracksIndexes.contains(index) {
            return audioFrameQueue
        } else {
            fatalError()
        }
    }
    
    func enqueueDiscardPacket() {
        for (_, queue) in packetsQueue{
            let packet1   = Packet()
            packet1.flags = .discard
            queue.enqueue([packet1])
        }
    }
    
    func allFlush() {
        videoFrameQueue.flush()
        audioFrameQueue.flush()
        for (_, queue) in packetsQueue {
           queue.flush()
       }
    }
}

class ObjectQueue {
    
    let queueType: QueueType
    let trackType: TrackType
    
    private let semaphore = DispatchSemaphore(value: 1)
    private(set) var count = 0
    private var queue: [FlowData] = []
    
    init(queueType: QueueType, trackType: TrackType) {
        self.queueType = queueType
        self.trackType = trackType
    }
    
    func enqueue(_ data: Array<FlowData>) {
        semaphore.wait()
        defer {
            semaphore.signal()
        }
        count += data.count
        queue.append(contentsOf: data)
        queue.sort { $0.position < $1.position }
    }
    
    func dequeue() -> FlowData? {
        semaphore.wait()
        defer {
            semaphore.signal()
        }
        if let node = queue.first {
            count -= 1
            queue.removeFirst()
            return node
        } else {
            return nil
        }
    }
    
    func flush() {
        semaphore.wait()
        defer {
            semaphore.signal()
        }
        queue = []
        count = 0
    }
    
}
