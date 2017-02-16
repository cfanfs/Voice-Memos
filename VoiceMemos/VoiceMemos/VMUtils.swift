
//
//  VMUtils.swift
//  VoiceMemos
//
//  Created by testadm on 2017/2/15.
//  Copyright © 2017年 Yunfan Cui. All rights reserved.
//

import Foundation
import UIKit

class VMUtils {
    class func randomFileName(withExtension ext:String) -> String {
        return [UUID().uuidString, ext].joined(separator: ".")
    }
    
    class func presentSingleButtonAlertController(inViewController viewController:UIViewController, withTitle title:String?, description:String?, buttonTitle:String?, action:(() -> Void)?) {
        let alertController = UIAlertController(title: title, message: description, preferredStyle: .alert)
        let action = UIAlertAction(title: buttonTitle ?? "OK", style: .cancel) { _ in
            action?()
        }
        alertController.addAction(action)
        viewController.present(alertController, animated: true, completion: nil)
    }
    
    class func log(_ string:String, file:String = #file, function:String = #function, line:Int = #line) {
        let fileName = file.components(separatedBy: "/").last ?? "Unknown File"
        print("\(Date())[VoiceMemos](\(fileName):LINE \(line))(\(function)) ".appending(string))
    }
}
