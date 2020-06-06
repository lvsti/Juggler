//
//  HooksController.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2020. 05. 24..
//  Copyright © 2020. Tamas Lustyik. All rights reserved.
//

import Foundation

final class HooksController {
    
    private let fileManager: FileManager
    private let xcodeController: XcodeController
    
    init(fileManager: FileManager, xcodeController: XcodeController) {
        self.fileManager = fileManager
        self.xcodeController = xcodeController
    }
        
    func newPullRequestTitle(for workspace: Workspace) -> String? {
        guard let ticket = workspace.ticket else {
            return nil
        }
        
        let scriptURL = hooksFolderURL(for: workspace).appendingPathComponent("ticket-new-pr-title.sh")
        let envVars = commonEnvVars(for: workspace).merging(ticketEnvVars(for: ticket), uniquingKeysWith: { $1 })

        return executeScript(scriptURL, inFolder: workspace.folderURL, withEnvVars: envVars)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func newPullRequestBody(for workspace: Workspace) -> String? {
        guard let ticket = workspace.ticket else {
            return nil
        }
        
        let scriptURL = hooksFolderURL(for: workspace).appendingPathComponent("ticket-new-pr-body.sh")
        let envVars = commonEnvVars(for: workspace).merging(ticketEnvVars(for: ticket), uniquingKeysWith: { $1 })
        
        return executeScript(scriptURL, inFolder: workspace.folderURL, withEnvVars: envVars)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func hooksFolderURL(for workspace: Workspace) -> URL {
        return workspace.folderURL.deletingLastPathComponent().appendingPathComponent(".juggler")
    }
    
    private func commonEnvVars(for workspace: Workspace) -> [String: String] {
        return [
            "WORKSPACE_DIR": workspace.folderURL.path,
            "PROJECT_PATH": workspace.projectURL?.path ?? "",
            "DERIVED_DATA_DIR": workspace.projectURL != nil ? xcodeController.derivedDataFolderURLs(forProjectAt: workspace.projectURL!).first?.path ?? "" : "",
        ]
    }
    
    private func ticketEnvVars(for ticket: Ticket) -> [String: String] {
        return [
            "TICKET_ID": ticket.id,
            "TICKET_TITLE": ticket.title ?? "",
            "TICKET_URL": ticket.url.absoluteString
        ]
    }
    
    private func pullRequestEnvVars(for pr: PullRequest) -> [String: String] {
        return [
            "PR_ID": pr.id,
            "PR_TITLE": pr.title ?? "",
            "PR_URL": pr.url.absoluteString,
            "PR_SOURCE_BRANCH": pr.sourceBranch.name,
            "PR_TARGET_BRANCH": pr.targetBranch.name
        ]
    }

    private func executeScript(_ scriptURL: URL, inFolder folderURL: URL, withEnvVars envVars: [String: String]) -> String? {
        guard fileManager.fileExists(atPath: scriptURL.path) else {
            return nil
        }

        let envStr = envVars.map { $0.key + "=\"" + $0.value + "\""}.joined(separator: " ")
        return try? shell("/bin/bash", args: ["-l", "-c", "cd \"\(folderURL.path)\" ; " + envStr + " " + scriptURL.path])
    }
}
