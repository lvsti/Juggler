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
    func menuControllerDidFocus(_ workspace: Workspace)
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
            var inactiveWorkspaces: [Workspace] = []
            
            var index = 1
            for workspace in workspaceController.workspaces {
                if !workspace.isActive {
                    inactiveWorkspaces.append(workspace)
                    continue;
                }
                if index == 1 {
                    menuItems.append(NSMenuItem(title: "Active Workspaces"))
                }
                menuItems.append(menuItem(for: workspace))
                index += 1
            }
            
            if !inactiveWorkspaces.isEmpty {
                menuItems.append(NSMenuItem.separator())
                menuItems.append(NSMenuItem(title: "Free Pool"))

                for workspace in inactiveWorkspaces {
                    menuItems.append(menuItem(for: workspace))
                    index += 1
                }

            }
        }
        else {
            menuItems.append(NSMenuItem(title: "No workspaces found"))
        }
        
        menuItems.append(NSMenuItem.separator())

        menuItems.append(NSMenuItem(title: "Refresh") { _ in
            self.workspaceController.reload { _ in
                self.rebuildMenu()
            }
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
    
    private func menuItem(for workspace: Workspace) -> NSMenuItem {
        let wsItem = NSMenuItem(title: workspace.resolvedTitle)
        wsItem.submenu = workspaceMenu(for: workspace)

        let nib = NSNib(nibNamed: "WorkspaceMenuItemCell", bundle: nil)
        var topLevel: NSArray? = nil
        nib?.instantiate(withOwner: nil, topLevelObjects: &topLevel)
        let cell = topLevel?.first(where: { $0 is WorkspaceMenuItemCell }) as! WorkspaceMenuItemCell
        
        cell.badgeTitle.stringValue = "\(workspace.folderURL.lastPathComponent)"
        cell.titleLabel.stringValue = workspace.resolvedTitle
        wsItem.view = cell
        
        return wsItem
    }
    
    private func workspaceMenu(for workspace: Workspace) -> NSMenu {
        let menu = NSMenu(title: workspace.resolvedTitle)
        
        let indented: (NSMenuItem) -> NSMenuItem = { item in
            item.indentationLevel = 1
            return item
        }
        
        menu.addItem(NSMenuItem(title: "Focus") { _ in
            self.delegate?.menuControllerDidFocus(workspace)
        })
        menu.addItem(NSMenuItem.separator())

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

        let hasMetadata = workspace.pullRequest != nil || workspace.ticket != nil
        
        if hasMetadata {
            if let ticket = workspace.ticket {
                menu.addItem(NSMenuItem.separator())
                menu.addItem(NSMenuItem(title: "JIRA: \(ticket.id)"))
                menu.addItem(indented(NSMenuItem(title: "Go to JIRA Issue") { _ in
                    NSWorkspace.shared.open(ticket.url)
                }))
            }

            if let pr = workspace.pullRequest {
                menu.addItem(NSMenuItem.separator())
                menu.addItem(NSMenuItem(title: "GitHub: PR #\(pr.id)"))
                menu.addItem(indented(NSMenuItem(title: "Go to GitHub PR") { _ in
                    NSWorkspace.shared.open(pr.url)
                }))
            }
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
                prField.placeholderString = "PR number or URL"
                alert.messageText = "Enter GitHub PR number or URL:"
                alert.accessoryView = prField
                alert.addButton(withTitle: "OK")
                alert.addButton(withTitle: "Cancel")
                alert.window.initialFirstResponder = prField

                if alert.runModal() == .alertFirstButtonReturn {
                    let urlProvider = GitHubURLProvider()

                    let prID: String
                    let prURL: URL
                    if let url = URL(string: prField.stringValue), let id = urlProvider.pullRequestID(from: url, in: remote) {
                        prID = id
                        prURL = url
                    }
                    else {
                        prID = prField.stringValue
                        prURL = urlProvider.pullRequestURL(for: prID, in: remote)
                    }
                    let pr = GitHubPullRequest(id: prID,
                                               title: "PR #\(prID) (\(workspace.gitStatus.currentBranch?.name ?? "N/A"))",
                                               url: prURL)
                    self.workspaceController.setPullRequest(pr, for: workspace)
                }
            })
        }

        if hasMetadata {
            menu.addItem(NSMenuItem(title: "Reset Metadata") { _ in
                self.workspaceController.resetWorkspace(workspace, metadataOnly: true) { _ in
                    self.workspaceController.reload()
                }
            })
        }

        menu.addItem(NSMenuItem(title: "Reset Contents") { _ in
            self.workspaceController.resetWorkspace(workspace, metadataOnly: false) { _ in
                self.workspaceController.reload()
            }
        })

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Set Up...") { _ in
            self.delegate?.menuControllerDidInvokeSetup(for: workspace)
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
