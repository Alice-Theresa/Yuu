//
//  PlayerControlView.swift
//  Yuu
//
//  Created by Skylar on 2019/9/25.
//  Copyright © 2019 Skylar. All rights reserved.
//

import UIKit

class PlayerControlView : UIView {
    lazy var backButton: UIButton = {
        let button = UIButton.init(type: .system)
        button.setTitle("back", for: .normal)
        return button
    }()
    
    lazy var actionButton: UIButton = {
        let button = UIButton.init(type: .system)
        button.setTitle("暂停", for: .normal)
        return button
    }()
    
    lazy var timeLabel: UILabel = {
        let label = UILabel.init()
        label.text = "00:00:00/00:00:00"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 10)
        return label
    }()
    
    lazy var progressSlide: UISlider = {
        let slide = UISlider()
        slide.value = 0
        return slide
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(backButton)
        addSubview(actionButton)
        addSubview(timeLabel)
        addSubview(progressSlide)
        
        backButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        progressSlide.translatesAutoresizingMaskIntoConstraints = false
        
        addConstraint(NSLayoutConstraint.init(item: backButton, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1, constant: 20))
        addConstraint(NSLayoutConstraint.init(item: backButton, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1, constant: 40))
        
        addConstraint(NSLayoutConstraint.init(item: actionButton, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1, constant: 20))
        addConstraint(NSLayoutConstraint.init(item: actionButton, attribute: .trailing, relatedBy: .equal, toItem: timeLabel, attribute: .leading, multiplier: 1, constant: -10))
        addConstraint(NSLayoutConstraint.init(item: timeLabel, attribute: .trailing, relatedBy: .equal, toItem: progressSlide, attribute: .leading, multiplier: 1, constant: -10))
        addConstraint(NSLayoutConstraint.init(item: progressSlide, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1, constant: -20))
        
        addConstraint(NSLayoutConstraint.init(item: timeLabel, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 100))
        
        addConstraint(NSLayoutConstraint.init(item: actionButton, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1, constant: -40))
        addConstraint(NSLayoutConstraint.init(item: timeLabel, attribute: .centerY, relatedBy: .equal, toItem: actionButton, attribute: .centerY, multiplier: 1, constant: 0))
        addConstraint(NSLayoutConstraint.init(item: progressSlide, attribute: .centerY, relatedBy: .equal, toItem: actionButton, attribute: .centerY, multiplier: 1, constant: 0))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func settingPlay() {
        actionButton.setTitle("暂停", for: .normal)
    }
    
    func settingPause() {
        actionButton.setTitle("播放", for: .normal)
    }
    
    func hideAll(_ hide: Bool) {
        if hide {
            backButton.isHidden = true
            timeLabel.isHidden = true
            progressSlide.isHidden = true
            actionButton.isHidden = true
        } else {
            backButton.isHidden = false
            timeLabel.isHidden = false
            progressSlide.isHidden = false
            actionButton.isHidden = false
        }
    }
}
