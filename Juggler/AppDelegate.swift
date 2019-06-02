//
//  AppDelegate.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 01..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var menuController: MenuController!
    private var preferencesCoordinator: PreferencesCoordinator?
    
    private let workspaceController: WorkspaceController
    private let gitController: GitController
    private let jiraURLProvider: JIRAURLProvider
    private let gitHubURLProvider: GitHubURLProvider
    
    override init() {
        gitController = GitController(gitURL: URL(fileURLWithPath: "/usr/bin/git"),
                                      fileManager: FileManager.default)
        jiraURLProvider = JIRAURLProvider(userDefaults: UserDefaults.standard)
        gitHubURLProvider = GitHubURLProvider()
        workspaceController = WorkspaceController(fileManager: FileManager.default,
                                                  gitController: gitController,
                                                  userDefaults: UserDefaults.standard,
                                                  jiraURLProvider: jiraURLProvider,
                                                  gitHubURLProvider: gitHubURLProvider)
        workspaceController.reload()
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        
//        statusItem.image = #imageLiteral(resourceName: "statusicon")
//        statusItem.image?.isTemplate = true
        statusItem.button!.title = "JG"
        statusItem.menu = NSMenu(title: statusItem.button!.title)
        
        NSMenu.setMenuBarVisible(false)
        
        menuController = MenuController(menu: statusItem.menu!,
                                        workspaceController: workspaceController,
                                        jiraURLProvider: jiraURLProvider)
        menuController.delegate = self
    }
    
}

extension AppDelegate: MenuControllerDelegate {
    func menuControllerDidInvokeSetup(for workspace: Workspace) {
        
    }
    
    func menuControllerDidInvokePreferences() {
        if preferencesCoordinator == nil {
            preferencesCoordinator = PreferencesCoordinator(workspaceController: workspaceController,
                                                            jiraURLProvider: jiraURLProvider)
            preferencesCoordinator?.delegate = self
        }
        preferencesCoordinator?.showPreferences()
    }
}

extension AppDelegate: PreferencesCoordinatorDelegate {
    func preferencesCoordinatorDidDismiss() {
        preferencesCoordinator = nil
    }
}

