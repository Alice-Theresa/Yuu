//
//  DecodeLayer.swift
//  Yuu
//
//  Created by Skylar on 2019/10/3.
//  Copyright © 2019 Skylar. All rights reserved.
//

import Foundation

class DecodeLayer: Controlable {
    
    private var state = ControlState.origin
    
    private let decodeOperation = BlockOperation()
    private let controlQueue = OperationQueue()
    
    private let queueManager: QueueManager
    private let context: FormatContext
    
    private var timeStamps: [Int: CMTime] = [:]
    
//    private var vtDecoder: VTDecoder
    private var ffDecoder: FFDecoder
    private var videoDecoder: VideoDecoder
    private var audioDecoder: AudioDecoder
    
    init(context: FormatContext, queueManager: QueueManager) {
        self.queueManager = queueManager
        self.context = context
//        vtDecoder = VTDecoder(formatContext: context)
        ffDecoder = FFDecoder(formatContext: context)
        videoDecoder = ffDecoder
        audioDecoder = AudioDecoder(formatContext: context)
    }
    
    func start() {
        decodeOperation.addExecutionBlock {
            self.decodingFrame()
        }
        controlQueue.addOperation(decodeOperation)
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
    
    func decodingFrame() {
        while state != .closed {
            if state == .paused {
                Thread.sleep(forTimeInterval: 0.03)
                continue
            }
            var index = -1
            var min: CMTime = .zero
            for (key, queue) in queueManager.packetsQueue {
                if queue.count == 0 {
                    continue
                }
                if let timeStamp = timeStamps[index] {
                    if CMTimeCompare(timeStamp, min) < 0 {
                        min = timeStamp
                        index = key
                        continue
                    }
                } else {
                    index = key
                    break
                }
            }
            if index == -1 {
                continue
            }
            let queue = queueManager.fetchFrameQueue(by: index)
            while true {
                if queue.count > 20 && !decodeOperation.isCancelled {
                    Thread.sleep(forTimeInterval: 0.03)
                    continue
                } else {
                    break
                }
            }
            // dequeue packet
            guard
                let packetqueue = queueManager.packetsQueue[index],
                let packet = packetqueue.dequeue() as? Packet else { continue }
            // update timestamps
            timeStamps[index] = packet.position
            
            if packet.flags == .discard {
                let c = queue.trackType == .video ? context.videoCodecContext : context.audioCodecContext
                avcodec_flush_buffers(c?.cContextPtr)
                queue.flush()
                queue.enqueue([MarkerFrame.init()])
                packet.unref()
                continue
            }
            let decoder: Decodable? = queue.trackType == .video ? videoDecoder : audioDecoder
            if let vd = decoder, packet.data != nil && packet.streamIndex >= 0 {
                let frames = vd.decode(packet: packet)
                queue.enqueue(frames)
            }
        }
    }
    
}
