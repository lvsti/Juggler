//
//  Ticket.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 10..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Foundation

enum TicketKind: String, Codable {
    case jira
}

protocol Ticket {
    var kind: TicketKind { get }
    var id: String { get }
    var title: String? { get }
    var url: URL { get }
}

private let validGitBranchCharsRegex = try! NSRegularExpression(pattern: "[^a-zA-Z0-9-_]", options: [])

extension Ticket {
    var preferredBranchName: String {
        if let title = title {
            let sanitizedTitle = validGitBranchCharsRegex.stringByReplacingMatches(in: title,
                                                                                   options: [],
                                                                                   range: NSRange(location: 0, length: title.count),
                                                                                   withTemplate: " ")
            let components = sanitizedTitle.lowercased().split(separator: " ")
            return "\(id)-" + components.joined(separator: "-")
        }
        return id
    }
}
