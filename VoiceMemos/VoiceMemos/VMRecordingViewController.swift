//
//  VMRecordingViewController.swift
//  VoiceMemos
//
//  Created by testadm on 2017/2/14.
//  Copyright © 2017年 Yunfan Cui. All rights reserved.
//

import UIKit
import AVFoundation

// MARK: - Basics
class VMRecordingViewController: UIViewController {
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var recordingButton: VMRecordingButton!
    
    fileprivate let audioFormat = VMAudioManager.AudioFormat.mpeg4acc
    fileprivate var recordTimer:Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resetMessage()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(recordingFinished(noti:)),
            name: NSNotification.Name.VMAudioManagerDidFinishRecording,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(recordingFailed(noti:)),
            name: .VMAudioManagerRecordingFailed,
            object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        endTimer()
    }
}

// MARK: - Recording Control
extension VMRecordingViewController {
    @IBAction func startRecordingAction(sender:VMRecordingButton) {
        resetMessage()
        let permission = VMAudioManager.shared.microphonePermission()
        switch permission {
        case AVAudioSessionRecordPermission.undetermined:
            VMAudioManager.shared.requestMicrophonePermission{ [weak self] granted in
                if !granted {
                    self?.showPermissionDeniedAlert()
                }
            }
        case AVAudioSessionRecordPermission.denied:
            showPermissionDeniedAlert()
        case AVAudioSessionRecordPermission.granted:
            startRecording()
        default:
            break
        }
    }
    
    @IBAction func endRecordingAction(sender:VMRecordingButton) {
        VMAudioManager.shared.stopRecording()
    }
    
    private func startRecording() {
        do {
            let result = try VMAudioManager.shared.startRecording(url: VMRecordDataManager.shared.temporaryRecordURL, format: audioFormat)
            recordingButton.recordDurationLimit = VMAudioManager.shared.maximumRecordDuration
            recordingButton.isRecording = result
            timeLabel.isHidden = false
            startTimer()
        } catch {
            showErrorMessage(message: error.localizedDescription)
        }
    }
    
    fileprivate func endRecording() {
        recordingButton.isRecording = false
        timeLabel.isHidden = true
        endTimer()
    }
    
    private func startTimer() {
        if recordTimer == nil {
            recordTimer = Timer.scheduledTimer(
                timeInterval: 0.2,
                target: self,
                selector: #selector(updateRecordingTime(_:)),
                userInfo: nil,
                repeats: true)
        }
    }
    
    fileprivate func endTimer() {
        recordTimer?.invalidate()
        recordTimer = nil
    }
    
    @objc private func updateRecordingTime(_ timer:Timer) {
        let currentTime = VMAudioManager.shared.currentTimeOfRecorder
        let maxDuration = VMAudioManager.shared.maximumRecordDuration
        
        if maxDuration > 0.0 {
            recordingButton.progress = CGFloat(currentTime / maxDuration)
            timeLabel.text = VMUtils.timeString(forInterval: maxDuration - currentTime)
        } else {
            timeLabel.text = VMUtils.timeString(forInterval: currentTime)
        }
    }
    
    fileprivate func getRecordName() {
        let alertController = UIAlertController(
            title: NSLocalizedString("glb_save_record", comment: ""),
            message: NSLocalizedString("glb_save_hint", comment: ""),
            preferredStyle: .alert)
        alertController.addTextField { (textField:UITextField) in
            textField.returnKeyType = .done
            textField.enablesReturnKeyAutomatically = true
        }
        let textField:UITextField! = alertController.textFields?.first!
        
        let deleteAction = UIAlertAction(
            title: NSLocalizedString("glb_delete", comment: ""),
            style: .destructive) { _ in
                VMRecordDataManager.shared.removeTemporaryRecord()
        }
        alertController.addAction(deleteAction)
        
        let createAction = UIAlertAction(
            title: NSLocalizedString("glb_save", comment: ""),
            style: .default) {[weak self] _ in
                self?.createNewRecord(textField)
        }
        alertController.addAction(createAction)
        alertController.preferredAction = createAction
        present(alertController, animated: true, completion: nil)
    }
    
    private func createNewRecord(_ sender:UITextField) {
        if let name = sender.text {
            do {
                let _ = try VMRecordDataManager.shared.createRecord(name: name, fileExtension: audioFormat.fileExtension)
            } catch {
                switch error as NSError {
                case NSError.VMRecordDataManagerInvalidRecordName:
                    VMUtils.presentSingleButtonAlertController(
                        inViewController: self,
                        withTitle: NSLocalizedString("glb_err", comment: ""),
                        description: error.localizedDescription,
                        buttonTitle: nil) {
                            self.getRecordName()
                    }
                default:
                    self.showErrorMessage(message: error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Messages
extension VMRecordingViewController {
    fileprivate func showPermissionDeniedAlert() {
        let alertController = UIAlertController(
            title: NSLocalizedString("glb_permission_denied", comment: ""),
            message: NSLocalizedString("glb_request_mic_access", comment: ""),
            preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("glb_cancel", comment: ""),
                                         style: .cancel,
                                         handler: nil)
        alertController.addAction(cancelAction)
        
        let setAction = UIAlertAction(title: NSLocalizedString("glb_setting", comment: ""),
                                      style: .default) { _ in
            UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
        }
        alertController.addAction(setAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    fileprivate func resetMessage() {
        messageLabel.text = NSLocalizedString("glb_hold_to_record", comment: "")
        messageLabel.textColor = UIColor.black
    }
    
    fileprivate func showErrorMessage(message:String) {
        messageLabel.text = message
        messageLabel.textColor = UIColor.red
        messageLabel.isHidden = false
    }
    
    fileprivate func showSuccessMessage(message:String) {
        messageLabel.text = message
        messageLabel.textColor = UIColor.green
        messageLabel.isHidden = false
    }
    
    
}

// MARK: - Notifications
extension VMRecordingViewController {
    func recordingFinished(noti:Notification) {
        OperationQueue.main.addOperation {
            self.getRecordName()
            self.endRecording()
        }
    }
    
    func recordingFailed(noti:Notification) {
        OperationQueue.main.addOperation {
            let errorMessage = noti.userInfo.flatMap { $0["error"] as? NSError }.map { $0.localizedDescription }
            self.showErrorMessage(message: errorMessage ?? NSLocalizedString("glb_unknown_err", comment: ""))
            self.endRecording()
        }
    }
}
