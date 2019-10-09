//
//  DemuxLayer.swift
//  Yuu
//
//  Created by Skylar on 2019/10/3.
//  Copyright © 2019 Skylar. All rights reserved.
//

import Foundation


class DemuxLayer: Controlable {
    
    weak var delegate: DemuxToQueueProtocol?

    private var state = ControlState.origin
    private var isSeeking = false
    private var videoSeekingTime: TimeInterval = -.greatestFiniteMagnitude
    
    private let controlQueue = OperationQueue()
    
    private let context: FormatContext
    
    deinit {
        print("demux layer deinit")
    }
    
    init(context: FormatContext) {
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
        while true {
            guard let delegate = delegate else {
                Thread.sleep(forTimeInterval: 0.03)
                continue
            }
            if state == .closed {
                break
            }
            if state == .paused {
                Thread.sleep(forTimeInterval: 0.03)
                continue
            }
            if delegate.packetQueueIsFull() {
                Thread.sleep(forTimeInterval: 0.03)
                continue
            }
            if isSeeking {
                context.seeking(time: videoSeekingTime)
                delegate.flush()
                delegate.enqueueDiscardPacket()
                isSeeking = false
                continue
            }
            let packet = Packet()
            let result = context.read(packet: packet)
            if result < 0 {
                break
            } else {
                delegate.enqueue(packet)
            }
        }
    }
    
}
