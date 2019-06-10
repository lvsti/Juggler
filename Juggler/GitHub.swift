//
//  GitHubPullRequest.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 01..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Foundation

struct GitHubPullRequest: PullRequest {
    var kind: PullRequestKind { return .github }
    var id: String
    var title: String?
    var url: URL
}

final class GitHubDataProvider {
    private static let gitHubKeychainItemLabel = "GitHub API Access"
    private static let gitHubKeychainItemService = "me.cocoagrinder.Juggler.GitHub"

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

    init(keychainManager: KeychainManager) {
        self.keychainManager = keychainManager
        self.credentials = keychainManager.credentials(forService: GitHubDataProvider.gitHubKeychainItemService)
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
            url.pathComponents.dropLast() == ["/", remote.orgName, remote.repoName, "pull"],
            Int(url.lastPathComponent) != nil
        else {
            return nil
        }
        
        return url.lastPathComponent
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
                completion(nil, error)
                return
            }
            
            let pr = GitHubPullRequest(id: prID,
                                       title: result.title,
                                       url: self.pullRequestURL(for: prID, in: remote))
            completion(pr, nil)
        }
        task.resume()
    }
}

private struct GitHubGetPullRequestResult: Decodable {
    let number: Int
    let title: String
}

