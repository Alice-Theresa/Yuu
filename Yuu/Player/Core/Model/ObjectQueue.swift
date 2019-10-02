//
//  ObjectQueue.swift
//  Yuu
//
//  Created by Skylar on 2019/10/1.
//  Copyright © 2019 Skylar. All rights reserved.
//

import Foundation

class ObjectQueue {
    
    private let semaphore = DispatchSemaphore(value: 1)
    
    private(set) var count = 0
    
    private var queue: [FlowData] = []
    
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
