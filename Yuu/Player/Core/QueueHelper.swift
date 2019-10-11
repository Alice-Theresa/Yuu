//
//  QueueHelper.swift
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
    func enqueue(_ frame: [FlowData], streamIndex: Int)
    func flush()
}

class ObjectQueue {
    
    let queueType: QueueType
    let trackType: TrackType
    let needSort: Bool
    
    private(set) var count = 0
    private(set) var size = 0
    
    private let semaphore = DispatchSemaphore(value: 1)
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
        size += data.reduce(0) { $0 + $1.size }
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
            size -= node.size
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
        size = 0
    }
    
}
