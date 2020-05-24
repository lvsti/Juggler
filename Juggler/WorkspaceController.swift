//
//  WorkspaceController.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 01..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Foundation

class WorkspaceController {
    private static let workspaceRootURLKey = "WorkspaceRootURL"
    
    private let fileManager: FileManager
    private let gitController: GitController
    private let userDefaults: UserDefaults
    private let jiraDataProvider: JIRADataProvider
    private let gitHubDataProvider: GitHubDataProvider
    private let xcodeController: XcodeController
    private let queue: DispatchQueue

    private(set) var workspaces: [Workspace] = []
    private var busyWorkspaceFolderURLs: Set<URL> = []
    private(set) var isReloading = false

    var rootFolderURL: URL {
        didSet {
            if !rootFolderURL.isFileURL {
                rootFolderURL = oldValue
            }

            guard rootFolderURL != oldValue else {
                return
            }
            
            userDefaults.set(rootFolderURL, forKey: WorkspaceController.workspaceRootURLKey)

            reload()
        }
    }

    init(fileManager: FileManager,
         gitController: GitController,
         userDefaults: UserDefaults,
         jiraDataProvider: JIRADataProvider,
         gitHubDataProvider: GitHubDataProvider,
         xcodeController: XcodeController,
         queue: DispatchQueue = DispatchQueue(label: "WSControllerQueue", qos: .userInitiated)) {
        self.fileManager = fileManager
        self.gitController = gitController
        self.userDefaults = userDefaults
        self.jiraDataProvider = jiraDataProvider
        self.gitHubDataProvider = gitHubDataProvider
        self.xcodeController = xcodeController
        self.queue = queue
        rootFolderURL = userDefaults.url(forKey: WorkspaceController.workspaceRootURLKey) ?? URL(fileURLWithPath: NSHomeDirectory())
    }

    func reload(completion: (([Workspace]) -> Void)? = nil) {
        isReloading = true
        
        queue.async {
            guard let entryNames = try? self.fileManager.contentsOfDirectory(atPath: self.rootFolderURL.path) else {
                DispatchQueue.main.async {
                    self.isReloading = false
                    completion?(self.workspaces)
                }
                return
            }
            
            var foundWorkspaces: [Workspace] = []
            
            for entryName in entryNames {
                let folderURL = self.rootFolderURL.appendingPathComponent(entryName)
                guard let gitStatus = self.gitController.workingCopyStatus(at: folderURL) else {
                    continue
                }
                
                if let workspace = self.loadWorkspace(at: folderURL, with: gitStatus) {
                    foundWorkspaces.append(workspace)
                }
                else {
                    foundWorkspaces.append(self.createWorkspace(for: folderURL, with: gitStatus))
                }
            }
            
            self.workspaces = foundWorkspaces.sorted(by: { $0.name < $1.name })
            
            DispatchQueue.main.async {
                self.isReloading = false
                completion?(self.workspaces)
            }
        }
    }
    
    func setPullRequest(_ pr: PullRequest?, for workspace: Workspace) {
        var newWorkspace = workspace
        newWorkspace.pullRequest = pr
        updateWorkspace(newWorkspace)
    }

    func setTicket(_ ticket: Ticket?, for workspace: Workspace) {
        var newWorkspace = workspace
        newWorkspace.ticket = ticket
        updateWorkspace(newWorkspace)
    }
    
    func setColor(_ color: Workspace.Color?, for workspace: Workspace) {
        var newWorkspace = workspace
        newWorkspace.color = color
        updateWorkspace(newWorkspace)
    }
    
