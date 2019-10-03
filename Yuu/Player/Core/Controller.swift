//
//  Controller.swift
//  Yuu
//
//  Created by Skylar on 2019/9/25.
//  Copyright © 2019 Skylar. All rights reserved.
//

import Foundation
import MetalKit

protocol ControllerProtocol: NSObjectProtocol {
    func controlCenter(controller: Controller, didRender position: TimeInterval, duration: TimeInterval)
}

enum ControlState: Int {
    case Origin = 0
    case Playing
    case Paused
    case Stopped
    case Closed
}

class Controller: NSObject {
    
    private let context  = FormatContext()
    
    private var vtDecoder: VTDecoder?
    private var ffDecoder: FFDecoder?
    private var videoDecoder: VideoDecoder?
    private var audioDecoder: AudioDecoder?
    
    private var queueManager: QueueManager!
    
    private let readPacketOperation = BlockOperation()
    private let videoDecodeOperation = BlockOperation()
    private let audioDecodeOperation = BlockOperation()
    private let controlQueue = OperationQueue()
    
    private weak var mtkView: MTKView?
    private let render = Render()
    weak var delegate: ControllerProtocol?
    
    public private(set) var state: ControlState = .Origin
    
    private var isSeeking = false
    private var videoSeekingTime: TimeInterval = -.greatestFiniteMagnitude
    private var audioSeekingTime: TimeInterval = -.greatestFiniteMagnitude
    private var syncer = Synchronizer()
    private var videoFrame: FlowData?
    private var audioFrame: AudioFrame?
    private var audioManager = AudioManager()
    
    private var timeStamps: [Int: TimeInterval] = [:]
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    init(renderView: MTKView) {
        
        renderView.device = render.device
        renderView.depthStencilPixelFormat = .invalid
        renderView.framebufferOnly = false
        renderView.colorPixelFormat = .bgra8Unorm
        mtkView = renderView

        super.init()
        mtkView!.delegate = self
        audioManager.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    func open(path: String) {
        context.open(path: path)
        queueManager = QueueManager(context: context)
//        vtDecoder = VTDecoder(formatContext: context)
        ffDecoder = FFDecoder(formatContext: context)
        videoDecoder = ffDecoder
        audioDecoder = AudioDecoder(formatContext: context)
        start()
    }
    
    func start() {
        readPacketOperation.addExecutionBlock {
            self.readPacket()
        }
        videoDecodeOperation.addExecutionBlock {
            self.decodeVideoFrame()
        }
        controlQueue.addOperation(readPacketOperation)
        controlQueue.addOperation(videoDecodeOperation)
        audioManager.play()
    }
    
    func pause() {
        state = .Paused
        audioManager.stop()
        mtkView?.isPaused = true
    }
    
    func resume() {
        state = .Playing
        audioManager.play()
        mtkView?.isPaused = false
    }
    
    func close() {
        audioManager.stop()
        state = .Closed
        controlQueue.cancelAllOperations()
        controlQueue.waitUntilAllOperationsAreFinished()
        queueManager.allFlush()
        context.closeFile()
    }
    
    func seeking(time: TimeInterval) {
        videoSeekingTime = time * context.duration
        audioSeekingTime = videoSeekingTime
        isSeeking = true
    }
    
    @objc func appWillResignActive() {
        pause()
    }
    
    func readPacket() {
        var finished = false
        while !finished {
            if state == .Closed {
                break
            }
            if state == .Paused {
                Thread.sleep(forTimeInterval: 0.03)
                continue
            }
            if queueManager.queueIsFull() {
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
                }
            }
        }
    }
    
    func decodeVideoFrame() {
        while state != .Closed {
            if state == .Paused {
                Thread.sleep(forTimeInterval: 0.03)
                continue
            }
            var index = 0
            var min: TimeInterval = .greatestFiniteMagnitude
            for (key, queue) in queueManager.packetsQueue {
                if queue.count == 0 {
                    continue
                }
                if let timeStamp = timeStamps[index] {
                    if timeStamp < min {
                        min = timeStamp
                        index = key
                        continue
                    }
                } else {
                    index = key
                    break
                }
            }
            let queue = queueManager.fetchFrameQueue(by: index)
            while true {
                if queue.count > 20 {
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

extension Controller: MTKViewDelegate {
    func draw(in view: MTKView) {
        if let playFrame = videoFrame {
            if playFrame is MarkerFrame {
                videoSeekingTime = -Double.greatestFiniteMagnitude
                videoFrame = nil
                return
            }
            if videoSeekingTime > 0 {
                videoFrame = nil
                return
            }
            if !syncer.shouldRenderVideoFrame(position: playFrame.position, duration: playFrame.duration) {
                return
            }
            render.render(frame: playFrame as! RenderData, drawIn: mtkView!)
            delegate?.controlCenter(controller: self, didRender: playFrame.position, duration: context.duration)
            videoFrame = nil
        } else {
            videoFrame = queueManager.videoFrameQueue.dequeue()
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}

extension Controller: AudioManagerDelegate {
    func fetch(outputData: UnsafeMutablePointer<Int16>, numberOfFrames: UInt32, numberOfChannels: UInt32) {
        var nof = numberOfFrames
        var od = outputData
        while nof > 0 {
            if let frame = audioFrame {
                if (self.audioSeekingTime > 0) {
                    memset(od, 0, Int(nof * numberOfChannels) * MemoryLayout<Int16>.size);
                    self.audioFrame = nil
                    return
                }
                syncer.updateAudioClock(position: frame.position)
                let nsData = frame.samples as NSData
                let bytes: UnsafePointer<UInt8> = nsData.bytes.assumingMemoryBound(to: UInt8.self).advanced(by: frame.outputOffset)
                let bytesLeft = frame.samples.count - frame.outputOffset
                let frameSizeOf = Int(numberOfChannels) * MemoryLayout<Int16>.size
                let  bytesToCopy = min(Int(nof) * frameSizeOf, bytesLeft)
                let  framesToCopy = bytesToCopy / frameSizeOf
                memcpy(od, bytes, bytesToCopy)
                nof -= UInt32(framesToCopy)
                od = od.advanced(by: framesToCopy * Int(numberOfChannels))
                
                if (bytesToCopy < bytesLeft) {
                    frame.outputOffset += bytesToCopy
                } else {
                    self.audioFrame = nil
                }
            } else if let frame = queueManager.audioFrameQueue.dequeue() {
                if frame is MarkerFrame {
                    memset(od, 0, Int(nof * numberOfChannels) * MemoryLayout<Int16>.size);
                    audioSeekingTime = -Double.greatestFiniteMagnitude
                    self.audioFrame = nil
                } else {
                    self.audioFrame = frame as? AudioFrame
                }
            } else {
                memset(od, 0, Int(nof * numberOfChannels) * MemoryLayout<Int16>.size)
            }
        }
    }
    
}
