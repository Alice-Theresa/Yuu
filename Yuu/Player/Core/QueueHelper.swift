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

protocol DemuxToQueueProtocol: class {
    func packetQueueIsFull() -> Bool
    func enqueueDiscardPacket()
    func enqueue(_ packet: Packet)
    func flush()
}

protocol DecodeToQueueProtocol: class {
    func frameQueueIsFull(streamIndex: Int) -> Bool
    func enqueue(_ frame: [FlowData])
    func flush()
}

class QueueManager {

    let videoFrameQueue  = ObjectQueue(queueType: .frame, trackType: .video, needSort: true)
    let audioFrameQueue  = ObjectQueue(queueType: .frame, trackType: .audio, needSort: true)

    private let videoTracksIndexes: [Int]
    private let audioTracksIndexes: [Int]
    
    init(context: FormatContext) {
        videoTracksIndexes = context.tracks.filter{ $0.type == .video }.map { $0.index }
        audioTracksIndexes = context.tracks.filter{ $0.type == .audio }.map { $0.index }
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
    
    func allFlush() {
        videoFrameQueue.flush()
        audioFrameQueue.flush()
    }
}

class ObjectQueue {
    
    let queueType: QueueType
    let trackType: TrackType
    let needSort: Bool
    
    private let semaphore = DispatchSemaphore(value: 1)
    private(set) var count = 0
    private var queue: [FlowData] = []
    
    init(queueType: QueueType, trackType: TrackType, needSort: Bool) {
        self.queueType = queueType
        self.trackType = trackType
        self.needSort = needSort
    }
    
    func enqueue(_ data: Array<FlowData>) {
        semaphore.wait()
        defer {
            semaphore.signal()
        }
        count += data.count
        queue.append(contentsOf: data)
        if needSort {
            queue.sort { CMTimeCompare($0.position, $1.position) == -1 }
        }
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
