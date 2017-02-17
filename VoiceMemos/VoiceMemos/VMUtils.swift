
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
    
    /// Generate random file name using UUID
    ///
    /// - Parameter ext: File extension. Empty string acceptable.
    /// - Returns: Generated file name
    class func randomFileName(withExtension ext:String) -> String {
        return [UUID().uuidString, ext].joined(separator: ".")
    }
    
    /// String formatted as hour:min:sec (e.g. 12:03:14)
    ///
    /// - Parameter timeInterval: Time interval to format
    /// - Returns: Formatted string
    class func timeString(forInterval timeInterval:TimeInterval) -> String {
        let integerInterval = UInt(max(0.0, timeInterval))
        let hours = integerInterval / 3600
        let minutes = (integerInterval % 3600) / 60
        let seconds = integerInterval % 60
        var components = [String]()
        if hours > 0 {
            components.append("\(hours)")
        }
        components.append(contentsOf: [minutes, seconds].map{String(format:"%02u", $0)})
        return components.joined(separator: ":")
    }
    
    /// Present a single button alert in target view controller
    ///
    /// - Parameters:
    ///   - viewController: Target view controller to present in
    ///   - title: Alert title
    ///   - description: Alert message
    ///   - buttonTitle: Title of button. Pass nil for "OK" as default.
    ///   - action: Action after alert dismissed
    class func presentSingleButtonAlertController(inViewController viewController:UIViewController, withTitle title:String?, description:String?, buttonTitle:String?, action:(() -> Void)?) {
        let alertController = UIAlertController(title: title, message: description, preferredStyle: .alert)
        let action = UIAlertAction(title: buttonTitle ?? NSLocalizedString("glb_ok", comment: ""), style: .cancel) { _ in
            action?()
        }
        alertController.addAction(action)
        viewController.present(alertController, animated: true, completion: nil)
    }
    
    /// Print simple custom log 
    class func log(_ string:String, file:String = #file, function:String = #function, line:Int = #line) {
        let fileName = file.components(separatedBy: "/").last ?? "Unknown File"
        print("\(Date())[VoiceMemos](\(fileName):LINE \(line))(\(function)) ".appending(string))
    }
}
