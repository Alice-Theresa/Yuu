//
//  PlayerController.swift
//  Yuu
//
//  Created by Skylar on 2019/9/25.
//  Copyright © 2019 Skylar. All rights reserved.
//

import UIKit
import MetalKit

class PlayerController: UIViewController {
    
    var mtkView: MTKView
    var controller: Controller!
    var playerView: PlayerControlView
    var isHideContainer = false
    var isTouchSlider = false

    init() {
        mtkView = MTKView()
        playerView = PlayerControlView()
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        let path = Bundle.main.resourcePath! + "/Aimer.mkv"
        controller.open(path: path)
    }

    func setup() {
        view.backgroundColor = .black
        mtkView.frame = view.bounds
        playerView.frame = view.bounds
        view.addSubview(mtkView)
        mtkView.addSubview(playerView)
        
        controller = Controller.init(renderView: mtkView)
        controller.delegate = self
        
        playerView.actionButton.addTarget(self, action: #selector(resumeOrPause), for: .touchUpInside)
        playerView.backButton.addTarget(self, action: #selector(pop), for: .touchUpInside)
        playerView.progressSlide.addTarget(self, action: #selector(seekingTime), for: .touchUpInside)
        playerView.progressSlide.addTarget(self, action: #selector(touchSlider), for: .touchUpInside)
        let tap = UITapGestureRecognizer.init(target: self, action: #selector(showOrHideView))
        playerView.addGestureRecognizer(tap)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.isHidden = false
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        controller.close()
    }
    
    @objc func showOrHideView() {
        playerView.hideAll(!isHideContainer)
        isHideContainer = !isHideContainer
    }
    
    @objc func resumeOrPause() {
        if controller.state == .playing {
            controller.pause()
            playerView.settingPause()
        } else {
            controller.resume()
            playerView.settingPlay()
        }
    }
    
    @objc func touchSlider() {
        isTouchSlider = true
    }
    
    @objc func seekingTime() {
        controller.seeking(time: TimeInterval(playerView.progressSlide.value))
        isTouchSlider = false
    }
    
    @objc func pop() {
        navigationController?.popViewController(animated: true)
    }

}

extension PlayerController: ControllerProtocol {
    func controlCenter(didRender position: TimeInterval, duration: TimeInterval) {
        let playing = Int(position)
        let length = Int(duration)
        let total = "\(length / 3600):\(length % 3600 / 60):\(length % 3600 % 60)"
        if !isTouchSlider {
            let current = "\(playing / 3600):\(playing % 3600 / 60):\(playing % 3600 % 60)"
            playerView.timeLabel.text = "\(current)/\(total)"
            playerView.progressSlide.value = Float(position / duration)
        } else {
            let result = Int(playerView.progressSlide.value) * length
            let current = "\(result / 3600):\(result % 3600 / 60):\(result % 3600 % 60)"
            playerView.timeLabel.text = "\(current)/\(total)"
        }
    }
}
