//
//  RenderLayer.swift
//  Yuu
//
//  Created by Skylar on 2019/10/3.
//  Copyright © 2019 Skylar. All rights reserved.
//

import Foundation
import MetalKit

class RenderLayer: NSObject {

    private var state = ControlState.origin
    private var isSeeking = false

    private let queueManager: QueueManager
    private let context: FormatContext
    
    private var mtkView: MTKView
    private let render = Render()
    weak var delegate: ControllerProtocol?
    
    private var videoSeekingTime: TimeInterval = -.greatestFiniteMagnitude
    private var audioSeekingTime: TimeInterval = -.greatestFiniteMagnitude
    
    private var syncer = Synchronizer()
    private var videoFrame: FlowData?
    private var audioFrame: AudioFrame?
    private var audioManager = AudioManager()
    
    let videoFrameQueue  = ObjectQueue(queueType: .frame, trackType: .video, needSort: true)
    let audioFrameQueue  = ObjectQueue(queueType: .frame, trackType: .audio, needSort: true)
    private let videoTracksIndexes: [Int]
    private let audioTracksIndexes: [Int]
    
    deinit {
        print("render layer deinit")
    }
    
    init(context: FormatContext, queueManager: QueueManager, mtkView: MTKView) {
        self.queueManager = queueManager
        self.context = context
        videoTracksIndexes = context.tracks.filter{ $0.type == .video }.map { $0.index }
        audioTracksIndexes = context.tracks.filter{ $0.type == .audio }.map { $0.index }
        
        mtkView.device = render.device
        mtkView.depthStencilPixelFormat = .invalid
        mtkView.framebufferOnly = false
        mtkView.colorPixelFormat = .bgra8Unorm
        self.mtkView = mtkView
        super.init()
        mtkView.delegate = self
        audioManager.delegate = self
    }
    
    func start() {
        audioManager.play()
    }
    
    func pause() {
        mtkView.isPaused = true
        audioManager.stop()
    }
    
    func resume() {
        mtkView.isPaused = false
        audioManager.play()
    }
    
    func close() {
        audioManager.stop()
    }
    
    func seeking(time: TimeInterval) {
        videoSeekingTime = time
        isSeeking = true
        audioSeekingTime = time
    }
    
}

extension RenderLayer: MTKViewDelegate {
    func draw(in view: MTKView) {
        if let playFrame = videoFrame {
            if playFrame is MarkerFrame {
                videoSeekingTime = -.greatestFiniteMagnitude
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
            render.render(frame: playFrame as! RenderData, drawIn: mtkView)
//            delegate?.controlCenter(didRender: playFrame.position, duration: context.duration)
            videoFrame = nil
        } else {
            videoFrame = queueManager.videoFrameQueue.dequeue()
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}

extension RenderLayer: AudioManagerDelegate {
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

//extension RenderLayer: DecodeToQueueProtocol {
//    func frameQueueIsFull(streamIndex: Int) -> Bool {
//        
//    }
//    
//    func enqueue(_ frame: FlowData) {
//        
//    }
//    
//    func flush() {
//        
//    }
//}
