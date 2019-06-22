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

    private var scriptingBridge: ScriptingBridge
    private let workspaceController: WorkspaceController
    private let gitController: GitController
    private let jiraDataProvider: JIRADataProvider
    private let gitHubDataProvider: GitHubDataProvider
    private let terminalController: TerminalController
    private let xcodeController: XcodeController
    private let keychainManager: KeychainManager
    
    override init() {
        Bundle.main.loadAppleScriptObjectiveCScripts()

        let scriptingBridgeClass: AnyClass = NSClassFromString("ScriptingBridge")!
        scriptingBridge = scriptingBridgeClass.alloc() as! ScriptingBridge
        
        gitController = GitController(gitURL: URL(fileURLWithPath: "/usr/bin/git"),
                                      fileManager: FileManager.default)
        keychainManager = KeychainManager()
        jiraDataProvider = JIRADataProvider(userDefaults: UserDefaults.standard,
                                            keychainManager: keychainManager)
        gitHubDataProvider = GitHubDataProvider(userDefaults: UserDefaults.standard,
                                                keychainManager: keychainManager)
        terminalController = TerminalController(userDefaults: UserDefaults.standard)
        xcodeController = XcodeController(scriptingBridge: scriptingBridge,
                                          userDefaults: UserDefaults.standard)
        workspaceController = WorkspaceController(fileManager: FileManager.default,
                                                  gitController: gitController,
                                                  userDefaults: UserDefaults.standard,
                                                  jiraDataProvider: jiraDataProvider,
                                                  gitHubDataProvider: gitHubDataProvider)
        workspaceController.reload()
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        
        statusItem.button?.image = #imageLiteral(resourceName: "statusicon")
        statusItem.button?.image?.isTemplate = true
        statusItem.menu = NSMenu(title: statusItem.button!.title)
        
        NSMenu.setMenuBarVisible(false)
        
        menuController = MenuController(menu: statusItem.menu!,
                                        workspaceController: workspaceController,
                                        jiraDataProvider: jiraDataProvider,
                                        gitHubDataProvider: gitHubDataProvider)
        menuController.delegate = self
    }
    
}

extension AppDelegate: MenuControllerDelegate {
    func menuControllerDidInvokePreferences() {
        if preferencesCoordinator == nil {
            preferencesCoordinator = PreferencesCoordinator(workspaceController: workspaceController,
                                                            jiraDataProvider: jiraDataProvider,
                                                            gitHubDataProvider: gitHubDataProvider,
                                                            terminalController: terminalController,
                                                            xcodeController: xcodeController)
            preferencesCoordinator?.delegate = self
        }
        preferencesCoordinator?.showPreferences()
    }
    
    func menuControllerDidFocus(_ workspace: Workspace) {
        NSWorkspace.shared.launchApplication("Sourcetree")
        scriptingBridge.closeAllSourcetreeWindows()
        NSWorkspace.shared.openFile(workspace.folderURL.path, withApplication: "Sourcetree")

        if let projectURL = workspace.projectURL {
            self.xcodeController.focusOnProject(at: projectURL)
        }
    }
    
    func menuControllerDidOpenTerminal(for workspace: Workspace) {
        terminalController.open(at: workspace.folderURL)
    }
}

extension AppDelegate: PreferencesCoordinatorDelegate {
    func preferencesCoordinatorDidDismiss() {
        preferencesCoordinator = nil
    }
}