    func resetWorkspace(_ workspace: Workspace,
                        metadataOnly: Bool,
                        discardChangesHandler: @escaping () -> Bool,
                        completion: ((Workspace?, Error?) -> Void)? = nil) {
        if metadataOnly {
            userDefaults.set(nil, forKey: workspace.folderURL.path)
            guard let ws = loadWorkspace(at: workspace.folderURL, with: workspace.gitStatus) else {
                completion?(nil, NSError(domain: "", code: -1, userInfo: nil))
                return
            }
            completion?(ws, nil)
            return
        }

        busyWorkspaceFolderURLs.insert(workspace.folderURL)
        
        queue.async {
            var err: Error?
            do {
                if let checkoutType = workspace.checkoutType {
                    let scriptName: String
                    switch checkoutType {
                    case .ticket: scriptName = "ticket-teardown.sh"
                    case .codeReview: scriptName = "codereview-teardown.sh"
                    }
                    
                    let teardownScriptURL = self.rootFolderURL.appendingPathComponent(".juggler").appendingPathComponent(scriptName)
                    if self.fileManager.fileExists(atPath: teardownScriptURL.path) {
                        var envVars: [String: String] = [
                            "WORKSPACE_DIR": workspace.folderURL.path,
                            "PROJECT_PATH": workspace.projectURL?.path ?? "",
                            "DERIVED_DATA_DIR": workspace.projectURL != nil ? self.xcodeController.derivedDataFolderURLs(forProjectAt: workspace.projectURL!).first?.path ?? "" : ""
                        ]
                        
                        if let pr = workspace.pullRequest {
                            envVars.merge([
                                "PR_ID": pr.id,
                                "PR_TITLE": pr.title ?? "",
                                "PR_URL": pr.url.absoluteString,
                                "PR_SOURCE_BRANCH": pr.sourceBranch.name,
                                "PR_TARGET_BRANCH": pr.targetBranch.name
                            ], uniquingKeysWith: { $1 })
                        }
                        if let ticket = workspace.ticket {
                            envVars.merge([
                                "TICKET_ID": ticket.id,
                                "TICKET_TITLE": ticket.title ?? "",
                                "TICKET_URL": ticket.url.absoluteString,
                            ], uniquingKeysWith: { $1 })
                        }
                        
                        let envStr = envVars.map { $0.key + "=\"" + $0.value + "\""}.joined(separator: " ")
                        
                        do {
                            let log = try shell("/bin/bash", args: ["-l", "-c", "cd \"\(workspace.folderURL.path)\" ; " + envStr + " " + teardownScriptURL.path])
                            try log.write(to: workspace.folderURL.appendingPathComponent("log.txt"), atomically: false, encoding: .utf8)
                        }
                        catch {
                            err = error
                        }
                    }
                }
                
                if let currentStatus = self.gitController.workingCopyStatus(at: workspace.folderURL),
                    currentStatus.localChanges.isEmpty || DispatchQueue.main.sync(execute: discardChangesHandler) {
                    self.userDefaults.set(nil, forKey: workspace.folderURL.path)
                    if let projectURL = workspace.projectURL {
                        self.xcodeController.removeUserData(forProjectAt: projectURL)
                    }
                    try self.gitController.resetWorkingCopy(at: workspace.folderURL, inMode: .hard)
                    try self.gitController.removeUntrackedFiles(at: workspace.folderURL)
                    try self.gitController.setCurrentBranchForWorkingCopy(at: workspace.folderURL,
                                                                          toExisting: Git.Branch(name: "master"))
                    try self.gitController.pullCurrentBranchForWorkingCopy(at: workspace.folderURL)
                }
            }
            catch {
                err = error
            }

            self.reload { wss in
                self.busyWorkspaceFolderURLs.remove(workspace.folderURL)
                let ws = err == nil ? wss.first(where: { $0.folderURL == workspace.folderURL }) : nil
                completion?(ws, err)
            }
        }
    }
    
    func firstAvailableWorkspace(for remote: Git.Remote) -> Workspace? {
        return workspaces.first(where: { !$0.isActive && $0.gitStatus.remote == remote })
    }
    
    func isWorkspaceBusy(_ workspace: Workspace) -> Bool {
        return busyWorkspaceFolderURLs.contains(workspace.folderURL)
    }
    
