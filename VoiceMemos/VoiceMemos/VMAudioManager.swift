//
//  VMAudioManager.swift
//  VoiceMemos
//
//  Created by testadm on 2017/2/14.
//  Copyright © 2017年 Yunfan Cui. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

// MARK: - Definitions & Interfaces
final class VMAudioManager:NSObject {
    static let shared:VMAudioManager = VMAudioManager()
    static let minimumRecordDutation:TimeInterval = 1.0
    private(set) var maximumRecordDuration:TimeInterval = 0.0
    
    private(set) var playingURL:URL?
    fileprivate var player:AVAudioPlayer?
    
    private(set) var recordingTargetURL:URL?
    fileprivate var recorder:AVAudioRecorder?
    
    enum State {
        case playing
        case recording
        case idle
    }
    fileprivate(set) var state:State = .idle {
        didSet {
            if oldValue == .playing {
                NotificationCenter.default.post(
                    name: Notification.Name.VMAudioManagerDidEndPlaying,
                    object: nil,
                    userInfo: nil)
            }
        }
    }
    
    override init() {
        super.init()
        // If 
        if let configurationMaximumLength = Bundle(for: type(of:self)).object(forInfoDictionaryKey: "VMRecordMaximumLength") as? TimeInterval {
            maximumRecordDuration = configurationMaximumLength
        }
        
        if AVAudioSession.sharedInstance().recordPermission() == .granted {
            resetAudioSession()
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioSessionInteruptionEvent(noti:)),
            name: .AVAudioSessionInterruption,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioSessionRouteChanged(noti:)),
            name: .AVAudioSessionRouteChange,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillBecomeInactive(noti:)),
            name: .UIApplicationWillResignActive,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive(noti:)),
            name: .UIApplicationDidBecomeActive,
            object: nil)
    }
    
    fileprivate func resetAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord, with: .defaultToSpeaker)
        } catch {
            VMUtils.log("Reset Audio Session Failed:\n\(error)")
        }
    }
    
    // Microphone Access
    
    func microphonePermission() -> AVAudioSessionRecordPermission {
        return AVAudioSession.sharedInstance().recordPermission()
    }
    
    func requestMicrophonePermission(completion:@escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { (granted:Bool) in
            if granted {
                self.resetAudioSession()
            }
            completion(granted)
        }
    }
    
    // Play / Record Control
    
    func play(url:URL) throws -> Bool {
        // prepare audiosession
        playingURL = url
        do {
            try prepareAndPlay()
        } catch {
            throw error
        }
        return true
    }
    
    func stopPlaying() {
        if state == .playing {
            player?.stop()
            resetState()
        }
    }
    
    func startRecording(url:URL, format:AudioFormat) throws -> Bool {
        recordingTargetURL = url
        do {
            try prepareAndRecord(format: format)
        } catch {
            throw error
        }
        return true
    }
    
    func stopRecording() {
        if state == .recording {
            recorder?.stop()
        }
    }
}

// MARK: - Recording Format Support
extension VMAudioManager {
    enum AudioFormat {
        case lossless
        case mpeg4acc
        case mp3
        
        var fileExtension:String {
            switch self {
            case .mpeg4acc:
                return "m4a"
            case .mp3:
                return "mp3"
            case .lossless:
                return "alac"
            }
        }
        
        fileprivate var formatID:AudioFormatID {
            switch self {
            case .mpeg4acc:
                return kAudioFormatMPEG4AAC
            case .mp3:
                return kAudioFormatMPEGLayer3
            case .lossless:
                return kAudioFormatAppleLossless
            }
        }
    }
}

// MARK: - Play/Record Methods Internal
fileprivate extension VMAudioManager {
    func prepareAndPlay() throws {
        guard let url = playingURL else {
            throw NSError.VMAudioManagerEmptyURL
        }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            if player?.url != url {
                try player = AVAudioPlayer(contentsOf: url)
                player?.delegate = self
            }
            if player?.play() == false {
                throw NSError.VMAudioManagerPlayerUnableToPlay
            }
            
            state = .playing
            NotificationCenter.default.post(
                name: Notification.Name.VMAudioManagerDidStartPlaying,
                object: nil,
                userInfo: nil)
        } catch {
            throw error
        }
    }
    
    func prepareAndRecord(format:AudioFormat) throws {
        guard let url = recordingTargetURL else {
            throw NSError.VMAudioManagerEmptyURL
        }
        
        do {
            let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 16000.0, channels: 1)
            var description = audioFormat.streamDescription.pointee
            description.mFormatID = format.formatID
            let finalFormat = AVAudioFormat(streamDescription: &description)
            
            if #available(iOS 10.0, *) {
                try recorder = AVAudioRecorder(url: url, format: finalFormat)
            } else {
                try recorder = AVAudioRecorder(url: url, settings: finalFormat.settings)
            }
            recorder?.delegate = self
            if recorder?.prepareToRecord() == false {
                throw NSError.VMAudioManagerRecorderUnableToRecord
            }
            try AVAudioSession.sharedInstance().setActive(true)
            if recorder?.record(forDuration: maximumRecordDuration) == false {
                throw NSError.VMAudioManagerRecorderUnableToRecord
            }
            state = .recording
        } catch {
            throw error
        }
    }
    
    func resetState() {
        if state != .idle {
            do {
                try AVAudioSession.sharedInstance().setActive(false, with: .notifyOthersOnDeactivation)
            } catch {
                VMUtils.log("Deactiving audio session failed:\n\(error)")
            }
            state = .idle
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension VMAudioManager:AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        resetState()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        resetState()
    }
}

