//
//  VMRecord.swift
//  VoiceMemos
//
//  Created by testadm on 2017/2/14.
//  Copyright © 2017年 Yunfan Cui. All rights reserved.
//

import Foundation

struct VMRecord {
    var name:String
    var fileName:String
    var createTime:Date
    
    var dictionary:[String: AnyObject] {
        return [
            "name": name as AnyObject,
            "file_name": fileName as AnyObject,
            "create_time": createTime as AnyObject
        ]
    }
    
    init(name:String, fileName:String, createTime:Date) {
        self.name = name
        self.fileName = fileName
        self.createTime = createTime
    }
    init(dictionary:[String: AnyObject]) {
        name = dictionary["name"] as? String ?? ""
        fileName = dictionary["file_name"] as? String ?? ""
        createTime = dictionary["create_time"] as? Date ?? Date()
    }
    
    /// Convinent access to record file url
    var recordFileURL:URL {
        return VMRecordDataManager.shared.recordFolderURL.appendingPathComponent(fileName)
    }
}

extension VMRecord:Equatable {
    static func == (lhs:VMRecord, rhs:VMRecord) -> Bool {
        return lhs.fileName == rhs.fileName
    }
}
