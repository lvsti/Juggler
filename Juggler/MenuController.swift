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
    func menuControllerDidFocus(_ workspace: Workspace)
    func menuControllerDidOpenTerminal(for workspace: Workspace)
}

class MenuController: NSObject, NSMenuDelegate {
    // dependencies
    private let menu: NSMenu
    private let workspaceController: WorkspaceController
    private let jiraDataProvider: JIRADataProvider
    private let gitHubDataProvider: GitHubDataProvider

    // state
    private var menuItems: [NSMenuItem]
    
    weak var delegate: MenuControllerDelegate?
    
    init(menu: NSMenu,
         workspaceController: WorkspaceController,
         jiraDataProvider: JIRADataProvider,
         gitHubDataProvider: GitHubDataProvider) {
        self.menu = menu
        self.workspaceController = workspaceController
        self.jiraDataProvider = jiraDataProvider
        self.gitHubDataProvider = gitHubDataProvider

        menuItems = []
        
        super.init()
        
        menu.delegate = self
    }
    
    private func rebuildMenu() {
        menuItems.removeAll(keepingCapacity: true)

        buildWorkflowMenuItems()
        menuItems.append(NSMenuItem.separator())

        buildWorkspaceMenuItems()
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
    
    private func buildWorkflowMenuItems() {
        let allRemotes = Set(workspaceController.workspaces.compactMap { $0.gitStatus.remote })
        
        let ticketMenu = NSMenu(title: "Start Ticket")
        let reviewMenu = NSMenu(title: "Start Code Review")
        
        if !workspaceController.isReloading {
            for remote in allRemotes {
                if let availableWorkspace = workspaceController.firstAvailableWorkspace(for: remote) {
                    ticketMenu.addItem(NSMenuItem(title: "In \(remote.orgName)/\(remote.repoName)...") { _ in
                        self.promptForJIRATicket { ticket in
                            guard let ticket = ticket else { return }
                            self.workspaceController.setUpWorkspace(availableWorkspace, forTicket: ticket)
                        }
                    })
                    
                    reviewMenu.addItem(NSMenuItem(title: "In \(remote.orgName)/\(remote.repoName)...") { _ in
                        self.promptForGitHubPullRequest(remote: remote) { pr in
                            guard let pr = pr else { return }
                            
                            self.workspaceController.setUpWorkspace(availableWorkspace, forReviewing: pr) { ws, err in
                                guard let ws = ws else { return }

                                guard
                                    let prTitle = pr.title,
                                    let regex = self.gitHubDataProvider.ticketIDFromPRTitleRegex,
                                    let match = regex.firstMatch(in: prTitle,
                                                                 options: [],
                                                                 range: NSRange(location: 0, length: prTitle.count))
                                else {
                                    return
                                }
                                
                                let ticketID = String(prTitle[Range(match.range(at: 1), in: prTitle)!])
                                
                                self.jiraDataProvider.fetchTicket(for: ticketID) { ticket, _ in
                                    guard let ticket = ticket else { return }
                                    self.workspaceController.setTicket(ticket, for: ws)
                                }
                            }
                        }
                    })
                }
                else {
                    ticketMenu.addItem(NSMenuItem(title: "In \(remote.orgName)/\(remote.repoName)..."))
                    reviewMenu.addItem(NSMenuItem(title: "In \(remote.orgName)/\(remote.repoName)..."))
                }
            }
        }
        
        let showEllipsis = allRemotes.count == 1 || workspaceController.isReloading
        
        let ticketItem = NSMenuItem(title: showEllipsis ? "Start Ticket..." : "Start Ticket")
        menuItems.append(ticketItem)
        
        let reviewItem = NSMenuItem(title: showEllipsis ? "Start Code Review..." : "Start Code Review")
        menuItems.append(reviewItem)

        if allRemotes.count == 1 {
            let remote = allRemotes.first!
            if let availableWorkspace = workspaceController.firstAvailableWorkspace(for: remote) {
                ticketItem.setHandler { _ in
                    self.promptForJIRATicket { ticket in
                        guard let ticket = ticket else { return }
                        self.workspaceController.setUpWorkspace(availableWorkspace, forTicket: ticket)
                    }
                }
                reviewItem.setHandler { _ in
                    self.promptForGitHubPullRequest(remote: remote) { pr in
                        guard let pr = pr else { return }
                        self.workspaceController.setUpWorkspace(availableWorkspace, forReviewing: pr) { ws, err in
                            guard let ws = ws else { return }
                            
                            guard
                                let prTitle = pr.title,
                                let regex = self.gitHubDataProvider.ticketIDFromPRTitleRegex,
                                let match = regex.firstMatch(in: prTitle,
                                                             options: [],
                                                             range: NSRange(location: 0, length: prTitle.count))
                            else {
                                return
                            }
                            
                            let ticketID = String(prTitle[Range(match.range(at: 1), in: prTitle)!])
                            
                            self.jiraDataProvider.fetchTicket(for: ticketID) { ticket, _ in
                                guard let ticket = ticket else { return }
                                self.workspaceController.setTicket(ticket, for: ws)
                            }
                        }
                    }
                }
            }
        }
        else {
            ticketItem.submenu = !workspaceController.isReloading ? ticketMenu : nil
            reviewItem.submenu = !workspaceController.isReloading ? reviewMenu : nil
        }
    }
    
    private func buildWorkspaceMenuItems() {
        if workspaceController.isReloading {
            menuItems.append(NSMenuItem(title: "Scanning workspaces..."))
        }
        else if !workspaceController.workspaces.isEmpty {
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
    }

    private func menuItem(for workspace: Workspace) -> NSMenuItem {
        let wsItem = NSMenuItem(title: workspace.resolvedTitle)

        let nib = NSNib(nibNamed: "WorkspaceMenuItemCell", bundle: nil)
        var topLevel: NSArray? = nil
        nib?.instantiate(withOwner: nil, topLevelObjects: &topLevel)
        let cell = topLevel?.first(where: { $0 is WorkspaceMenuItemCell }) as! WorkspaceMenuItemCell
        
        cell.badgeTitle.stringValue = "\(workspace.name)"
        cell.titleLabel.stringValue = workspace.resolvedTitle
        cell.color = workspace.color?.toNSColor()
        wsItem.view = cell

        let isBusy = workspaceController.isWorkspaceBusy(workspace)
        cell.disclosureArrow.isHidden = isBusy
        cell.spinner.isHidden = !isBusy
        if isBusy {
            cell.spinner.startAnimation(nil)
        }
        wsItem.submenu = isBusy ? nil : workspaceMenu(for: workspace)

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
            self.delegate?.menuControllerDidOpenTerminal(for: workspace)
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
            self.promptForJIRATicket { ticket in
                guard let ticket = ticket else { return }
                self.workspaceController.setTicket(ticket, for: workspace)
            }
        })
        
        if let remote = workspace.gitStatus.remote {
            menu.addItem(NSMenuItem(title: "Link to GitHub PR...") { _ in
                self.promptForGitHubPullRequest(remote: remote) { pr in
                    guard let pr = pr else { return }
                    self.workspaceController.setPullRequest(pr, for: workspace)
                }
            })
        }

        let colorItem = NSMenuItem(title: "Set Color")
        colorItem.submenu = colorMenu(for: workspace)
        menu.addItem(colorItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Reset Contents") { _ in
            self.workspaceController.resetWorkspace(workspace, metadataOnly: false, discardChangesHandler: {
                return self.showConfirmDiscardChangesAlert(for: workspace)
            })
        })

