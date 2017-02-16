//
//  VMRecordDataManager.swift
//  VoiceMemos
//
//  Created by testadm on 2017/2/14.
//  Copyright © 2017年 Yunfan Cui. All rights reserved.
//

import Foundation
import CoreData

final class VMRecordDataManager {
    static let shared = VMRecordDataManager()
    private var recordContents:[[String: AnyObject]] = []
    
    private var spinLock:OSSpinLock = OS_SPINLOCK_INIT
    @available(iOS 10.0, *)
    private lazy var unfairLock:os_unfair_lock = os_unfair_lock()
    
    init() {
        loadLocalRecords()
    }
    
    private var recordListFileURL:URL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents/records_list.plist")
    
    var recordFolderURL:URL {
        return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents/Record")
    }
    
    var temporaryRecordURL:URL {
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("vm_temporary_audio")
    }
    
    private func loadLocalRecords() {
        if let content = NSArray(contentsOf: recordListFileURL) as? [[String: AnyObject]] {
            recordContents = content
        }
    }
    
    private func synchronize() -> Bool {
        let result = (recordContents as NSArray).write(to: recordListFileURL, atomically: true)
        if !result {
            VMUtils.log("Can not synchronize record list file.")
        }
        return result
    }
    
    private func lock() {
        if #available(iOS 10.0, *) {
            os_unfair_lock_lock(&unfairLock)
        } else {
            OSSpinLockLock(&spinLock)
        }
    }
    
    private func unlock() {
        if #available(iOS 10.0, *) {
            os_unfair_lock_unlock(&unfairLock)
        } else {
            OSSpinLockUnlock(&spinLock)
        }
    }
    
    private func sync(closure:(() throws -> ())) rethrows {
        lock()
        do {
            try closure()
        } catch {
            unlock()
            throw error
        }
        unlock()
    }
    
    // Interfaces
    
    var records:[VMRecord] {
        var output:[VMRecord] = []
        sync {
            output = recordContents.reversed().map{VMRecord(dictionary:$0)}
        }
        return output
    }
    
    func createRecord(fileURL:URL? = nil, name:String, fileExtension:String) throws -> VMRecord? {
        if name.characters.count == 0 {
            throw NSError.VMRecordDataManagerInvalidRecordName
        }
        
        let sourceURL = fileURL ?? temporaryRecordURL
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: sourceURL.path) {
            VMUtils.log("Record source file not exist")
            throw NSError.VMRecordDataManagerUnableToSaveNewRecord
        }
        
        let targetFolderURL = recordFolderURL
        var isDirectory:ObjCBool = false
        if !fileManager.fileExists(atPath: targetFolderURL.path, isDirectory: &isDirectory) {
            do {
                try fileManager.createDirectory(at: targetFolderURL, withIntermediateDirectories: false, attributes: nil)
            } catch {
                VMUtils.log("Unable to create records directory :\n\(error)")
                throw error
            }
        } else if !isDirectory.boolValue {
            VMUtils.log("~/Documents/Records is not a directory.")
            throw NSError.VMRecordDataManagerUnableToSaveNewRecord
        }
        
        var fileName:String = VMUtils.randomFileName(withExtension: fileExtension)
        var targetURL = targetFolderURL.appendingPathComponent(fileName)
        while fileManager.fileExists(atPath: targetURL.path) {
            fileName = VMUtils.randomFileName(withExtension: fileExtension)
            targetURL = targetFolderURL.appendingPathComponent(fileName)
        }
        
        let record = VMRecord(name:name, fileName:fileName, createTime:Date())
        do {
            try sync {
                do {
                    try fileManager.moveItem(at: sourceURL, to: targetURL)
                } catch {
                    VMUtils.log("Move failed:\n\(error)")
                    throw NSError.VMRecordDataManagerUnableToSaveNewRecord
                }
                recordContents.append(record.dictionary)
                if !synchronize() {
                    recordContents.removeLast()
                    VMUtils.log("Uable to write back record list file.")
                    throw NSError.VMRecordDataManagerUnableToSaveNewRecord
                }
            }
        } catch {
            throw error
        }
        
        return record
    }
    
    func removeRecord(record:VMRecord) -> Bool {
        do {
            try sync {
                guard let indexToRemove = (recordContents.index { VMRecord(dictionary: $0) == record }) else {
                    VMUtils.log("Try to remove non-existing record.")
                    abort()
                }
                do {
                    try FileManager.default.removeItem(at: record.recordFileURL)
                } catch {
                    // trash item at recordFileURL might be a solution
                }
                recordContents.remove(at:indexToRemove)
                if !synchronize() {
                    recordContents.insert(record.dictionary, at: indexToRemove)
                    throw NSError.VMRecordDataManagerRemovingRecordFailed
                }
            }
        } catch {
            return false
        }
        return true
    }
    
    func removeTemporaryRecord() {
        sync {
            let fileManager = FileManager.default
            do {
                try fileManager.removeItem(at: temporaryRecordURL)
            } catch {
                VMUtils.log("Remove temporary record failed:\n\(error)")
            }
        }
    }
}

// MARK: - Errors
let VMRecordDataManagerErrorDomain = "VMRecordDataManagerErrorDomain"

let VMRecordDataMangerInvalidRecordNameErrorCode = -1
let VMRecordDataManagerUnableToSaveNewRecordErrorCode = -2
let VMRecordDataManagerRemovingRecordFailedErrorCode = -3

extension NSError {
    static let VMRecordDataManagerInvalidRecordName =
        NSError(domain: VMRecordDataManagerErrorDomain,
                code: VMRecordDataMangerInvalidRecordNameErrorCode,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("vmrdm_invalid_record_name", comment: "")])
    
    static let VMRecordDataManagerUnableToSaveNewRecord =
        NSError(domain:VMRecordDataManagerErrorDomain ,
                code: VMRecordDataManagerUnableToSaveNewRecordErrorCode,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("vmrdm_saving_record_failed", comment: "")])
    
    static let VMRecordDataManagerRemovingRecordFailed =
        NSError(domain: VMRecordDataManagerErrorDomain,
                code: VMRecordDataManagerRemovingRecordFailedErrorCode,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("vmrdm_removing_record_failed", comment: "")])
}
