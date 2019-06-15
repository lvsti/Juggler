//
//  XcodeController.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 15..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Cocoa

final class XcodeController {
    private static let xcodeAppPathKey = "XcodeAppPath"
    
    private let scriptingBridge: ScriptingBridge
    private let userDefaults: UserDefaults
    
    var appPath: String {
        get {
            return userDefaults.string(forKey: XcodeController.xcodeAppPathKey) ?? "/Applications/Xcode.app"
        }
        set {
            userDefaults.set(newValue, forKey: XcodeController.xcodeAppPathKey)
        }
    }
    
    init(scriptingBridge: ScriptingBridge, userDefaults: UserDefaults) {
        self.scriptingBridge = scriptingBridge
        self.userDefaults = userDefaults
    }
    
    func focusOnProject(at projectURL: URL) {
        if scriptingBridge.requestPermissionsToAutomateXcode() {
            scriptingBridge.closeAllXcodeProjects(except: projectURL.path, withXcodeAt: appPath)
        }
        
        NSWorkspace.shared.openFile(projectURL.path, withApplication: appPath)
    }
}
