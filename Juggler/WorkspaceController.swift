//
//  WorkspaceController.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 01..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Foundation

enum TicketKind: String {
    case jira
}

protocol Ticket {
    var kind: TicketKind { get }
    var id: String { get }
    var title: String? { get }
    var url: URL { get }
}

enum PullRequestKind: String {
    case github
}

protocol PullRequest {
    var kind: PullRequestKind { get }
    var id: String { get }
    var title: String? { get }
    var url: URL { get }
}

struct Workspace {
    var folderURL: URL
    var title: String?
    var description: String?
    var gitStatus: Git.WorkingCopyStatus
    var ticket: Ticket?
    var pullRequest: PullRequest?
    var projectURL: URL?
    
    var resolvedTitle: String {
        return title ??
            ticketInfo ??
            pullRequestInfo ??
            gitDescription
    }
    
    var isActive: Bool {
        return gitStatus.currentBranch?.name != "master"
    }
    
    private var ticketInfo: String? {
        guard let ticket = ticket else { return nil }
        return "[\(ticket.id)] \(ticket.title ?? "")"
    }
    
    private var pullRequestInfo: String? {
        guard let pr = pullRequest else { return nil }
        return "PR #\(pr.id) " + (pr.title ?? "(\(gitDescription))")
    }
    
    private var gitDescription: String {
        let branchSpec = gitStatus.currentBranch?.name ?? "HEAD"
        if let remote = gitStatus.remote {
            return branchSpec + " on \(remote.orgName)/\(remote.repoName)"
        }
        return branchSpec
    }
}



class WorkspaceController {
    private static let workspaceRootURLKey = "WorkspaceRootURL"
    
    private let fileManager: FileManager
    private let gitController: GitController
    private let userDefaults: UserDefaults
    private let jiraDataProvider: JIRADataProvider
    private let gitHubDataProvider: GitHubDataProvider
    private let queue: DispatchQueue

    private(set) var workspaces: [Workspace] = []

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
                completion?(self.workspaces)
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

        queue.async {
            var err: Error?
            do {
                try self.gitController.resetWorkingCopy(at: workspace.folderURL)
                try self.gitController.setCurrentBranchForWorkingCopy(at: workspace.folderURL,
                                                                      toExisting: Git.Branch(name: "master"))
                try self.gitController.pullCurrentBranchForWorkingCopy(at: workspace.folderURL)
            }
            catch {
                err = error
            }
            
            if let completion = completion {
                DispatchQueue.main.async {
                    completion(err)
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
        guard let serializedWS = userDefaults.dictionary(forKey: url.path) else {
            return nil
        }
        
        var ticket: Ticket?
        if let serializedTicket = serializedWS["ticket"] as? [String: String],
            let ticketID = serializedTicket["id"],
            let ticketKind = serializedTicket["kind"],
            let kind = TicketKind(rawValue: ticketKind)
        {
            switch kind {
            case .jira:
                ticket = JIRATicket(id: ticketID,
                                    title: serializedTicket["title"],
                                    url: jiraDataProvider.ticketURL(for: ticketID))
            }
        }
        
        var pr: PullRequest?
        if let serializedPR = serializedWS["pr"] as? [String: String],
            let prID = serializedPR["id"],
            let prKind = serializedPR["kind"],
            let kind = PullRequestKind(rawValue: prKind),
            let remote = gitStatus.remote
        {
            switch kind {
            case .github:
                pr = GitHubPullRequest(id: prID,
                                       title: serializedPR["title"],
                                       url: gitHubDataProvider.pullRequestURL(for: prID, in: remote))
            }
        }

        return Workspace(folderURL: url,
                         title: serializedWS["title"] as? String,
                         description: serializedWS["desc"] as? String,
                         gitStatus: gitStatus,
                         ticket: ticket,
                         pullRequest: pr,
                         projectURL: (serializedWS["proj"] as? String).flatMap({ URL(fileURLWithPath: $0) }) ?? xcodeProjectURL(for: url))
    }
    
    private func saveWorkspace(_ workspace: Workspace) {
        var serializedWS: [String: Any] = [:]
        
        if let title = workspace.title {
            serializedWS["title"] = title
        }
        if let desc = workspace.description {
            serializedWS["desc"] = desc
        }
        if let proj = workspace.projectURL {
            serializedWS["proj"] = proj.path
        }
        if let ticket = workspace.ticket {
            var ticketProps: [String: Any] = [
                "kind": ticket.kind.rawValue,
                "id": ticket.id
            ]
            
            if let title = ticket.title {
                ticketProps["title"] = title
            }
            serializedWS["ticket"] = ticketProps
        }
        if let pr = workspace.pullRequest {
            var prProps: [String: Any] = [
                "kind": pr.kind.rawValue,
                "id": pr.id
            ]

            if let title = pr.title {
                prProps["title"] = title
            }
            serializedWS["pr"] = prProps
        }

        userDefaults.set(serializedWS, forKey: workspace.folderURL.path)
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
