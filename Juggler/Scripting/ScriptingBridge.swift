//
//  ScriptingBridge.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 09..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Foundation
import AppleScriptObjC

@objc(NSObject) protocol ScriptingBridge {
    func closeAllSourcetreeWindows()
    func doCloseAllXcodeProjects(except: NSString, xcodePath: NSString)
    func doGetActiveXcodeProjectPath() -> NSString
}

extension ScriptingBridge {
    func closeAllXcodeProjects(except projectName: String, withXcodeAt path: String) {
        doCloseAllXcodeProjects(except: projectName as NSString, xcodePath: path as NSString)
    }
    
    func getActiveXcodeProjectPath() -> String? {
        let hfsPath = doGetActiveXcodeProjectPath()
        
        guard
            hfsPath.length > 0,
            let fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                        hfsPath as CFString?,
                                                        CFURLPathStyle(rawValue:1)!,
                                                        hfsPath.hasSuffix(":"))
        else {
            return nil
        }
        
        return (fileURL as URL).path
    }
    
    func requestPermissionsToAutomateXcode() -> Bool {
        if #available(OSX 10.14, *) {
            let targetAppEventDescriptor = NSAppleEventDescriptor(bundleIdentifier: "com.apple.dt.Xcode")
            let status = AEDeterminePermissionToAutomateTarget(targetAppEventDescriptor.aeDesc, typeWildCard, typeWildCard, true)
            return status == noErr
        }
        
        return true
    }
}
