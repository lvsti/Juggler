//
//  PreferencesWindowController.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 02..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Cocoa

protocol PreferencesWindowDelegate: class {
    func preferencesWindowDidLoad()
    func preferencesWindowDidDismiss()
}

final class PreferencesWindowController: NSWindowController, NSWindowDelegate {

    weak var delegate: PreferencesWindowDelegate?
    
    override var windowNibName: NSNib.Name? {
        return "PreferencesWindow"
    }
    
    init() {
        super.init(window: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        delegate?.preferencesWindowDidLoad()
        window?.delegate = self
    }
    
    func windowWillClose(_ notification: Notification) {
        delegate?.preferencesWindowDidDismiss()
    }
}
