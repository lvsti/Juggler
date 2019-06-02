//
//  JIRATicket.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 01..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Foundation

struct JIRATicket: Ticket {
    var kind: TicketKind { return .jira }
    let id: String
    let title: String?
    let url: URL
}

class JIRAURLProvider {
    private let userDefaults: UserDefaults
    private static let jiraBaseURLKey = "JIRABaseURL"
    
    var baseURL: URL {
        get {
            guard var baseURLStr = userDefaults.string(forKey: JIRAURLProvider.jiraBaseURLKey) else {
                return URL(string: "https://example.com/")!
            }
            
            if !baseURLStr.hasPrefix("https://") && !baseURLStr.hasPrefix("http://") {
                baseURLStr = "https://" + baseURLStr
            }
            
            guard let url = URL(string: baseURLStr) else {
                return URL(string: "https://example.com/")!
            }

            return url
        }
        set {
            if newValue.scheme != "https" && newValue.scheme != "http" {
                return
            }
            
            userDefaults.set(newValue.absoluteString, forKey: JIRAURLProvider.jiraBaseURLKey)
        }
    }
    
    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }
    
    func ticketURL(for ticketID: String) -> URL {
        return baseURL.appendingPathComponent("browse").appendingPathComponent(ticketID)
    }
}

