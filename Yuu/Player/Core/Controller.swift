//
//  Controller.swift
//  Yuu
//
//  Created by Skylar on 2019/9/25.
//  Copyright © 2019 Skylar. All rights reserved.
//

import Foundation
import MetalKit

protocol Controlable {
    func start()
    func pause()
    func resume()
    func close()
}

protocol ControllerProtocol: class {
    func controlCenter(didRender position: TimeInterval, duration: TimeInterval)
}

enum ControlState {
    case origin
    case playing
    case paused
    case closed
}

class Controller {
    
    private let context  = FormatContext()
    
    private var demuxLayer: DemuxLayer!
    private var decodeLayer: DecodeLayer!
    private var renderLayer: RenderLayer!
    
    private var mtkView: MTKView
    private let render = Render()
    weak var delegate: ControllerProtocol?
    
    public private(set) var state: ControlState = .origin
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    init(renderView: MTKView) {
        mtkView = renderView
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    func open(path: String) {
        context.open(path: path)
        demuxLayer = DemuxLayer(context: context)
        decodeLayer = DecodeLayer(context: context, demuxLayer: demuxLayer)
        renderLayer = RenderLayer(context: context, decodeLayer: decodeLayer, mtkView: mtkView)
        start()
    }
    
    func start() {
        state = .playing
        demuxLayer.start()
        decodeLayer.start()
        renderLayer.start()
    }
    
    func pause() {
        state = .paused
        demuxLayer.pause()
        decodeLayer.pause()
        renderLayer.pause()
    }
    
    func resume() {
        state = .playing
        demuxLayer.resume()
        decodeLayer.resume()
        renderLayer.resume()
    }
    
    func close() {
        state = .closed
        demuxLayer.close()
        decodeLayer.close()
        renderLayer.close()
        context.closeFile()
    }
    
    func seeking(percentage: TimeInterval) {
        let seconds = CMTimeGetSeconds(context.totalDuration)
        demuxLayer.seeking(time: percentage * seconds)
    }
    
    @objc func appWillResignActive() {
        pause()
    }
    
}
