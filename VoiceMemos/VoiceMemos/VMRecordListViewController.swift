//
//  VMRecordListViewController.swift
//  VoiceMemos
//
//  Created by testadm on 2017/2/14.
//  Copyright © 2017年 Yunfan Cui. All rights reserved.
//

import UIKit
import CoreData

class VMRecordListViewController: UIViewController {
    @IBOutlet weak var tableView:UITableView!
    fileprivate var records:[VMRecord] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        records = VMRecordDataManager.shared.records
    }
    
    /// Show errors occured while playing in an alert
    fileprivate func showError(error:Error) {
        let alertController = UIAlertController(title: nil, message: error.localizedDescription, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func doneAction(_ sender:UIBarButtonItem) {
        VMAudioManager.shared.stopPlaying()
        dismiss(animated: true, completion: nil)
    }
}

extension VMRecordListViewController:UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return records.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RecordListCell", for: indexPath)
        if let recordCell = cell as? VMRecordCell {
            recordCell.config(withRecord: records[indexPath.row])
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            removeItemAt(indexPath: indexPath)
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if VMAudioManager.shared.isPlayingRecord(record: records[indexPath.row]) {
            VMAudioManager.shared.stopPlaying()
        }
    }
    
    private func removeItemAt(indexPath:IndexPath) {
        if VMAudioManager.shared.isPlayingRecord(record: records[indexPath.row]) {
            VMAudioManager.shared.stopPlaying()
        }
        
        let alertController = UIAlertController(
            title: NSLocalizedString("glb_delete", comment: ""),
            message: NSLocalizedString("glb_confirm_to_delete", comment: ""),
            preferredStyle: .alert)
        let deleteAction = UIAlertAction(
            title: NSLocalizedString("glb_delete", comment: ""),
            style: .destructive) { [weak self] _ in
                if let strongSelf = self {
                    if VMRecordDataManager.shared.removeRecord(record: strongSelf.records[indexPath.row]) {
                        strongSelf.records.remove(at: indexPath.row)
                        strongSelf.tableView.deleteRows(at: [indexPath], with: .automatic)
                    } else {
                        VMUtils.presentSingleButtonAlertController(
                            inViewController: strongSelf,
                            withTitle: NSLocalizedString("glb_error", comment: ""),
                            description: NSLocalizedString("vmrdm_removing_record_failed", comment: ""),
                            buttonTitle: nil,
                            action: nil)
                    }
                }
        }
        alertController.addAction(deleteAction)
        let cancelAction = UIAlertAction(
            title: NSLocalizedString("glb_cancel", comment: ""),
            style: .cancel) { [weak self] _ in
                self?.tableView.setEditing(false, animated: true)
        }
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
}
// MARK: - VMRecordCell
class VMRecordCell:UITableViewCell {
    @IBOutlet weak var nameLabel:UILabel!
    @IBOutlet weak var timeLabel:UILabel!
    @IBOutlet weak var playStopButton:UIButton!
    weak var containerViewController:VMRecordListViewController?
    
    private var isPlaying = true {
        didSet {
            if isPlaying {
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(playingStatusChanged(noti:)),
                    name: .VMAudioManagerDidEndPlaying,
                    object: nil)
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(playingStatusChanged(noti:)),
                    name: .VMAudioManagerDidStartPlaying,
                    object: nil)
                playStopButton.setImage(#imageLiteral(resourceName: "button_stop"), for: .normal)
            } else {
                playStopButton.setImage(#imageLiteral(resourceName: "button_play"), for: .normal)
            }
        }
    }
    private var recordReference:VMRecord?
    
    /// Self configuraton for VMRecord
    fileprivate func config(withRecord record:VMRecord) {
        recordReference = record
        nameLabel.text = record.name
        timeLabel.text = DateFormatter.localizedString(from: record.createTime, dateStyle: .medium, timeStyle: .medium)
        isPlaying = VMAudioManager.shared.isPlayingRecord(record: record)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        NotificationCenter.default.removeObserver(self)
        containerViewController = nil
        recordReference = nil
        isPlaying = false
    }
    /// Play/Stop button action
    @IBAction func playStopAction(_ sender:UIButton) {
        if isEditing {
            return
        }
        if isPlaying {
            VMAudioManager.shared.stopPlaying()
        } else {
            guard let record = recordReference else {
                return
            }
            
            do {
                try isPlaying = VMAudioManager.shared.playRecord(record: record)
            } catch {
                containerViewController?.showError(error: error)
            }
        }
    }
    // VMAudioManagerDidStartPlaying / VMAudioManagerDidEndPlaying
    @objc private func playingStatusChanged(noti:Notification) {
        OperationQueue.main.addOperation {
            if let record = self.recordReference {
                self.isPlaying = VMAudioManager.shared.isPlayingRecord(record: record)
            }
        }
    }
}
