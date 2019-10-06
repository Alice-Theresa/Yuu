//
//  YuuFrame.swift
//  Yuu
//
//  Created by Skylar on 2019/9/25.
//  Copyright © 2019 Skylar. All rights reserved.
//

import Foundation

class YuuFrame {
    
    let cFramePtr: UnsafeMutablePointer<AVFrame>
    var cFrame: AVFrame { return cFramePtr.pointee }
    
    deinit {
        var ptr: UnsafeMutablePointer<AVFrame>? = cFramePtr
        av_frame_free(&ptr)
    }
    init(cFramePtr: UnsafeMutablePointer<AVFrame>) {
        self.cFramePtr = cFramePtr
    }
    
    init() {
        guard let framePtr = av_frame_alloc() else {
            fatalError()
        }
        self.cFramePtr = framePtr
    }
    
    var data: UnsafeMutableBufferPointer<UnsafeMutablePointer<UInt8>?> {
        get {
            return withUnsafeMutableBytes(of: &cFramePtr.pointee.data) { ptr in
                return ptr.bindMemory(to: UnsafeMutablePointer<UInt8>?.self)
            }
        }
        set {
            withUnsafeMutableBytes(of: &cFramePtr.pointee.data) { ptr in
                ptr.copyMemory(from: UnsafeRawBufferPointer(newValue))
            }
        }
    }
    
    var linesize: UnsafeMutableBufferPointer<Int32> {
        get {
            return withUnsafeMutableBytes(of: &cFramePtr.pointee.linesize) { ptr in
                return ptr.bindMemory(to: Int32.self)
            }
        }
        set {
            withUnsafeMutableBytes(of: &cFramePtr.pointee.linesize) { ptr in
                ptr.copyMemory(from: UnsafeRawBufferPointer(newValue))
            }
        }
    }
    
    var sampleCount: Int {
        get { return Int(cFrame.nb_samples) }
        set { cFramePtr.pointee.nb_samples = Int32(newValue) }
    }
    
    var repeatPicture: Int {
        return Int(cFrame.repeat_pict)
    }
    
    var pktDuration: Int {
        return Int(cFrame.pkt_duration)
    }
    
    var bestEffortTimestamp: Int {
        return Int(cFrame.best_effort_timestamp)
    }
}
