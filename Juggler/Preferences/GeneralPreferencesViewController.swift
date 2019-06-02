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
    var jiraBaseURL: URL { get }
    func generalPreferencesDidChangeWorkspaceRootURL(to url: URL)
    func generalPreferencesDidChangeJIRABaseURL(to url: URL)
}

final class GeneralPreferencesViewController: NSViewController {
    
    @IBOutlet weak var rootFolderLabel: NSTextField!
    @IBOutlet weak var jiraBaseURLTextField: NSTextField!
    
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
        jiraBaseURLTextField.stringValue = delegate?.jiraBaseURL.absoluteString ?? ""
    }
    
    @IBAction func browseButtonClicked(_ sender: Any) {
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
    
    @IBAction func jiraBaseURLChanged(_ sender: Any) {
        if let url = URL(string: jiraBaseURLTextField.stringValue) {
            delegate?.generalPreferencesDidChangeJIRABaseURL(to: url)
        }
    }
}