    func setUpWorkspace(_ workspace: Workspace, forTicket ticket: Ticket, completion: ((Workspace?, Error?) -> Void)? = nil) {
        resetWorkspace(workspace, metadataOnly: false, discardChangesHandler: { return true }) { ws, err in
            guard let ws = ws else {
                completion?(nil, err)
                return
            }

            self.busyWorkspaceFolderURLs.insert(workspace.folderURL)

            self.queue.async {
                var err: Error?
                do {
                    let branch = try self.gitController.createBranchForWorkingCopy(at: workspace.folderURL,
                                                                                   branchName: ticket.preferredBranchName)
                    try self.gitController.setCurrentBranchForWorkingCopy(at: workspace.folderURL,
                                                                          toExisting: branch)
                }
                catch {
                    err = error
                }

                guard let gitStatus = self.gitController.workingCopyStatus(at: workspace.folderURL) else {
                    DispatchQueue.main.async {
                        self.busyWorkspaceFolderURLs.remove(workspace.folderURL)
                        completion?(nil, NSError(domain: "", code: -1, userInfo: nil))
                    }
                    return
                }

                let setupScriptURL = self.rootFolderURL.appendingPathComponent(".juggler").appendingPathComponent("ticket-setup.sh")
                if self.fileManager.fileExists(atPath: setupScriptURL.path) {
                    let envVars: [String: String] = [
                        "WORKSPACE_DIR": workspace.folderURL.path,
                        "PROJECT_PATH": workspace.projectURL?.path ?? "",
                        "DERIVED_DATA_DIR": workspace.projectURL != nil ? self.xcodeController.derivedDataFolderURLs(forProjectAt: workspace.projectURL!).first?.path ?? "" : "",
                        "TICKET_ID": ticket.id,
                        "TICKET_TITLE": ticket.title ?? "",
                        "TICKET_URL": ticket.url.absoluteString
                    ]
                    
                    let envStr = envVars.map { $0.key + "=\"" + $0.value + "\""}.joined(separator: " ")
                    
                    do {
                        let log = try shell("/bin/bash", args: ["-l", "-c", "cd \"\(workspace.folderURL.path)\" ; " + envStr + " " + setupScriptURL.path])
                        try log.write(to: workspace.folderURL.appendingPathComponent("log.txt"), atomically: false, encoding: .utf8)
                    }
                    catch {
                        err = error
                    }
                }

                var newWorkspace = ws
                newWorkspace.gitStatus = gitStatus
                if err == nil {
                    newWorkspace.ticket = ticket
                    newWorkspace.checkoutType = .ticket
                }

                DispatchQueue.main.async {
                    self.updateWorkspace(newWorkspace)
                    self.busyWorkspaceFolderURLs.remove(workspace.folderURL)
                    completion?(err == nil ? newWorkspace : nil, err)
                }
            }
        }
    }