        return menu
    }
    
    private func colorMenu(for workspace: Workspace) -> NSMenu {
        let menu = NSMenu(title: "Set Color")
        
        for color in Workspace.Color.allCases {
            let item = NSMenuItem(title: color.name) { _ in
                self.workspaceController.setColor(color, for: workspace)
            }
            item.image = colorSwatch(for: color.toNSColor())
            item.state = workspace.color == color ? .on : .off
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Reset to Default") { _ in
            self.workspaceController.setColor(nil, for: workspace)
        })
        
        return menu
    }
    
    private func colorSwatch(for color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        color.set()
        NSRect(x: 0, y: 0, width: 10, height: 10).fill()
        image.unlockFocus()
        return image
    }
    
    private func promptForJIRATicket(completion: @escaping (JIRATicket?) -> Void) {
        let alert = NSAlert()
        let ticketField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 22))
        ticketField.placeholderString = "Ticket ID or URL"
        alert.messageText = "Enter JIRA ticket ID or URL:"
        alert.accessoryView = ticketField
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = ticketField
        
        if alert.runModal() != .alertFirstButtonReturn {
            completion(nil)
            return
        }
        
        let ticketID: String
        if let url = URL(string: ticketField.stringValue), let id = jiraDataProvider.ticketID(from: url) {
            ticketID = id
        }
        else {
            ticketID = ticketField.stringValue
        }
        
        jiraDataProvider.fetchTicket(for: ticketID) { ticket, _ in
            if ticket == nil {
                self.showTicketFetchFailedAlert()
            }
            completion(ticket)
        }
    }
    
    private func showTicketFetchFailedAlert() {
        let alert = NSAlert()
        alert.messageText = "Failed to query ticket"
        alert.informativeText = "This could as well be a network hiccup or the requested ticket might not exist."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func promptForGitHubPullRequest(remote: Git.Remote, completion: @escaping (GitHubPullRequest?) -> Void) {
        let alert = NSAlert()
        let prField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 22))
        prField.placeholderString = "PR number or URL"
        alert.messageText = "Enter GitHub PR number or URL:"
        alert.accessoryView = prField
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = prField
        
        if alert.runModal() != .alertFirstButtonReturn {
            completion(nil)
            return
        }
        
        let prID: String
        if let url = URL(string: prField.stringValue), let id = gitHubDataProvider.pullRequestID(from: url, in: remote) {
            prID = id
        }
        else {
            prID = prField.stringValue
        }
        
        gitHubDataProvider.fetchPullRequest(for: prID, in: remote) { pr, _ in
            if pr == nil {
                self.showPRFetchFailedAlert(remote: remote)
            }
            completion(pr)
        }
    }
    
    private func showPRFetchFailedAlert(remote: Git.Remote) {
        let alert = NSAlert()
        alert.messageText = "Failed to query pull request"
        alert.informativeText = "This could as well be a network hiccup or the requested PR " +
                                "might not exist in the \(remote.orgName)/\(remote.repoName) remote."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showConfirmDiscardChangesAlert(for workspace: Workspace) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Discard changes?"
        alert.informativeText = "The working copy in \"\(workspace.name)\" is not clean, do you want to discard changes?"
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")
        
        class ChangesDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
            private let changes: [Git.LocalChange]
            
            init(changes: [Git.LocalChange]) {
                self.changes = changes
            }

            func numberOfRows(in tableView: NSTableView) -> Int {
                return changes.count
            }
            
            func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
                return changes[row].path
            }

            func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
                let tf = NSTextField(frame: CGRect(x: 0, y: 0, width: 200, height: 17))
                tf.stringValue = changes[row].path
                tf.textColor = {
                    switch changes[row].type {
                    case .added: return .systemGreen
                    case .deleted: return .systemRed
                    case .modified: return .systemBlue
                    case .untracked: return .systemGray
                    }
                }()
                tf.drawsBackground = false
                tf.isBezeled = false
                tf.lineBreakMode = .byTruncatingMiddle

                let view = NSTableCellView(frame: CGRect(x: 0, y: 0, width: 200, height: 17))
                view.addSubview(tf)
                view.textField = tf

                return view
            }
        }
        
        let dataSource = ChangesDataSource(changes: workspace.gitStatus.localChanges)

        let scrollView = NSScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
        scrollView.hasVerticalScroller = true
        
        let clipView = NSClipView(frame: .zero)
        clipView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentView = clipView
        scrollView.addConstraint(NSLayoutConstraint(item: clipView, attribute: .left, relatedBy: .equal, toItem: scrollView, attribute: .left, multiplier: 1.0, constant: 0))
        scrollView.addConstraint(NSLayoutConstraint(item: clipView, attribute: .top, relatedBy: .equal, toItem: scrollView, attribute: .top, multiplier: 1.0, constant: 0))
        scrollView.addConstraint(NSLayoutConstraint(item: clipView, attribute: .right, relatedBy: .equal, toItem: scrollView, attribute: .right, multiplier: 1.0, constant: 0))
        scrollView.addConstraint(NSLayoutConstraint(item: clipView, attribute: .bottom, relatedBy: .equal, toItem: scrollView, attribute: .bottom, multiplier: 1.0, constant: 0))

        let tableView = NSTableView(frame: .zero)
        tableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "Column")))
        tableView.headerView = nil
        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsEmptySelection = true

        scrollView.documentView = tableView
        clipView.addConstraint(NSLayoutConstraint(item: clipView, attribute: .left, relatedBy: .equal, toItem: tableView, attribute: .left, multiplier: 1.0, constant: 0))
        clipView.addConstraint(NSLayoutConstraint(item: clipView, attribute: .top, relatedBy: .equal, toItem: tableView, attribute: .top, multiplier: 1.0, constant: 0))
        clipView.addConstraint(NSLayoutConstraint(item: clipView, attribute: .right, relatedBy: .equal, toItem: tableView, attribute: .right, multiplier: 1.0, constant: 0))

        alert.accessoryView = scrollView
        
        return alert.runModal() == .alertFirstButtonReturn
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

extension Workspace.Color {
    func toNSColor() -> NSColor {
        switch self {
        case .red: return .systemRed
        case .orange: return .systemOrange
        case .yellow: return .systemYellow
        case .green: return .systemGreen
        case .teal: return .systemTeal
        case .blue: return .systemBlue
        case .purple: return .systemPurple
        case .pink: return .systemPink
        }
    }
    
    var name: String {
        switch self {
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .teal: return "Teal"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .pink: return "Pink"
        }
    }
}
