//
//  MenuController.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 01..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Foundation
import AppKit

protocol MenuControllerDelegate: class {
    func menuControllerDidInvokePreferences()
    func menuControllerDidInvokeSetup(for workspace: Workspace)
}

class MenuController: NSObject, NSMenuDelegate {
    // dependencies
    private let menu: NSMenu
    private let workspaceController: WorkspaceController
    private let jiraURLProvider: JIRAURLProvider

    // state
    private var menuItems: [NSMenuItem]
    
    weak var delegate: MenuControllerDelegate?
    
    init(menu: NSMenu, workspaceController: WorkspaceController, jiraURLProvider: JIRAURLProvider) {
        self.menu = menu
        self.workspaceController = workspaceController
        self.jiraURLProvider = jiraURLProvider
        
        menuItems = []
        
        super.init()
        
        menu.delegate = self
    }
    
    private func rebuildMenu() {
        menuItems.removeAll(keepingCapacity: true)
        
        if !workspaceController.workspaces.isEmpty {
            var index = 1
            for workspace in workspaceController.workspaces {
                let wsItem = NSMenuItem(title: workspace.resolvedTitle)
                wsItem.submenu = workspaceMenu(for: workspace)
                menuItems.append(wsItem)
                index += 1
            }
        }
        else {
            menuItems.append(NSMenuItem(title: "No workspaces found"))
        }
        
        menuItems.append(NSMenuItem.separator())

        menuItems.append(NSMenuItem(title: "Refresh") { _ in
            self.workspaceController.reload()
            self.rebuildMenu()
        })
        menuItems.append(NSMenuItem(title: "Preferences...") { _ in
            self.delegate?.menuControllerDidInvokePreferences()
        })
        menuItems.append(NSMenuItem.separator())
        menuItems.append(NSMenuItem(title: "Quit Juggler", keyEquivalent: "q") { _ in
            NSApplication.shared.terminate(nil)
        })
    }
    
    private func renderMenu() {
        menu.removeAllItems()
        for item in menuItems {
            menu.addItem(item)
        }
    }
    
    private func workspaceMenu(for workspace: Workspace) -> NSMenu {
        let menu = NSMenu(title: workspace.resolvedTitle)
        
        let indented: (NSMenuItem) -> NSMenuItem = { item in
            item.indentationLevel = 1
            return item
        }

        menu.addItem(NSMenuItem(title: "Workspace"))
        if let project = workspace.projectURL {
            menu.addItem(indented(NSMenuItem(title: "Open in Xcode") { _ in
                NSWorkspace.shared.openFile(project.path, withApplication: "Xcode")
            }))
        }
        else {
            menu.addItem(indented(NSMenuItem(title: "Open in Xcode")))
        }
        menu.addItem(indented(NSMenuItem(title: "Open in Sourcetree") { _ in
            NSWorkspace.shared.openFile(workspace.folderURL.path, withApplication: "Sourcetree")
        }))
        menu.addItem(indented(NSMenuItem(title: "Open in Finder") { _ in
            NSWorkspace.shared.open(workspace.folderURL)
        }))
        menu.addItem(indented(NSMenuItem(title: "Open in Terminal") { _ in
            NSWorkspace.shared.openFile(workspace.folderURL.path, withApplication: "iTerm")
        }))

        if let pr = workspace.pullRequest {
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "GitHub"))
            menu.addItem(indented(NSMenuItem(title: "Go to PR") { _ in
                NSWorkspace.shared.open(pr.url)
            }))
        }
        
        if let ticket = workspace.ticket {
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "JIRA"))
            menu.addItem(indented(NSMenuItem(title: "Go to Issue") { _ in
                NSWorkspace.shared.open(ticket.url)
            }))
        }
        
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Link to JIRA ticket...") { _ in
            let alert = NSAlert()
            let ticketField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 22))
            ticketField.placeholderString = "Ticket ID"
            alert.messageText = "Enter JIRA ticket ID:"
            alert.accessoryView = ticketField
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            alert.window.initialFirstResponder = ticketField
            
            if alert.runModal() == .alertFirstButtonReturn {
                let ticketID = ticketField.stringValue
                let ticketURL = self.jiraURLProvider.ticketURL(for: ticketID)
                let ticket = JIRATicket(id: ticketID, title: ticketID, url: ticketURL)
                self.workspaceController.setTicket(ticket, for: workspace)
            }
        })

        
        if let remote = workspace.gitStatus.remote {
            menu.addItem(NSMenuItem(title: "Link to GitHub PR...") { _ in
                let alert = NSAlert()
                let prField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 22))
                prField.placeholderString = "PR number"
                alert.messageText = "Enter GitHub PR number:"
                alert.accessoryView = prField
                alert.addButton(withTitle: "OK")
                alert.addButton(withTitle: "Cancel")
                alert.window.initialFirstResponder = prField

                if alert.runModal() == .alertFirstButtonReturn {
                    let prID = prField.stringValue
                    let prURL = GitHubURLProvider().pullRequestURL(for: prID, in: remote)
                    let pr = GitHubPullRequest(id: prID,
                                               title: "PR #\(prID) (\(workspace.gitStatus.currentBranch?.name ?? "N/A"))",
                                               url: prURL)
                    self.workspaceController.setPullRequest(pr, for: workspace)
                }
            })
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Set Up...") { _ in
            self.delegate?.menuControllerDidInvokeSetup(for: workspace)
        })
        menu.addItem(NSMenuItem(title: "Reset") { _ in
            self.workspaceController.resetWorkspace(workspace)
            self.workspaceController.reload()
        })

        return menu
    }

    // MARK: - from NSMenuDelegate:
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu == self.menu else {
            return
        }

        rebuildMenu()
        renderMenu()
    }
    
}
