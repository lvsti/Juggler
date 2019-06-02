//
//  PreferencesCoordinator.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 02..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Foundation

protocol PreferencesCoordinatorDelegate: class {
    func preferencesCoordinatorDidDismiss()
}

class PreferencesCoordinator {
    private let workspaceController: WorkspaceController
    private let jiraURLProvider: JIRAURLProvider
    
    private var preferencesWindowController: PreferencesWindowController?
    
    weak var delegate: PreferencesCoordinatorDelegate?

    init(workspaceController: WorkspaceController, jiraURLProvider: JIRAURLProvider) {
        self.workspaceController = workspaceController
        self.jiraURLProvider = jiraURLProvider
    }
    
    func showPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController()
            preferencesWindowController?.delegate = self
        }
        preferencesWindowController?.window?.makeKeyAndOrderFront(nil)
    }
}

extension PreferencesCoordinator: PreferencesWindowDelegate {
    func preferencesWindowDidLoad() {
        let generalVC = GeneralPreferencesViewController()
        generalVC.delegate = self
        preferencesWindowController?.contentViewController = generalVC
    }
    
    func preferencesWindowDidDismiss() {
        preferencesWindowController = nil
        delegate?.preferencesCoordinatorDidDismiss()
    }
}

extension PreferencesCoordinator: GeneralPreferencesViewDelegate {
    var workspaceRootURL: URL {
        return workspaceController.rootFolderURL
    }
    
    var jiraBaseURL: URL {
        return jiraURLProvider.baseURL
    }
    
    func generalPreferencesDidChangeJIRABaseURL(to url: URL) {
        jiraURLProvider.baseURL = url
    }
    
    func generalPreferencesDidChangeWorkspaceRootURL(to url: URL) {
        workspaceController.rootFolderURL = url
    }
}
