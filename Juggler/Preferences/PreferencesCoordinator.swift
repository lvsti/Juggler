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
    private let jiraDataProvider: JIRADataProvider
    
    private var preferencesWindowController: PreferencesWindowController?
    
    weak var delegate: PreferencesCoordinatorDelegate?

    init(workspaceController: WorkspaceController, jiraDataProvider: JIRADataProvider) {
        self.workspaceController = workspaceController
        self.jiraDataProvider = jiraDataProvider
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
        return jiraDataProvider.baseURL
    }
    
    func generalPreferencesDidChangeJIRABaseURL(to url: URL) {
        jiraDataProvider.baseURL = url
    }
    
    func generalPreferencesDidChangeWorkspaceRootURL(to url: URL) {
        workspaceController.rootFolderURL = url
    }
}
