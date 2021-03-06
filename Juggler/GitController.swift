//
//  GitRepository.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 01..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Foundation

enum Git {
    struct Commit: Equatable {
        let sha: String
    }
    
    struct Branch: Equatable {
        let name: String
    }
    
    enum Ref: CustomStringConvertible {
        case branch(Branch)
        case commit(Commit)
        
        var description: String {
            switch self {
            case .branch(let branch): return branch.name
            case .commit(let commit): return commit.sha
            }
        }
    }
    
    enum ResetMode: String {
        case hard = "--hard", mixed = "--mixed"
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
    
    struct LocalChange {
        enum ChangeType: String {
            case added = "A", deleted = "D", modified = "M", untracked = "??"
        }
        let type: ChangeType
        let path: String
    }
    
    struct WorkingCopyStatus {
        let folderURL: URL
        let localChanges: [LocalChange]
        let currentBranch: Branch?
        let remote: Remote?
    }
}

extension Git.Remote: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(repoURI)
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
                                     localChanges: (try? localChanges(in: folderURL)) ?? [],
                                     currentBranch: try? currentBranch(in: folderURL),
                                     remote: try? remote(in: folderURL))
    }
    
    func setCurrentBranchForWorkingCopy(at folderURL: URL, toExisting branch: Git.Branch) throws {
        try executeGitCommand("checkout", args: [branch.name], in: folderURL)
    }

    func createBranchForWorkingCopy(at folderURL: URL, branchName: String) throws -> Git.Branch {
        try executeGitCommand("branch", args: [branchName], in: folderURL)
        return Git.Branch(name: branchName)
    }

    func forkPoint(at folderURL: URL, of branchRef: Git.Ref, relativeTo parentRef: Git.Ref) throws -> Git.Ref {
        let result = try executeGitCommand("merge-base",
                                           args: [parentRef.description, branchRef.description],
                                           in: folderURL)
        return .commit(Git.Commit(sha: result))
    }
    
    func resetWorkingCopy(at folderURL: URL, to ref: Git.Ref? = nil, inMode mode: Git.ResetMode) throws {
        try executeGitCommand("reset", args: [mode.rawValue] + (ref != nil ? [ref!.description] : []), in: folderURL)
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
    
    func removeUntrackedFiles(at folderURL: URL) throws {
        try executeGitCommand("clean", args: ["-f", "-d"], in: folderURL)
    }
    
    func pushCurrentBranchForWorkingCopy(at folderURL: URL) throws {
        guard let branch = try currentBranch(in: folderURL) else {
            return
        }
        try executeGitCommand("push", args: ["origin", branch.name], in: folderURL)
    }
    
    func deleteBranchForWorkingCopy(at folderURL: URL, branch: Git.Branch) throws {
        try executeGitCommand("branch", args: ["-D", branch.name], in: folderURL)
    }

    private func gitFolderExists(in folderURL: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: folderURL.appendingPathComponent(".git").path,
                                      isDirectory: &isDirectory) && isDirectory.boolValue
    }
    
    private func localChanges(in folderURL: URL) throws -> [Git.LocalChange] {
        let changeList = try executeGitCommand("status", args: ["--porcelain", "-uno", "--ignore-submodules"], in: folderURL)
        
        var changes: [Git.LocalChange] = []
        changeList.enumerateLines { (line, _) in
            let fields = line.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
            guard
                fields.count == 2,
                let typeField = fields.first,
                let path = fields.last,
                let type = Git.LocalChange.ChangeType(rawValue: typeField)
            else {
                return
            }
            changes.append(Git.LocalChange(type: type, path: path))
        }
        
        return changes
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
        return try shell("/bin/bash", args: ["-l", "-c", "cd \"\(folderURL.path)\" ; \"\(gitURL.path)\" \(command) \(args.joined(separator: " "))"])
    }
}
