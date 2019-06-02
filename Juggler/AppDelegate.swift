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
        
        menuController = MenuController(menu: statusItem.menu!, workspaceController: workspaceController)
    }
    
}