// MARK: - AVAudioRecorderDelegate
extension VMAudioManager:AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        resetState()
        // Calculate duration
        // .duration of AVAsset / AVPlayerItem always return 0.0 or nan.
        // This calculation process takes about 0.2-0.25 seconds
        let temporaryPlayer = try? AVAudioPlayer(contentsOf: recorder.url)
        temporaryPlayer?.prepareToPlay()
        let duration = temporaryPlayer?.duration ?? 0.0
        
        if duration < type(of:self).minimumRecordDutation {
            postRecordingFailedNotification(withError: NSError.VMAudioManagerRecordTooShort)
        } else if flag {
            NotificationCenter.default.post(
                name: .VMAudioManagerDidFinishRecording,
                object: nil,
                userInfo: nil)
        } else {
            postRecordingFailedNotification(withError: NSError.VMAudioManagerRecordingFailedUnknown)
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        resetState()
        postRecordingFailedNotification(withError: error)
    }
    
    private func postRecordingFailedNotification(withError error: Error?) {
        NotificationCenter.default.post(
            name: .VMAudioManagerRecordingFailed,
            object: nil,
            userInfo: ["error" : error as Any])
    }
}

// MARK: - Observing Notifications
extension VMAudioManager {
    // AVAudioSessionInterruption
    func audioSessionInteruptionEvent(noti:Notification) {
        let interuptionType = (noti.userInfo.flatMap{$0[AVAudioSessionInterruptionTypeKey] as? UInt})
        if interuptionType == AVAudioSessionInterruptionType.began.rawValue {
            hangUpCurrentWork()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                self.endCurrentWork()
                self.resetAudioSession()
            })
        }
    }
    // AVAudioSessionRouteChange
    func audioSessionRouteChanged(noti:Notification) {
        let currentRouteDescription = AVAudioSession.sharedInstance().currentRoute
        VMUtils.log("Route changed to: [inputs:\(currentRouteDescription.inputs.map{$0.portName}), output:\(currentRouteDescription.outputs.map{$0.portName})]")
    }
    
    func applicationWillBecomeInactive(noti:Notification) {
        hangUpCurrentWork()
    }
    
    func applicationDidBecomeActive(noti:Notification) {
        endCurrentWork()
        resetAudioSession()
    }
    
    private func hangUpCurrentWork() {
        if state == .playing {
            player?.pause()
        } else if state == .recording {
            recorder?.pause()
        }
    }
    
    private func endCurrentWork() {
        if state == .playing {
            self.stopPlaying()
        } else if state == .recording {
            self.stopRecording()
        }
    }
}

// MARK: - Post Notifications
extension Notification.Name {
    static let VMAudioManagerDidFinishRecording = Notification.Name("VMAudioManagerDidFinishRecording")
    static let VMAudioManagerRecordingFailed = Notification.Name("VMAudioManagerRecordingFailed")
    
    static let VMAudioManagerDidEndPlaying = Notification.Name("VMAudioManagerDidEndPlaying")
    static let VMAudioManagerDidStartPlaying = Notification.Name("VMAudioManagerDidStartPlaying")
}

// MARK: - Errors

let VMAudioManagerErrorDomain = "VMAudioManagerError"

let VMAudioManagerEmptyURLErrorCode = -1
let VMAudioManagerPlayerUnableToPlayErrorCode = -2
let VMAudioManagerRecorderUnableToRecordErrorCode = -3
let VMAudioManagerRecordTooShortErrorCode = -4

let VMAudioManagerRecordingFailedUnknownErrorCode = -100

extension NSError {
    static let VMAudioManagerEmptyURL =
        NSError(domain: VMAudioManagerErrorDomain,
                code: VMAudioManagerEmptyURLErrorCode,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("vmam_empty_url", comment: "")])
    
    static let VMAudioManagerPlayerUnableToPlay =
        NSError(domain: VMAudioManagerErrorDomain,
                code: VMAudioManagerPlayerUnableToPlayErrorCode,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("vmam_player_failed", comment: "")])
    
    static let VMAudioManagerRecorderUnableToRecord =
        NSError(domain: VMAudioManagerErrorDomain,
                code: VMAudioManagerRecorderUnableToRecordErrorCode,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("vmam_record_failed", comment: "")])
    
    static let VMAudioManagerRecordTooShort =
        NSError(domain: VMAudioManagerErrorDomain,
                code: VMAudioManagerRecordTooShortErrorCode,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("vmam_short_record", comment: "")])
    
    static let VMAudioManagerRecordingFailedUnknown =
        NSError(domain: VMAudioManagerErrorDomain,
                code: VMAudioManagerRecordingFailedUnknownErrorCode,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("vmam_record_failed", comment: "")])
}

// MARK: - VMRecord Related Interfaces
extension VMAudioManager {
    func playRecord(record:VMRecord) throws -> Bool {
        do {
            try _ = play(url: record.recordFileURL)
        } catch {
            throw error
        }
        return true
    }
    
    func isPlayingRecord(record:VMRecord) -> Bool {
        if state == .playing, let url = playingURL {
            return url == record.recordFileURL
        }
        return false
    }
}
