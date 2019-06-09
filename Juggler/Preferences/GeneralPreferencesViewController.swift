//
//  GeneralPreferencesViewController.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 02..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Cocoa

protocol GeneralPreferencesViewDelegate: class {
    var workspaceRootURL: URL { get }
    var terminalAppURL: URL { get }
    func generalPreferencesDidChangeWorkspaceRootURL(to url: URL)
    func generalPreferencesDidChangeTerminalAppURL(to url: URL)
}

final class GeneralPreferencesViewController: NSViewController {
    
    @IBOutlet weak var rootFolderLabel: NSTextField!
    @IBOutlet weak var terminalAppLabel: NSTextField!
    
    weak var delegate: GeneralPreferencesViewDelegate?
    
    override var nibName: NSNib.Name? {
        return "GeneralPreferencesView"
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        rootFolderLabel.stringValue = delegate?.workspaceRootURL.path ?? ""
        terminalAppLabel.stringValue = delegate?.terminalAppURL.path ?? ""
    }
    
    @IBAction private func browseRootButtonClicked(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.title = "Choose Workspace Root Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        
        panel.beginSheetModal(for: view.window!) { response in
            if response == .OK {
                self.delegate?.generalPreferencesDidChangeWorkspaceRootURL(to: panel.url!)
                self.rootFolderLabel.stringValue = panel.url!.path
            }
        }
    }

    @IBAction private func browseTerminalButtonClicked(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.title = "Select Terminal App"
        panel.canCreateDirectories = false
        panel.prompt = "Select"
        panel.allowedFileTypes = [kUTTypeApplicationBundle as String]
        
        if let appsDir = try? FileManager.default.url(for: .applicationDirectory,
                                                      in: .systemDomainMask,
                                                      appropriateFor: nil,
                                                      create: false) {
            panel.directoryURL = appsDir
        }
        
        panel.beginSheetModal(for: view.window!) { response in
            if response == .OK {
                self.delegate?.generalPreferencesDidChangeTerminalAppURL(to: panel.url!)
                self.terminalAppLabel.stringValue = panel.url!.path
            }
        }
    }

}
