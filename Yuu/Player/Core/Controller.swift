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
//    case stopped
    case closed
}

class Controller {
    
    private let context  = FormatContext()
    
    private var queueManager: QueueManager!
    private var packetLayer: DemuxLayer!
    private var decodeLayer: DecodeLayer!
    private var renderLayer: RenderLayer!
    
    private var mtkView: MTKView
    private let render = Render()
    weak var delegate: ControllerProtocol?
    
    public private(set) var state: ControlState = .origin
    
    private var videoSeekingTime: TimeInterval = -.greatestFiniteMagnitude
    private var audioSeekingTime: TimeInterval = -.greatestFiniteMagnitude
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    init(renderView: MTKView) {
        mtkView = renderView
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    func open(path: String) {
        context.open(path: path)
        queueManager = QueueManager(context: context)
        packetLayer = DemuxLayer(context: context, queueManager: queueManager)
        decodeLayer = DecodeLayer(context: context, queueManager: queueManager)
        renderLayer = RenderLayer(context: context, queueManager: queueManager, mtkView: mtkView)
        start()
    }
    
    func start() {
        state = .playing
        packetLayer.start()
        decodeLayer.start()
        renderLayer.start()
    }
    
    func pause() {
        state = .paused
        packetLayer.pause()
        decodeLayer.pause()
        renderLayer.pause()
    }
    
    func resume() {
        state = .playing
        packetLayer.resume()
        decodeLayer.resume()
        renderLayer.resume()
    }
    
    func close() {
        state = .closed
        packetLayer.close()
        decodeLayer.close()
        renderLayer.close()
        queueManager.allFlush()
        context.closeFile()
    }
    
    func seeking(time: TimeInterval) {
        videoSeekingTime = time * context.duration
        packetLayer.seeking(time: videoSeekingTime)
    }
    
    @objc func appWillResignActive() {
        pause()
    }
    
}
