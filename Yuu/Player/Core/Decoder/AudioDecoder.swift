//
//  AudioDecoder.swift
//  Yuu
//
//  Created by Skylar on 2019/9/25.
//  Copyright © 2019 Skylar. All rights reserved.
//

import Foundation

import Foundation
import Accelerate

class AudioDecoder: Decodable {
    
    let samplingRate: Int32 = 44100
    let channelCount: Int32 = 2
    
    var tempFrame: YuuFrame?
    var audioSWRContext: OpaquePointer?
    
    var _audio_swr_buffer: UnsafeMutableRawPointer?
    var _audio_swr_buffer_size: Int = 0
    
    var context: FormatContext?
    var codecContext: UnsafeMutablePointer<AVCodecContext>?
    
    deinit {
        swr_free(&audioSWRContext)
    }
    
    init(formatContext: FormatContext) {
        context = formatContext
        tempFrame = YuuFrame()
        codecContext = formatContext.audioCodecContext?.cContextPtr
        setupSwsContext()
    }
    
    func setupSwsContext() {
        guard let codec = codecContext else { return }
        audioSWRContext = swr_alloc_set_opts(nil,
                                               av_get_default_channel_layout(channelCount),
                                               AV_SAMPLE_FMT_S16,
                                               samplingRate,
                                               av_get_default_channel_layout(codec.pointee.channels),
                                               codec.pointee.sample_fmt,
                                               codec.pointee.sample_rate,
                                               0,
                                               nil)
        let result = swr_init(audioSWRContext)
        if result < 0 || audioSWRContext == nil {
            if let _ = audioSWRContext {
                swr_free(&audioSWRContext)
            }
        }
    }
    
    func decode(packet: Packet) -> Array<FlowData> {
        let defaultArray: [AudioFrame] = []
        var array: [AudioFrame] = []
        guard let _ = packet.data, let context = context else { return defaultArray }
        var result = avcodec_send_packet(context.audioCodecContext?.cContextPtr, packet.cPacketPtr)
        if result < 0 {
            return defaultArray
        }
        while result >= 0 {
            result = avcodec_receive_frame(context.audioCodecContext?.cContextPtr, tempFrame?.cFramePtr)
            if result < 0 {
                break
            }
            if let frame = audioFrameFromTempFrame(packetSize: Int(packet.size)) {
                array.append(frame)
            }
        }
        packet.unref()
        return array
    }
    
    func audioFrameFromTempFrame(packetSize: Int) -> AudioFrame?  {
        
        guard
            let temp = tempFrame,
            let _ = temp.data[0],
            let codecContext = codecContext else { return nil }
        var numberOfFrames: Int32 = 0
        var audioDataBuffer: UnsafeMutableRawPointer?
        if let c = audioSWRContext {
            let ratio = max(1, samplingRate / codecContext.pointee.sample_rate) * max(1, channelCount / codecContext.pointee.channels) * 2
            let buffer_size = av_samples_get_buffer_size(nil, channelCount, Int32(temp.sampleCount) * ratio, AV_SAMPLE_FMT_S16, 1)
            if _audio_swr_buffer == nil || _audio_swr_buffer_size < buffer_size {
                _audio_swr_buffer_size = Int(buffer_size)
                _audio_swr_buffer = realloc(_audio_swr_buffer, _audio_swr_buffer_size)
            }
            
            let tempdata = UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>.allocate(capacity: 4)
            tempdata.initialize(to: nil)

            let data = UnsafeMutableBufferPointer(start: tempdata, count: 4)
            let repeatData = _audio_swr_buffer?.assumingMemoryBound(to: UInt8.self)
            data.assign(repeating: repeatData)
            
            let dataPointer = withUnsafeMutablePointer(to: &temp.cFramePtr.pointee.data){$0}
                .withMemoryRebound(to: Optional<UnsafePointer<UInt8>>.self, capacity: MemoryLayout<UnsafePointer<UInt8>>.stride * 8) {$0}
            numberOfFrames = swr_convert(c,
                                         data.baseAddress,
                                         Int32(temp.sampleCount) * ratio,
                                         dataPointer,
                                         Int32(temp.sampleCount))
            audioDataBuffer = _audio_swr_buffer
            
        }
        let numberOfElements = numberOfFrames * channelCount
        let length = Int(numberOfElements) * MemoryLayout<Int16>.size
        
        let timeBase = context!.audioCodecDescriptor!.timebase
        let ps = CMTimeMake(value: Int64(temp.bestEffortTimestamp) * Int64(timeBase.num), timescale: timeBase.den)
        let ds = CMTimeMake(value: Int64(temp.pktDuration) * Int64(timeBase.num), timescale: timeBase.den)
        
        let samples = Data(bytes: audioDataBuffer!, count: length)
        let audioFrame = AudioFrame(duration: ds, position: ps, samples: samples)
        
        audioFrame.duration = ds
        audioFrame.position = ps
        
        return audioFrame
    }

}
