//
//  DemuxLayer.swift
//  Yuu
//
//  Created by Skylar on 2019/10/3.
//  Copyright © 2019 Skylar. All rights reserved.
//

import Foundation

protocol DemuxPacketProtocol: class {
    func packetQueueIsFull() -> Bool
    func enqueueDiscardPacket()
    func enqueue(_ packet: Array<FlowData>)
}

class DemuxLayer: Controlable {
    
    weak var delegate: DemuxPacketProtocol?

    private var state = ControlState.origin
    private var isSeeking = false
    private var videoSeekingTime: TimeInterval = -.greatestFiniteMagnitude
    
    private let controlQueue = OperationQueue()
    
    private let queueManager: QueueManager
    private let context: FormatContext
    
    init(context: FormatContext, queueManager: QueueManager) {
        self.queueManager = queueManager
        self.context = context
    }
    
    func start() {
        let readPacketOperation = BlockOperation()
        readPacketOperation.addExecutionBlock {
            self.readPacket()
        }
        controlQueue.addOperation(readPacketOperation)
        state = .playing
    }
    
    func close() {
        state = .closed
        controlQueue.cancelAllOperations()
        controlQueue.waitUntilAllOperationsAreFinished()
    }
    
    func resume() {
        state = .playing
    }
    
    func pause() {
        state = .paused
    }
    
    func seeking(time: TimeInterval) {
        videoSeekingTime = time
        isSeeking = true
    }
    
    private func readPacket() {
        var finished = false
        while !finished {
            if state == .closed {
                break
            }
            if state == .paused {
                Thread.sleep(forTimeInterval: 0.03)
                continue
            }
            if queueManager.packetQueueIsFull() {
                Thread.sleep(forTimeInterval: 0.03)
                continue
            }
            if isSeeking {
                context.seeking(time: videoSeekingTime)
                queueManager.allFlush()
                queueManager.enqueueDiscardPacket()
                isSeeking = false
                continue
            }
            let packet = Packet()
            let result = context.read(packet: packet)
            if result < 0 {
                finished = true
                break
            } else {
                if let queue = queueManager.packetsQueue[packet.streamIndex] {
                    queue.enqueue([packet])
                    print("\(queue.trackType) + \(packet.position)")
                }
            }
        }
    }
    
}
