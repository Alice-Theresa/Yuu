//
//  DecodeLayer.swift
//  Yuu
//
//  Created by Skylar on 2019/10/3.
//  Copyright © 2019 Skylar. All rights reserved.
//

import Foundation

class DecodeLayer: Controlable {
    
    weak var delegate: DecodeToQueueProtocol?
    
    private var state = ControlState.origin
    private let controlQueue = OperationQueue()
    private let context: FormatContext
    
    private var timeStamps: [Int: CMTime] = [:]
    private var packetsQueue: [Int: ObjectQueue] = [:]
    
//    private var vtDecoder: VTDecoder
    private var ffDecoder: FFDecoder
    private var videoDecoder: VideoDecoder
    private var audioDecoder: AudioDecoder
    
    deinit {
        print("decode layer deinit")
    }
    
    init(context: FormatContext, demuxLayer: DemuxLayer) {
        self.context = context
//        vtDecoder = VTDecoder(formatContext: context)
        ffDecoder = FFDecoder(formatContext: context)
        videoDecoder = ffDecoder
        audioDecoder = AudioDecoder(formatContext: context)
        
        for track in context.tracks {
            packetsQueue[track.index] = ObjectQueue(queueType: .packet, trackType: track.type, needSort: false)
        }
        demuxLayer.delegate = self
    }
    
    func start() {
        let decodeOperation = BlockOperation()
        decodeOperation.addExecutionBlock {
            self.decodingFrame()
        }
        controlQueue.addOperation(decodeOperation)
        state = .playing
    }
    
    func close() {
        flush()
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
            guard let delegate = delegate else {
                Thread.sleep(forTimeInterval: 0.03)
                continue
            }
            if state == .paused {
                Thread.sleep(forTimeInterval: 0.03)
                continue
            }
            var streamIndex = -1
            var min: CMTime = .zero
            for (key, queue) in packetsQueue {
                if queue.count == 0 {
                    continue
                }
                if let timeStamp = timeStamps[streamIndex] {
                    if CMTimeCompare(timeStamp, min) < 0 {
                        min = timeStamp
                        streamIndex = key
                        continue
                    }
                } else {
                    streamIndex = key
                    break
                }
            }
            if streamIndex == -1 {
                continue
            }
            while true {
                if delegate.frameQueueIsFull(streamIndex: streamIndex) {
                    Thread.sleep(forTimeInterval: 0.03)
                    continue
                } else {
                    break
                }
            }
            // dequeue packet
            guard
                let packetqueue = packetsQueue[streamIndex],
                let packet = packetqueue.dequeue() as? Packet else { continue }
            // update timestamps
            timeStamps[streamIndex] = packet.position
            
            if packet.flags == .discard {
                let c = packet.codecDescriptor!.trackType == .video ? context.videoCodecContext : context.audioCodecContext
                avcodec_flush_buffers(c?.cContextPtr)
                delegate.flush()
                delegate.enqueue([MarkerFrame.init()], streamIndex: streamIndex)
                packet.unref()
                continue
            }
            let decoder: Decodable? = packet.codecDescriptor!.trackType == .video ? videoDecoder : audioDecoder
            if let vd = decoder, packet.data != nil && packet.streamIndex >= 0 {
                let frames = vd.decode(packet: packet)
                delegate.enqueue(frames, streamIndex: streamIndex)
            }
        }
    }
    
}

extension DecodeLayer: DemuxToQueueProtocol {
    func packetQueueIsFull() -> Bool {
        var total = 0
        for queue in packetsQueue {
            total += queue.value.count
        }
        return total > 20
    }
    
    func enqueue(_ packet: Packet) {
        if let queue = packetsQueue[packet.streamIndex] {
            let stream             = context.formatContext.streams[packet.streamIndex]
            let codecDescriptor    = CodecDescriptor(timebase: stream.timebase, trackType: queue.trackType)
            let timeBase           = stream.timebase
            packet.position        = CMTimeMake(value: Int64(packet.pts) * Int64(timeBase.num), timescale: timeBase.den)
            packet.codecDescriptor = codecDescriptor
            queue.enqueue([packet])
        }
    }
    
    func flush() {
        for (_, queue) in packetsQueue {
            queue.flush()
        }
    }
    
    func enqueueDiscardPacket() {
        for (_, queue) in packetsQueue {
            let packet             = Packet()
            packet.flags           = .discard
            packet.codecDescriptor = CodecDescriptor(timebase: AVRational(), trackType: queue.trackType)
            queue.enqueue([packet])
        }
    }
}

