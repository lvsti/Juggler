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
    private let queue: DispatchQueue

    private(set) var workspaces: [Workspace] = []
    private var busyWorkspaceFolderURLs: Set<URL> = []

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
         queue: DispatchQueue = DispatchQueue(label: "WSControllerQueue", qos: .userInitiated)) {
        self.fileManager = fileManager
        self.gitController = gitController
        self.userDefaults = userDefaults
        self.jiraDataProvider = jiraDataProvider
        self.gitHubDataProvider = gitHubDataProvider
        self.queue = queue
        rootFolderURL = userDefaults.url(forKey: WorkspaceController.workspaceRootURLKey) ?? URL(fileURLWithPath: NSHomeDirectory())
    }

    func reload(completion: (([Workspace]) -> Void)? = nil) {
        queue.async {
            guard let entryNames = try? self.fileManager.contentsOfDirectory(atPath: self.rootFolderURL.path) else {
                DispatchQueue.main.async {
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
            
            self.workspaces = foundWorkspaces
            
            DispatchQueue.main.async {
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
    
    func resetWorkspace(_ workspace: Workspace, metadataOnly: Bool, completion: ((Error?) -> Void)? = nil) {
        userDefaults.set(nil, forKey: workspace.folderURL.path)
        
        guard !metadataOnly else {
            completion?(nil)
            return
        }

        busyWorkspaceFolderURLs.insert(workspace.folderURL)
        
        queue.async {
            var err: Error?
            do {
                try self.gitController.resetWorkingCopy(at: workspace.folderURL, inMode: .hard)
                try self.gitController.setCurrentBranchForWorkingCopy(at: workspace.folderURL,
                                                                      toExisting: Git.Branch(name: "master"))
                try self.gitController.pullCurrentBranchForWorkingCopy(at: workspace.folderURL)
            }
            catch {
                err = error
            }
            
            self.reload { _ in
                self.busyWorkspaceFolderURLs.remove(workspace.folderURL)
                completion?(err)
            }
        }
    }
    
    var firstAvailableWorkspace: Workspace? {
        return workspaces.first(where: { !$0.isActive })
    }
    
    func isWorkspaceBusy(_ workspace: Workspace) -> Bool {
        return busyWorkspaceFolderURLs.contains(workspace.folderURL)
    }
    
    func setUpWorkspace(_ workspace: Workspace, for ticket: Ticket, completion: ((Error?) -> Void)? = nil) {
        resetWorkspace(workspace, metadataOnly: false) { err in
            guard err == nil else { return }

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
                        completion?(NSError(domain: "", code: -1, userInfo: nil))
                    }
                    return
                }

                var newWorkspace = workspace
                newWorkspace.gitStatus = gitStatus

                if err == nil {
                    newWorkspace.ticket = ticket
                }

                DispatchQueue.main.async {
                    self.updateWorkspace(newWorkspace)
                    self.busyWorkspaceFolderURLs.remove(workspace.folderURL)
                    completion?(err)
                }
            }
        }
    }

    func setUpWorkspace(_ workspace: Workspace, for pr: PullRequest, completion: ((Error?) -> Void)? = nil) {
        resetWorkspace(workspace, metadataOnly: false) { err in
            guard err == nil else { return }
            
            self.busyWorkspaceFolderURLs.insert(workspace.folderURL)

            self.queue.async {
                var err: Error?
                do {
                    try self.gitController.fetchAllRemotesForWorkingCopy(at: workspace.folderURL)
                    try self.gitController.setCurrentBranchForWorkingCopy(at: workspace.folderURL, toExisting: pr.sourceBranch)
                    try self.gitController.pullCurrentBranchForWorkingCopy(at: workspace.folderURL)
                    try self.gitController.resetWorkingCopy(at: workspace.folderURL,
                                                            to: .branch(pr.targetBranch),
                                                            inMode: .mixed)
                }
                catch {
                    err = error
                }

                guard let gitStatus = self.gitController.workingCopyStatus(at: workspace.folderURL) else {
                    DispatchQueue.main.async {
                        self.busyWorkspaceFolderURLs.remove(workspace.folderURL)
                        completion?(NSError(domain: "", code: -1, userInfo: nil))
                    }
                    return
                }

                var newWorkspace = workspace
                newWorkspace.gitStatus = gitStatus
                if err == nil {
                    newWorkspace.pullRequest = pr
                }

                DispatchQueue.main.async {
                    self.updateWorkspace(newWorkspace)
                    self.busyWorkspaceFolderURLs.remove(workspace.folderURL)
                    completion?(err)
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
                         projectURL: xcodeProjectURL(for: url))
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
                         projectURL: meta.projectURL)
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
