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
    var title: String { get }
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
            ticket?.title ??
            pullRequest?.title ??
            gitDescription
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
    private let jiraURLProvider: JIRAURLProvider
    private let gitHubURLProvider: GitHubURLProvider

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
         jiraURLProvider: JIRAURLProvider,
         gitHubURLProvider: GitHubURLProvider) {
        self.fileManager = fileManager
        self.gitController = gitController
        self.userDefaults = userDefaults
        self.jiraURLProvider = jiraURLProvider
        self.gitHubURLProvider = gitHubURLProvider
        rootFolderURL = userDefaults.url(forKey: WorkspaceController.workspaceRootURLKey) ?? URL(fileURLWithPath: NSHomeDirectory())
    }

    func reload() {
        guard let entryNames = try? fileManager.contentsOfDirectory(atPath: rootFolderURL.path) else {
            return
        }

        var foundWorkspaces: [Workspace] = []
        
        for entryName in entryNames {
            let folderURL = rootFolderURL.appendingPathComponent(entryName)
            guard let gitStatus = gitController.workingCopyStatus(at: folderURL) else {
                continue
            }

            if let workspace = loadWorkspace(at: folderURL, with: gitStatus) {
                foundWorkspaces.append(workspace)
            }
            else {
                foundWorkspaces.append(createWorkspace(for: folderURL, with: gitStatus))
            }
        }
        
        workspaces = foundWorkspaces
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
                                    url: jiraURLProvider.ticketURL(for: ticketID))
            }
        }
        
        var pr: PullRequest?
        if let serializedPR = serializedWS["pr"] as? [String: String],
            let prID = serializedPR["id"],
            let prKind = serializedPR["kind"],
            let prTitle = serializedPR["title"],
            let kind = PullRequestKind(rawValue: prKind),
            let remote = gitStatus.remote
        {
            switch kind {
            case .github:
                pr = GitHubPullRequest(id: prID,
                                       title: prTitle,
                                       url: gitHubURLProvider.pullRequestURL(for: prID, in: remote))
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
            serializedWS["ticket"] = [
                "kind": ticket.kind.rawValue,
                "id": ticket.id,
                "title": ticket.title ?? ""
            ]
        }
        if let pr = workspace.pullRequest {
            serializedWS["pr"] = [
                "kind": pr.kind.rawValue,
                "id": pr.id,
                "title": pr.title
            ]
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