    func setUpWorkspace(_ workspace: Workspace, forReviewing pr: PullRequest, completion: ((Workspace?, Error?) -> Void)? = nil) {
        resetWorkspace(workspace, metadataOnly: false, discardChangesHandler: { return true }) { ws, err in
            guard let ws = ws else {
                completion?(nil, err)
                return
            }

            self.busyWorkspaceFolderURLs.insert(workspace.folderURL)

            self.queue.async {
                var err: Error?
                do {
                    try self.gitController.fetchAllRemotesForWorkingCopy(at: workspace.folderURL)
                    try self.gitController.setCurrentBranchForWorkingCopy(at: workspace.folderURL, toExisting: pr.sourceBranch)
                    try self.gitController.pullCurrentBranchForWorkingCopy(at: workspace.folderURL)
                    
                    let forkPoint = try self.gitController.forkPoint(at: workspace.folderURL,
                                                                     of: .branch(pr.sourceBranch),
                                                                     relativeTo: .branch(pr.targetBranch))
                    try self.gitController.resetWorkingCopy(at: workspace.folderURL,
                                                            to: forkPoint,
                                                            inMode: .mixed)
                }
                catch {
                    err = error
                }

                guard let gitStatus = self.gitController.workingCopyStatus(at: workspace.folderURL) else {
                    DispatchQueue.main.async {
                        self.busyWorkspaceFolderURLs.remove(workspace.folderURL)
                        completion?(nil, NSError(domain: "", code: -1, userInfo: nil))
                    }
                    return
                }
                
                let setupScriptURL = self.rootFolderURL.appendingPathComponent(".juggler").appendingPathComponent("codereview-setup.sh")
                if self.fileManager.fileExists(atPath: setupScriptURL.path) {
                    let envVars: [String: String] = [
                        "WORKSPACE_DIR": workspace.folderURL.path,
                        "PROJECT_PATH": workspace.projectURL?.path ?? "",
                        "DERIVED_DATA_DIR": workspace.projectURL != nil ? self.xcodeController.derivedDataFolderURLs(forProjectAt: workspace.projectURL!).first?.path ?? "" : "",
                        "PR_ID": pr.id,
                        "PR_TITLE": pr.title ?? "",
                        "PR_URL": pr.url.absoluteString,
                        "PR_SOURCE_BRANCH": pr.sourceBranch.name,
                        "PR_TARGET_BRANCH": pr.targetBranch.name
                    ]
                    
                    let envStr = envVars.map { $0.key + "=\"" + $0.value + "\""}.joined(separator: " ")
                    
                    do {
                        let log = try shell("/bin/bash", args: ["-l", "-c", "cd \"\(workspace.folderURL.path)\" ; " + envStr + " " + setupScriptURL.path])
                        try log.write(to: workspace.folderURL.appendingPathComponent("log.txt"), atomically: false, encoding: .utf8)
                    }
                    catch {
                        err = error
                    }
                }

                var newWorkspace = ws
                newWorkspace.gitStatus = gitStatus
                if err == nil {
                    newWorkspace.pullRequest = pr
                    newWorkspace.checkoutType = .codeReview
                }

                DispatchQueue.main.async {
                    self.updateWorkspace(newWorkspace)
                    self.busyWorkspaceFolderURLs.remove(workspace.folderURL)
                    completion?(err == nil ? newWorkspace : nil, err)
                }
            }
        }
    }

    private func updateWorkspace(_ workspace: Workspace) {
        saveWorkspace(workspace)
        
        queue.sync {
            let index = workspaces.firstIndex(where: { $0.folderURL == workspace.folderURL })!

            var newWorkspaces = self.workspaces
            newWorkspaces.replaceSubrange(index ..< index + 1, with: [workspace])
            self.workspaces = newWorkspaces
        }
    }

    private func createWorkspace(for url: URL, with gitStatus: Git.WorkingCopyStatus) -> Workspace {
        return Workspace(folderURL: url,
                         title: nil,
                         description: nil,
                         gitStatus: gitStatus,
                         ticket: nil,
                         pullRequest: nil,
                         projectURL: xcodeProjectURL(for: url),
                         color: nil,
                         checkoutType: nil)
    }
    
    private func loadWorkspace(at url: URL, with gitStatus: Git.WorkingCopyStatus) -> Workspace? {
        guard
            let jsonData = userDefaults.string(forKey: url.path)?.data(using: .utf8),
            let meta = try? JSONDecoder().decode(WorkspaceMeta.self, from: jsonData)
        else {
            return nil
        }
        
        return Workspace(folderURL: url,
                         title: meta.title,
                         description: meta.description,
                         gitStatus: gitStatus,
                         ticket: meta.ticket,
                         pullRequest: meta.pullRequest,
                         projectURL: meta.projectURL,
                         color: meta.color,
                         checkoutType: meta.checkoutType)
    }
    
    private func saveWorkspace(_ workspace: Workspace) {
        guard
            let jsonData = try? JSONEncoder().encode(workspace.meta),
            let json = String(data: jsonData, encoding: .utf8)
        else {
            return
        }
        userDefaults.set(json, forKey: workspace.folderURL.path)
    }

    private func xcodeProjectURL(for folderURL: URL) -> URL? {
        let enumerator = fileManager.enumerator(at: folderURL,
                                                includingPropertiesForKeys: [],
                                                options: [.skipsHiddenFiles, .skipsPackageDescendants])!
        var projects: [URL] = []
        for entry in enumerator {
            let url = entry as! URL
            if url.pathExtension == "xcworkspace" {
                return url
            }
            else if url.pathExtension == "xcodeproj" {
                projects.append(url)
            }
        }
        
        return projects.first
    }
}
