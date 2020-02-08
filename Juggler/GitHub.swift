//
//  GitHubPullRequest.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 01..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Foundation

struct GitHubPullRequest: PullRequest {
    var kind: PullRequestKind { return .gitHub }
    let id: String
    let title: String?
    let url: URL
    let remote: Git.Remote
    let sourceBranch: Git.Branch
    let targetBranch: Git.Branch
}

extension GitHubPullRequest: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, title, url, remote, source, target
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
       
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        
        let urlStr = try container.decode(String.self, forKey: .url)
        guard let url = URL(string: urlStr) else {
            throw DecodingError.dataCorruptedError(forKey: .url, in: container, debugDescription: "invalid URL")
        }
        self.url = url
        
        guard let remote = Git.Remote(repoURI: try container.decode(String.self, forKey: .remote)) else {
            throw DecodingError.dataCorruptedError(forKey: .remote, in: container, debugDescription: "invalid remote")
        }
        self.remote = remote
        
        sourceBranch = Git.Branch(name: try container.decode(String.self, forKey: .source))
        targetBranch = Git.Branch(name: try container.decode(String.self, forKey: .target))
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encode(url.absoluteString, forKey: .url)
        try container.encode(remote.repoURI, forKey: .remote)
        try container.encode(sourceBranch.name, forKey: .source)
        try container.encode(targetBranch.name, forKey: .target)
    }
}

final class GitHubDataProvider {
    private static let gitHubKeychainItemLabel = "GitHub API Access"
    private static let gitHubKeychainItemService = "me.cocoagrinder.Juggler.GitHub"
    private static let gitHubTicketIDFromPRTitlePatternKey = "GitHubTicketIDFromPRTitlePattern"
    private static let gitHubIntegrationBranchKey = "GitHubIntegrationBranch"
    private static let gitHubNewPRTitlePatternKey = "GitHubNewPRTitlePattern"

    private let userDefaults: UserDefaults
    private let keychainManager: KeychainManager
    
    private var credentials: KeychainManager.Credentials? {
        didSet {
            if let credentials = credentials {
                keychainManager.setCredentials(credentials,
                                               forService: GitHubDataProvider.gitHubKeychainItemService,
                                               label: GitHubDataProvider.gitHubKeychainItemLabel)
            }
        }
    }
    
    var apiToken: String? {
        get { return credentials?.secret }
        set {
            if credentials != nil {
                credentials?.secret = newValue ?? ""
            }
            else if newValue != nil {
                credentials = KeychainManager.Credentials(account: "OAuth", secret: newValue!)
            }
        }
    }
    
    var integrationBranch: Git.Branch {
        get { return Git.Branch(name: userDefaults.string(forKey: GitHubDataProvider.gitHubIntegrationBranchKey) ?? "master") }
        set { userDefaults.set(newValue.name, forKey: GitHubDataProvider.gitHubIntegrationBranchKey) }
    }
    
    var newPRTitlePattern: String? {
        get { return userDefaults.string(forKey: GitHubDataProvider.gitHubNewPRTitlePatternKey) }
        set { userDefaults.set(newValue, forKey: GitHubDataProvider.gitHubNewPRTitlePatternKey) }
    }
    
    private var _ticketIDFromPRTitleRegex: NSRegularExpression?
    var ticketIDFromPRTitleRegex: NSRegularExpression? {
        return _ticketIDFromPRTitleRegex
    }
    
    var ticketIDFromPRTitlePattern: String? {
        get { return userDefaults.string(forKey: GitHubDataProvider.gitHubTicketIDFromPRTitlePatternKey) }
        set {
            guard
                let newPattern = newValue,
                let regex = try? NSRegularExpression(pattern: newPattern, options: []),
                regex.numberOfCaptureGroups == 1
            else {
                _ticketIDFromPRTitleRegex = nil
                userDefaults.removeObject(forKey: GitHubDataProvider.gitHubTicketIDFromPRTitlePatternKey)
                return
            }
            
            userDefaults.set(newPattern, forKey: GitHubDataProvider.gitHubTicketIDFromPRTitlePatternKey)
            _ticketIDFromPRTitleRegex = regex
        }
    }

    init(userDefaults: UserDefaults, keychainManager: KeychainManager) {
        self.userDefaults = userDefaults
        self.keychainManager = keychainManager
        self.credentials = keychainManager.credentials(forService: GitHubDataProvider.gitHubKeychainItemService)
        
        if let pattern = ticketIDFromPRTitlePattern {
            ticketIDFromPRTitlePattern = pattern
        }
    }

    func pullRequestURL(for prID: String, in remote: Git.Remote) -> URL {
        return URL(string: "https://github.com")!
            .appendingPathComponent(remote.orgName)
            .appendingPathComponent(remote.repoName)
            .appendingPathComponent("pull")
            .appendingPathComponent(prID)
    }
    
    func pullRequestID(from url: URL, in remote: Git.Remote) -> String? {
        guard
            url.host == "github.com",
            url.pathComponents.starts(with: ["/", remote.orgName, remote.repoName, "pull"]),
            url.pathComponents.count >= 5,
            Int(url.pathComponents[4]) != nil
        else {
            return nil
        }
        
        return url.pathComponents[4]
    }
    
    func fetchPullRequest(for prID: String, in remote: Git.Remote, completion: @escaping (GitHubPullRequest?, Error?) -> Void) {
        guard
            let token = credentials?.secret, !token.isEmpty,
            let requestURL = URL(string: "https://api.github.com/repos/\(remote.orgName)/\(remote.repoName)/pulls/\(prID)")
        else {
            completion(nil, nil)
            return
        }
        
        var request = URLRequest(url: requestURL)
        request.addValue("Token \(token)", forHTTPHeaderField: "Authorization")
        
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let task = session.dataTask(with: request) { data, response, error in
            guard
                let data = data,
                let result = try? JSONDecoder().decode(GitHubGetPullRequestResult.self, from: data)
            else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            let pr = GitHubPullRequest(id: prID,
                                       title: result.title,
                                       url: self.pullRequestURL(for: prID, in: remote),
                                       remote: remote,
                                       sourceBranch: Git.Branch(name: result.head.ref),
                                       targetBranch: Git.Branch(name: result.base.ref))
            DispatchQueue.main.async {
                completion(pr, nil)
            }
        }
        task.resume()
    }
}

private struct GitHubGetPullRequestResult: Decodable {
    struct BaseSection: Decodable {
        let ref: String
    }
    
    struct HeadSection: Decodable {
        let ref: String
    }
    
    let number: Int
    let title: String
    let base: BaseSection
    let head: HeadSection
}

