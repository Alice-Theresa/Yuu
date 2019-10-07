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
    var duration: CMTime { get }
    var position: CMTime { get }
}

class Packet: YuuPacket, FlowData {
    var position: CMTime
    var duration: CMTime
    
    init(duration: CMTime, position: CMTime) {
        self.duration = duration
        self.position = position
        super.init()
    }
    
    override init() {
        self.duration = .zero
        self.position = .zero
        super.init()
    }
}

class MarkerFrame: FlowData {
    var duration: CMTime = .zero
    var position: CMTime = .zero
}

class AudioFrame: FlowData {
    var duration: CMTime = .zero
    var position: CMTime = .zero
    
    var samples: Data
    var outputOffset: Int = 0

    init(duration: CMTime, position: CMTime, samples: Data) {
        self.duration = duration
        self.position = position
        self.samples = samples
    }

}

class NV12VideoFrame: FlowData, RenderDataNV12 {
    
    let width: Int
    let height: Int
    let pixelBuffer: CVPixelBuffer
    
    var duration: CMTime
    var position: CMTime
    
    init(duration: CMTime, position: CMTime, pixelBuffer: CVPixelBuffer) {
        self.duration = duration
        self.position = position
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
    
    var duration: CMTime
    var position: CMTime
    
    deinit {
        luma_channel_pixels.deallocate()
        chromaB_channel_pixels.deallocate()
        chromaR_channel_pixels.deallocate()
    }
    
    init(duration: CMTime, position: CMTime, width: Int, height: Int, frame: YuuFrame) {
        self.duration = duration
        self.position = position
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
