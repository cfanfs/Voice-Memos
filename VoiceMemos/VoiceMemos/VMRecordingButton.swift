//
//  VMRecordingButton.swift
//  VoiceMemos
//
//  Created by testadm on 2017/2/13.
//  Copyright © 2017年 Yunfan Cui. All rights reserved.
//

import UIKit

// MARK: - Basics
class VMRecordingButton: UIControl {
    var recordDurationLimit:TimeInterval = 0.0
    
    var isRecording:Bool = false {
        didSet {
            if isRecording {
                displayRecording()
                startCountDownAnimation()
            } else {
                displayIdle()
                endCountDownAnimation()
            }
        }
    }
    
    fileprivate var iconSize:CGSize = CGSize.zero
    fileprivate var progressCircleLayer:CAShapeLayer = CAShapeLayer()
    fileprivate var recordBackgroundLayer:CAShapeLayer = CAShapeLayer()
    fileprivate var recordingIconLayer:CALayer = CALayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayer()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupLayer()
    }
}

// MARK: - Layout
extension VMRecordingButton {
    fileprivate func setupLayer() {
        progressCircleLayer.fillColor = nil
        progressCircleLayer.lineWidth = 3.0
        progressCircleLayer.strokeColor = UIColor.green.cgColor
        progressCircleLayer.strokeStart = 0
        progressCircleLayer.strokeEnd = 0
        layer.addSublayer(progressCircleLayer)
        
        recordBackgroundLayer.fillColor = UIColor.lightGray.cgColor
        recordBackgroundLayer.strokeColor = nil
        layer.addSublayer(recordBackgroundLayer)
        
        let recordingIcon = #imageLiteral(resourceName: "record_icon")
        iconSize = recordingIcon.size
        recordingIconLayer.bounds = CGRect(origin: CGPoint.zero, size: recordingIcon.size)
        recordingIconLayer.contentsScale = UIScreen.main.scale
        recordingIconLayer.contents = recordingIcon.cgImage
        layer.addSublayer(recordingIconLayer)
    }
    
    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        if layer == self.layer {
            let squareBoundingRect = (frame.width > frame.height) ?
                CGRect(x: (frame.width - frame.height) / 2.0, y: 0.0, width: frame.height, height: frame.height) :
                CGRect(x: 0, y: (frame.height - frame.width) / 2.0, width: frame.width, height: frame.width)
            // progress layer
            progressCircleLayer.frame = bounds
            let progressLayerRect = squareBoundingRect.insetBy(dx: 2.0, dy: 2.0)
            var transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2.0).translatedBy(x: -(frame.height + frame.width) / 2.0, y: (frame.width - frame.height) / 2.0)
            progressCircleLayer.path = CGPath(ellipseIn: progressLayerRect, transform: &transform)
            // background layer
            recordBackgroundLayer.frame = bounds
            let backgroundLayerRect = squareBoundingRect.insetBy(dx: 10.0, dy: 10.0)
            recordBackgroundLayer.path = CGPath(ellipseIn: backgroundLayerRect, transform: nil)
            // icon
            recordingIconLayer.position = CGPoint(x: frame.width / 2.0, y: frame.height / 2.0)
        }
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: iconSize.width + 20.0, height: iconSize.height + 20.0)
    }
    
    fileprivate func displayRecording() {
        recordingIconLayer.contents = #imageLiteral(resourceName: "record_icon_recording").cgImage
        recordBackgroundLayer.fillColor = UIColor.green.cgColor
    }
    
    fileprivate func displayIdle() {
        recordingIconLayer.contents = #imageLiteral(resourceName: "record_icon").cgImage
        recordBackgroundLayer.fillColor = UIColor.lightGray.cgColor
    }
    
    fileprivate func startCountDownAnimation() {
        if recordDurationLimit > 0.0 {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = 0.0
            animation.toValue = 1.0
            animation.duration = recordDurationLimit
            progressCircleLayer.add(animation, forKey: nil)
            progressCircleLayer.isHidden = false
        }
    }
    
    fileprivate func endCountDownAnimation() {
        if recordDurationLimit > 0.0 {
            progressCircleLayer.removeAllAnimations()
            progressCircleLayer.isHidden = true
        }
    }
}
