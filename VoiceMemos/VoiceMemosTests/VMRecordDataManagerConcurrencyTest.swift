//
//  VMRecordDataManagerConcurrencyTest.swift
//  VoiceMemos
//
//  Created by testadm on 2017/2/17.
//  Copyright © 2017年 Yunfan Cui. All rights reserved.
//

import XCTest
import Foundation
@testable import VoiceMemos

class VMRecordDataManagerConcurrencyTest: XCTestCase {
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testConcurrencyReadWrite() {
        for threadIndex in 0..<10 {
            let thread = Thread {
                for taskIndex in 0..<50 {
                    let index = threadIndex * 50 + taskIndex
                    let dataManager = VMRecordDataManager.shared
                    let url = dataManager.temporaryRecordURL
                    let name = "\(index)"
                    try? name.write(to: url, atomically: true, encoding: .utf8)
                    if let _ = try? dataManager.createRecord(sourceURL: url, name: name, fileExtension: "test") {
                        
                    }
                }
            }
            thread.name = "Writing thread \(threadIndex)"
            thread.start()
        }
        
        for threadIndex in 0..<10 {
            let expect = expectation(description: "Thread \(threadIndex)")
            let thread = Thread {
                for taskIndex in 0..<100 {
                    let recordsCopy = VMRecordDataManager.shared.records
                    if recordsCopy.count > 0 {
                        let index = Int(arc4random()) % recordsCopy.count
                        let record = recordsCopy[index]
                        let content = try? String(contentsOf: record.recordFileURL)
                        if content != record.name {
                            XCTFail("Record is not correct!")
                        } else {
                            print("Reading test \(threadIndex) - \(taskIndex) passed")
                        }
                    }
                }
                expect.fulfill()
            }
            thread.qualityOfService = .background
            thread.name = "Reading thread \(threadIndex)"
            thread.start()
        }
        
        waitForExpectations(timeout: 200.0, handler: nil)
    }
}

