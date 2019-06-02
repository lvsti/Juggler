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
            .appendingPathComponent(prID)
    }
}
