//
//  PreferencesCoordinator.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 02..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Cocoa

protocol PreferencesCoordinatorDelegate: class {
    func preferencesCoordinatorDidDismiss()
}

class PreferencesCoordinator {
    private let workspaceController: WorkspaceController
    private let jiraDataProvider: JIRADataProvider
    private let terminalController: TerminalController
    
    private var preferencesWindowController: PreferencesWindowController?
    private var paneControllers: [PreferencesPane: NSViewController] = [:]
    private var activePane: PreferencesPane = .general
    
    weak var delegate: PreferencesCoordinatorDelegate?

    init(workspaceController: WorkspaceController,
         jiraDataProvider: JIRADataProvider,
         terminalController: TerminalController) {
        self.workspaceController = workspaceController
        self.jiraDataProvider = jiraDataProvider
        self.terminalController = terminalController
    }
    
    func showPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController()
            preferencesWindowController?.delegate = self
        }
        preferencesWindowController?.window?.makeKeyAndOrderFront(nil)
    }
    
    private func activatePane(_ pane: PreferencesPane) {
        guard pane != activePane else {
            return
        }
        
        preferencesWindowController?.contentViewController = paneControllers[pane]
        activePane = pane
    }
}

extension PreferencesCoordinator: PreferencesWindowDelegate {
    func preferencesWindowDidLoad() {
        let generalVC = GeneralPreferencesViewController()
        generalVC.delegate = self
        let jiraVC = JIRAPreferencesViewController()
        jiraVC.delegate = self
        
        paneControllers = [
            .general: generalVC,
            .jira: jiraVC
        ]
        
        preferencesWindowController?.contentViewController = generalVC
    }
    
    func preferencesWindowDidDismiss() {
        preferencesWindowController = nil
        delegate?.preferencesCoordinatorDidDismiss()
    }
    
    func preferencesWindowDidChangePane(to pane: PreferencesPane) {
        activatePane(pane)
    }
}

extension PreferencesCoordinator: GeneralPreferencesViewDelegate {
    var workspaceRootURL: URL {
        return workspaceController.rootFolderURL
    }
    
    var terminalAppURL: URL {
        return URL(fileURLWithPath: terminalController.appPath)
    }
    
    func generalPreferencesDidChangeWorkspaceRootURL(to url: URL) {
        workspaceController.rootFolderURL = url
    }
    
    func generalPreferencesDidChangeTerminalAppURL(to url: URL) {
        terminalController.appPath = url.path
    }
}

extension PreferencesCoordinator: JIRAPreferencesViewDelegate {
    var jiraBaseURL: URL {
        return jiraDataProvider.baseURL
    }
 
    var jiraUserName: String {
        return jiraDataProvider.userName ?? ""
    }
    
    var jiraAPIToken: String {
        return jiraDataProvider.apiToken ?? ""
    }
    
    func jiraPreferencesDidChangeBaseURL(to url: URL) {
        jiraDataProvider.baseURL = url
    }
    
    func jiraPreferencesDidChangeUserName(to userName: String) {
        jiraDataProvider.userName = userName
    }
    
    func jiraPreferencesDidChangeAPIToken(to token: String) {
        jiraDataProvider.apiToken = token
    }
    
    
}
