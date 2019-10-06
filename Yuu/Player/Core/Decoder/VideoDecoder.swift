//
//  VideoDecoder.swift
//  Yuu
//
//  Created by Skylar on 2019/9/25.
//  Copyright © 2019 Skylar. All rights reserved.
//

import Foundation
import VideoToolbox

protocol Decodable {
    func decode(packet: Packet) -> Array<FlowData>
}

protocol VideoDecoder: Decodable {
    var context: FormatContext? { get }
}

class VTDecoder: VideoDecoder {
    
    weak var context: FormatContext?
    
    var session: VTDecompressionSession?
    var formatDescription: CMVideoFormatDescription?
    
    deinit {
        if let session = session {
            VTDecompressionSessionWaitForAsynchronousFrames(session)
            VTDecompressionSessionInvalidate(session)
        }
    }
    
    init(formatContext: FormatContext) {
        context = formatContext
        tryInitDecoder(context: formatContext)
    }
    
    func tryInitDecoder(context: FormatContext) {
        guard let codecContext = context.videoCodecContext, let data = codecContext.extradata else {
            fatalError()
        }
        let dataSize = codecContext.extradataSize
        if dataSize < 7 || data[0] != 1 {
            fatalError()
        }
        formatDescription = createFormatDescription(codec_type: kCMVideoCodecType_H264,
                                                    width: Int32(codecContext.width),
                                                    height: Int32(codecContext.height),
                                                    extradata: data,
                                                    extradata_size: Int32(dataSize))
        guard let desc = formatDescription else { fatalError() }
        let destinationPixelBufferAttributes = NSMutableDictionary()
        destinationPixelBufferAttributes.setValue(NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange), forKey: kCVPixelBufferPixelFormatTypeKey as String)
        var callBackRecord = VTDecompressionOutputCallbackRecord()
        callBackRecord.decompressionOutputCallback = YuuDidDecompress
        callBackRecord.decompressionOutputRefCon = Unmanaged.passUnretained(self).toOpaque()
        let status = VTDecompressionSessionCreate(allocator: kCFAllocatorDefault,
                                                  formatDescription: desc,
                                                  decoderSpecification: NSMutableDictionary(),
                                                  imageBufferAttributes: destinationPixelBufferAttributes,
                                                  outputCallback: &callBackRecord,
                                                  decompressionSessionOut: &session)
        print(status)
    }
    
    func decode(packet: Packet) -> Array<FlowData> {
        var outputPixelBuffer: CVPixelBuffer?
        var blockBuffer: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault,
                                                        memoryBlock: packet.data,
                                                        blockLength: Int(packet.size),
                                                        blockAllocator: kCFAllocatorNull,
                                                        customBlockSource: nil,
                                                        offsetToData: 0,
                                                        dataLength: Int(packet.size),
                                                        flags: 0,
                                                        blockBufferOut: &blockBuffer)
        if status == kCMBlockBufferNoErr {
            var sampleBuffer: CMSampleBuffer?
            status = CMSampleBufferCreate(allocator: kCFAllocatorDefault,
                                          dataBuffer: blockBuffer,
                                          dataReady: true,
                                          makeDataReadyCallback: nil,
                                          refcon: nil,
                                          formatDescription: formatDescription,
                                          sampleCount: 1,
                                          sampleTimingEntryCount: 0,
                                          sampleTimingArray: nil,
                                          sampleSizeEntryCount: 0,
                                          sampleSizeArray: nil,
                                          sampleBufferOut: &sampleBuffer)
            if (status == kCMBlockBufferNoErr) {
                if let sampleBuffer = sampleBuffer, let session = session {
                    var flagsOut: VTDecodeInfoFlags = []
                    let decodeStatus = VTDecompressionSessionDecodeFrame(session, sampleBuffer: sampleBuffer, flags: [], frameRefcon: &outputPixelBuffer, infoFlagsOut: &flagsOut)
                    if (decodeStatus == kVTInvalidSessionErr) {
                        
                    } else if(decodeStatus == kVTVideoDecoderBadDataErr) {
                        
                    } else if(decodeStatus != noErr) {
                        
                    }
                    if let outputPixelBuffer = outputPixelBuffer, let context = context {
                        let videoFrame = NV12VideoFrame(pixelBuffer: outputPixelBuffer)
//                        videoFrame.durationStamp = ds
//                        videoFrame.positionStamp = ps
                        packet.unref()
                        return [videoFrame]
                    }
                }
            }
        }
        packet.unref()
        return []
    }
    
    func createFormatDescription(codec_type: CMVideoCodecType,
                                 width: Int32,
                                 height: Int32,
                                 extradata: UnsafePointer<UInt8>,
                                 extradata_size: Int32) -> CMFormatDescription? {
        let params = NSMutableDictionary()
        let atoms = NSMutableDictionary()
        let extensions = NSMutableDictionary()
        var formatDescription: CMFormatDescription?
        
        params.setObject(0, forKey: "HorizontalSpacing" as NSString)
        params.setObject(0, forKey: "VerticalSpacing" as NSString)
        
        atoms.setObject(NSData(bytes: extradata, length: Int(extradata_size)), forKey: "avcC" as NSString)
        
        extensions.setObject(params, forKey: "CVPixelAspectRatio" as NSString)
        extensions.setObject(atoms, forKey: "SampleDescriptionExtensionAtoms" as NSString)
        extensions.setObject("avcC", forKey: "FormatName" as NSString)
        extensions.setObject("left", forKey: "CVImageBufferChromaLocationBottomField" as NSString)
        extensions.setObject("left", forKey: "CVImageBufferChromaLocationTopField" as NSString)
        extensions.setObject(0, forKey: "FullRangeVideo" as NSString)
        
        CMVideoFormatDescriptionCreate(allocator: nil,
                                       codecType: CMVideoCodecType(codec_type),
                                       width: width,
                                       height: height,
                                       extensions: extensions,
                                       formatDescriptionOut: &formatDescription)
        return formatDescription
    }
}

class FFDecoder: VideoDecoder {
    weak var context: FormatContext?
    var tempFrame: YuuFrame
    
    init(formatContext: FormatContext) {
        context = formatContext
        tempFrame = YuuFrame()
    }
    
    func decode(packet: Packet) -> Array<FlowData> {
        let defaultArray: [FlowData] = []
        var array: [FlowData] = []
        guard let _ = packet.data, let context = context, let vcc = context.videoCodecContext else { return defaultArray }
        do {
            try vcc.sendPacket(packet)
        } catch {
            return defaultArray
        }
        while true {
            do {
                try vcc.receiveFrame(tempFrame)
                if let frame = videoFrameFromTempFrame() {
                    array.append(frame)
                }
            } catch {
                break
            }
        }
        packet.unref()
        return array
    }
    
    func videoFrameFromTempFrame() -> I420VideoFrame?  {
        guard let _ = tempFrame.data[0],
            let _ = tempFrame.data[1],
            let _ = tempFrame.data[2],
            let context = context,
            let vcc = context.videoCodecContext else { return nil }

        let timeBase = context.codecDescriptor!.timebase
        
        let ps = CMTimeMake(value: Int64(tempFrame.bestEffortTimestamp) * Int64(timeBase.num), timescale: timeBase.den)
        let ds = CMTimeMake(value: Int64(tempFrame.pktDuration) * Int64(timeBase.num), timescale: timeBase.den)
        let videoFrame = I420VideoFrame(width: vcc.width,
                                        height: vcc.height,
                                        frame: tempFrame)
        videoFrame.duration = ds
        videoFrame.position = ps
        return videoFrame
    }

}
