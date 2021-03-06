//
//  AppDelegate.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 01..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Cocoa
import Carbon

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
    private let hooksController: HooksController
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
                                          userDefaults: UserDefaults.standard,
                                          fileManager: FileManager.default)
        hooksController = HooksController(fileManager: FileManager.default,
                                          xcodeController: xcodeController)
        workspaceController = WorkspaceController(fileManager: FileManager.default,
                                                  gitController: gitController,
                                                  userDefaults: UserDefaults.standard,
                                                  jiraDataProvider: jiraDataProvider,
                                                  gitHubDataProvider: gitHubDataProvider,
                                                  xcodeController: xcodeController,
                                                  hooksController: hooksController)
        super.init()

        _ = GlobalHotKeys.addHandler(for: kVK_ANSI_H, modifiers: [.command, .shift]) { [weak self] in
            self?.menuControllerDidInvokeXcodeWorkspaceIdentification()
        }
        workspaceController.reload()
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
                                        gitHubDataProvider: gitHubDataProvider,
                                        xcodeController: xcodeController,
                                        gitController: gitController,
                                        hooksController: hooksController)
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
    
    func menuControllerDidInvokeXcodeWorkspaceIdentification() {
        guard let projectURL = xcodeController.getActiveProjectURL() else {
            return
        }

        if let ws = workspaceController.workspaces.first(where: { $0.projectURL == projectURL }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let noti = NSUserNotification()
                noti.title = ws.folderURL.lastPathComponent
                noti.subtitle = ws.resolvedTitle
                NSUserNotificationCenter.default.deliver(noti)
            }
        }
    }
}

extension AppDelegate: PreferencesCoordinatorDelegate {
    func preferencesCoordinatorDidDismiss() {
        preferencesCoordinator = nil
    }
}

