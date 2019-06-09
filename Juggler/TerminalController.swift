//
//  Terminal.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 09..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Cocoa

final class TerminalController {
    private static let terminalAppPathKey = "TerminalAppPath"
    
    private let userDefaults: UserDefaults
    
    var appPath: String {
        get {
            return userDefaults.string(forKey: TerminalController.terminalAppPathKey) ?? "/Applications/Utilities/Terminal.app"
        }
        set {
            userDefaults.set(newValue, forKey: TerminalController.terminalAppPathKey)
        }
    }
    
    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }
    
    func open(at url: URL) {
        NSWorkspace.shared.openFile(url.path, withApplication: appPath)
    }
}
