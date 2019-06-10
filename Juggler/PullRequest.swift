//
//  PullRequest.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 10..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Foundation

enum PullRequestKind: String, Codable {
    case gitHub
}

protocol PullRequest {
    var kind: PullRequestKind { get }
    var id: String { get }
    var title: String? { get }
    var url: URL { get }
    var remote: Git.Remote { get }
    var sourceBranch: Git.Branch { get }
    var targetBranch: Git.Branch { get }
}
