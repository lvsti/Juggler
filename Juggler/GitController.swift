//
//  GitRepository.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 01..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Foundation

enum Git {
    struct Branch {
        let name: String
    }

    struct WorkingCopyStatus {
        let folderURL: URL
        let hasLocalChanges: Bool
        let currentBranch: Branch?
    }
}


class GitController {
    private let gitURL: URL
    private let fileManager: FileManager
    
    init(gitURL: URL, fileManager: FileManager) {
        self.gitURL = gitURL
        self.fileManager = fileManager
    }
    
    func workingCopyStatus(at folderURL: URL) -> Git.WorkingCopyStatus? {
        guard gitFolderExists(in: folderURL) else {
            return Git.WorkingCopyStatus(folderURL: folderURL, hasLocalChanges: false, currentBranch: nil)
        }
        
        return Git.WorkingCopyStatus(folderURL: folderURL,
                                     hasLocalChanges: hasLocalChanges(in: folderURL),
                                     currentBranch: try? currentBranch(in: folderURL))
    }
    
    func setCurrentBranchForWorkingCopy(at folderURL: URL, toExisting branch: Git.Branch) throws {
        try executeGitCommand("checkout", args: [branch.name], in: folderURL)
    }
    
    func resetWorkingCopy(at folderURL: URL) throws {
        try executeGitCommand("reset", args: ["--hard"], in: folderURL)
    }
    
    func fetchAllRemotesForWorkingCopy(at folderURL: URL) throws {
        try executeGitCommand("fetch", args: ["origin"], in: folderURL)
    }
    
    func pullCurrentBranchForWorkingCopy(at folderURL: URL) throws {
        guard let branch = try currentBranch(in: folderURL) else {
            // nothing to pull on HEAD
            return
        }
        try executeGitCommand("pull", args: ["origin", branch.name], in: folderURL)
    }

    private func gitFolderExists(in folderURL: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: folderURL.appendingPathComponent(".git").path,
                                      isDirectory: &isDirectory) && isDirectory.boolValue
    }
    
    private func hasLocalChanges(in folderURL: URL) -> Bool {
        guard let changes = try? executeGitCommand("status", args: ["--porcelain", "-uno"], in: folderURL) else {
            return false
        }
        
        for change in changes.split(separator: "\n", omittingEmptySubsequences: true) {
            if change.hasPrefix(" M ") {
                return true
            }
        }
        
        return false
    }
    
    private func currentBranch(in folderURL: URL) throws -> Git.Branch? {
        let branchName = try executeGitCommand("symbolic-ref", args: ["HEAD", "-q", "--short"], in: folderURL)
        return branchName.isEmpty ? nil : Git.Branch(name: branchName)
    }
    
    @discardableResult
    private func executeGitCommand(_ command: String, args: [String], in folderURL: URL) throws -> String {
        return try shell("bash", args: ["-c", "cd \"\(folderURL.path)\" ; \"\(gitURL.path)\" \(command) \(args.joined(separator: " "))"])
    }
}
