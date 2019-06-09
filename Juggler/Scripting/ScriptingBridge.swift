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
    func doCloseAllXcodeProjects(except projectName: NSString)
}

extension ScriptingBridge {
    func closeAllXcodeProjects(except projectName: String) {
        doCloseAllXcodeProjects(except: projectName as NSString)
    }
}
