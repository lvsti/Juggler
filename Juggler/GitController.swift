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
    
    struct Remote {
        enum URLKind {
            case ssh, https
        }

        private static let sshURIRegex = try! NSRegularExpression(pattern: #"^(?<user>[^@]+)@(?<host>[^:]+):(?<org>[^\/]+)\/(?<repo>[^\/]+)\.git$"#, options: [])
        private static let httpsURIRegex = try! NSRegularExpression(pattern: #"^https:\/\/(?<host>[^\/]+)\/(?<org>[^\/]+)\/(?<repo>[^\/]+)\.git$"#, options: [])

        let repoURI: String
        let urlKind: URLKind
        
        let userName: String?
        let host: String
        let orgName: String
        let repoName: String

        init?(repoURI: String) {
            self.repoURI = repoURI
            
            let uriMatch: NSTextCheckingResult?
            if repoURI.hasPrefix("https://") {
                urlKind = .https
                uriMatch = Remote.httpsURIRegex.firstMatch(in: repoURI, options: [], range: NSRange(location: 0, length: repoURI.count))
            }
            else {
                urlKind = .ssh
                uriMatch = Remote.sshURIRegex.firstMatch(in: repoURI, options: [], range: NSRange(location: 0, length: repoURI.count))
            }

            guard let match = uriMatch else {
                return nil
            }
            
            let userRange = match.range(withName: "user")
            if userRange.location != NSNotFound {
                userName = String(repoURI[Range(userRange, in: repoURI)!])
            }
            else {
                userName = nil
            }
            
            host = String(repoURI[Range(match.range(withName: "host"), in: repoURI)!])
            orgName = String(repoURI[Range(match.range(withName: "org"), in: repoURI)!])
            repoName = String(repoURI[Range(match.range(withName: "repo"), in: repoURI)!])
        }
    }
    
    struct WorkingCopyStatus {
        let folderURL: URL
        let hasLocalChanges: Bool
        let currentBranch: Branch?
        let remote: Remote?
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
            return nil
        }
        
        return Git.WorkingCopyStatus(folderURL: folderURL,
                                     hasLocalChanges: hasLocalChanges(in: folderURL),
                                     currentBranch: try? currentBranch(in: folderURL),
                                     remote: try? remote(in: folderURL))
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
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return branchName.isEmpty ? nil : Git.Branch(name: branchName)
    }
    
    private func remote(in folderURL: URL) throws -> Git.Remote? {
        let uri = try executeGitCommand("config", args: ["--get", "remote.origin.url"], in: folderURL)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return uri.isEmpty ? nil : Git.Remote(repoURI: uri)
    }
    
    @discardableResult
    private func executeGitCommand(_ command: String, args: [String], in folderURL: URL) throws -> String {
        return try shell("/bin/bash", args: ["-c", "cd \"\(folderURL.path)\" ; \"\(gitURL.path)\" \(command) \(args.joined(separator: " "))"])
    }
}
