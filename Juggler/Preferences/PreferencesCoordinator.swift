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
    private let gitHubDataProvider: GitHubDataProvider
    private let terminalController: TerminalController
    private let xcodeController: XcodeController
    
    private var preferencesWindowController: PreferencesWindowController?
    private var paneControllers: [PreferencesPane: NSViewController] = [:]
    private var activePane: PreferencesPane = .general
    
    weak var delegate: PreferencesCoordinatorDelegate?

    init(workspaceController: WorkspaceController,
         jiraDataProvider: JIRADataProvider,
         gitHubDataProvider: GitHubDataProvider,
         terminalController: TerminalController,
         xcodeController: XcodeController) {
        self.workspaceController = workspaceController
        self.jiraDataProvider = jiraDataProvider
        self.gitHubDataProvider = gitHubDataProvider
        self.terminalController = terminalController
        self.xcodeController = xcodeController
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
        let gitHubVC = GitHubPreferencesViewController()
        gitHubVC.delegate = self

        paneControllers = [
            .general: generalVC,
            .jira: jiraVC,
            .gitHub: gitHubVC
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
    
    var xcodeURL: URL {
        return URL(fileURLWithPath: xcodeController.appPath)
    }
    
    func generalPreferencesDidChangeWorkspaceRootURL(to url: URL) {
        workspaceController.rootFolderURL = url
    }
    
    func generalPreferencesDidChangeTerminalAppURL(to url: URL) {
        terminalController.appPath = url.path
    }

    func generalPreferencesDidChangeXcodeURL(to url: URL) {
        xcodeController.appPath = url.path
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

extension PreferencesCoordinator: GitHubPreferencesViewDelegate {
    var gitHubAPIToken: String {
        return gitHubDataProvider.apiToken ?? ""
    }
    
    var gitHubTicketIDPattern: String {
        return gitHubDataProvider.ticketIDFromPRTitlePattern ?? ""
    }
    
    var gitHubNewPRTitlePattern: String {
        return gitHubDataProvider.newPRTitlePattern ?? ""
    }

    var gitHubNewPRBranchName: String {
        return gitHubDataProvider.integrationBranch.name
    }

    func gitHubPreferencesDidChangeAPIToken(to token: String) {
        gitHubDataProvider.apiToken = token
    }

    func gitHubPreferencesDidChangeTicketIDPattern(to pattern: String) {
        gitHubDataProvider.ticketIDFromPRTitlePattern = pattern.isEmpty ? nil : pattern
    }
    
    func gitHubPreferencesDidChangeNewPRTitlePattern(to pattern: String) {
        gitHubDataProvider.newPRTitlePattern = pattern.isEmpty ? nil : pattern
    }

    func gitHubPreferencesDidChangeNewPRBranch(to branchName: String) {
        guard !branchName.isEmpty else {
            return
        }
        gitHubDataProvider.integrationBranch = Git.Branch(name: branchName)
    }

}
