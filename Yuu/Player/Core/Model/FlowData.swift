//
//  Data.swift
//  Yuu
//
//  Created by Skylar on 2019/10/2.
//  Copyright © 2019 Skylar. All rights reserved.
//

import Foundation
import MetalKit

protocol FlowData {
    var position: TimeInterval { get }
    var duration: TimeInterval { get }
}

class Packet: YuuPacket, FlowData {
    var position: TimeInterval {
        get {
            return TimeInterval(pos)
        }
    }
    
    var duration: TimeInterval {
        get {
            return TimeInterval(dur)
        }
    }
}

class MarkerFrame: FlowData {
    var position: TimeInterval = -.greatestFiniteMagnitude
    var duration: TimeInterval = -.greatestFiniteMagnitude
}

class AudioFrame: FlowData {
    var position: TimeInterval
    var duration: TimeInterval
    
    var samples: Data
    var outputOffset: Int = 0

    init(position: TimeInterval, duration: TimeInterval, samples: Data) {
        self.position = position
        self.duration = duration
        self.samples = samples
    }

}

class NV12VideoFrame: FlowData, RenderDataNV12 {
    
    let width: Int
    let height: Int
    let pixelBuffer: CVPixelBuffer
    
    let position: TimeInterval
    let duration: TimeInterval
    
    init(position: TimeInterval, duration: TimeInterval, pixelBuffer: CVPixelBuffer) {
        self.position = position
        self.duration = duration
        self.pixelBuffer = pixelBuffer
        self.width = CVPixelBufferGetWidth(pixelBuffer)
        self.height = CVPixelBufferGetHeight(pixelBuffer)
    }
}

class I420VideoFrame: FlowData, RenderDataI420 {
    var luma_channel_pixels: UnsafeMutablePointer<UInt8>
    var chromaB_channel_pixels: UnsafeMutablePointer<UInt8>
    var chromaR_channel_pixels: UnsafeMutablePointer<UInt8>
    
    let width: Int
    let height: Int
    
    let position: TimeInterval
    let duration: TimeInterval
    
    deinit {
        luma_channel_pixels.deallocate()
        chromaB_channel_pixels.deallocate()
        chromaR_channel_pixels.deallocate()
    }
    
    init(position: TimeInterval, duration: TimeInterval, width: Int, height: Int, frame: YuuFrame) {
        self.position = position
        self.duration = duration
        self.width = width
        self.height = height
        
        let linesize_y = Int(frame.linesize[0])
        let linesize_u = Int(frame.linesize[1])
        let linesize_v = Int(frame.linesize[2])
        
        let needsize_y = YuuYUVChannelFilterNeedSize(linesize_y, width, height)
        let needsize_u = YuuYUVChannelFilterNeedSize(linesize_u, width/2, height/2)
        let needsize_v = YuuYUVChannelFilterNeedSize(linesize_v, width/2, height/2)
        
        luma_channel_pixels = UnsafeMutablePointer<UInt8>.allocate(capacity: needsize_y)
        chromaB_channel_pixels = UnsafeMutablePointer<UInt8>.allocate(capacity: needsize_u)
        chromaR_channel_pixels = UnsafeMutablePointer<UInt8>.allocate(capacity: needsize_v)
        
        YuuYUVChannelFilter(frame.data[0]!, linesize_y, width, height, luma_channel_pixels, needsize_y)
        YuuYUVChannelFilter(frame.data[1]!, linesize_u, width / 2, height / 2, chromaB_channel_pixels, needsize_u)
        YuuYUVChannelFilter(frame.data[2]!, linesize_v, width / 2, height / 2, chromaR_channel_pixels, needsize_v)
    }
    
}
