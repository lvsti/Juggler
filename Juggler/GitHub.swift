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
    var title: String
    var url: URL
}

class GitHubURLProvider {
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
}

