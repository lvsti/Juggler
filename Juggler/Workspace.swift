//
//  Workspace.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 10..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Foundation

struct Workspace {
    var folderURL: URL
    var title: String?
    var description: String?
    var gitStatus: Git.WorkingCopyStatus
    var ticket: Ticket?
    var pullRequest: PullRequest?
    var projectURL: URL?
    
    var meta: WorkspaceMeta {
        var wsMeta = WorkspaceMeta()
        wsMeta.title = title
        wsMeta.description = description
        wsMeta.ticket = ticket
        wsMeta.pullRequest = pullRequest
        wsMeta.projectURL = projectURL
        return wsMeta
    }
    
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

struct WorkspaceMeta: Codable {
    var title: String?
    var description: String?
    var ticket: Ticket?
    var pullRequest: PullRequest?
    var projectURL: URL?
    
    init() {}

    private enum CodingKeys: String, CodingKey {
        case title, description = "desc", ticketKind, jiraTicket, prKind, gitHubPR, projectURL = "proj"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        title = try container.decodeIfPresent(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        projectURL = try container.decodeIfPresent(String.self, forKey: .projectURL).flatMap { URL(fileURLWithPath: $0) }

        if let ticketKind = try container.decodeIfPresent(TicketKind.self, forKey: .ticketKind), ticketKind == .jira {
            ticket = try container.decode(JIRATicket.self, forKey: .jiraTicket)
        }

        if let prKind = try container.decodeIfPresent(PullRequestKind.self, forKey: .prKind), prKind == .gitHub {
            pullRequest = try container.decode(GitHubPullRequest.self, forKey: .gitHubPR)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(projectURL?.path, forKey: .projectURL)
        
        try container.encodeIfPresent(ticket?.kind, forKey: .ticketKind)
        try container.encodeIfPresent(ticket as? JIRATicket, forKey: .jiraTicket)
        try container.encodeIfPresent(pullRequest?.kind, forKey: .prKind)
        try container.encodeIfPresent(pullRequest as? GitHubPullRequest, forKey: .gitHubPR)
    }
}
