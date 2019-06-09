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

final class JIRADataProvider {
    private let userDefaults: UserDefaults
    private static let jiraBaseURLKey = "JIRABaseURL"
    private static let jiraUserNameKey = "JIRAUserName"
    private static let jiraAPITokenKey = "JIRAAPIToken"
    
    var baseURL: URL {
        get {
            guard var baseURLStr = userDefaults.string(forKey: JIRADataProvider.jiraBaseURLKey) else {
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
            
            userDefaults.set(newValue.absoluteString, forKey: JIRADataProvider.jiraBaseURLKey)
        }
    }
    
    var userName: String? {
        get {
            return userDefaults.string(forKey: JIRADataProvider.jiraUserNameKey)
        }
        set {
            userDefaults.set(pUserName, forKey: JIRADataProvider.jiraUserNameKey)
        }
    }

    var apiToken: String? {
        get {
            return userDefaults.string(forKey: JIRADataProvider.jiraAPITokenKey)
        }
        set {
            userDefaults.set(pUserName, forKey: JIRADataProvider.jiraAPITokenKey)
        }
    }

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }
    
    func ticketURL(for ticketID: String) -> URL {
        return baseURL.appendingPathComponent("browse").appendingPathComponent(ticketID)
    }

    func ticketID(from url: URL) -> String? {
        guard url.host == baseURL.host, url.pathComponents.dropLast() == ["/", "browse"] else {
            return nil
        }
        
        return url.lastPathComponent
    }
    
    func fetchTicket(for ticketID: String, completion: @escaping (JIRATicket?, Error?) -> Void) {
        guard
            let user = userDefaults.string(forKey: JIRADataProvider.jiraUserNameKey),
            let token = userDefaults.string(forKey: JIRADataProvider.jiraAPITokenKey),
            let requestURL = URL(string: "https://shapr3d.atlassian.net/rest/api/latest/issue/\(ticketID)?fields=summary")
        else {
            completion(nil, nil)
            return
        }
        
        var request = URLRequest(url: requestURL)
        let credentials = "\(user):\(token)".data(using: .utf8)!.base64EncodedString()
        request.addValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        
        let session = URLSession()
        let task = session.dataTask(with: request) { data, response, error in
            guard
                let data = data,
                let result = try? JSONDecoder().decode(JIRAGetIssueResult.self, from: data)
            else {
                completion(nil, error)
                return
            }
            
            let ticket = JIRATicket(id: ticketID,
                                    title: result.fields["summary"],
                                    url: self.ticketURL(for: result.key))
            completion(ticket, nil)
        }
        task.resume()
    }
}

private struct JIRAGetIssueResult: Decodable {
    let key: String
    let fields: [String: String]
}
