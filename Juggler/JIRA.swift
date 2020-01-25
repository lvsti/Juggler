//
//  JIRATicket.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 01..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Foundation
import Security

struct JIRATicket: Ticket, Codable {
    var kind: TicketKind { return .jira }
    let id: String
    let title: String?
    let url: URL
}

final class JIRADataProvider {
    private static let jiraBaseURLKey = "JIRABaseURL"
    private static let jiraKeychainItemLabel = "JIRA API Access"
    private static let jiraKeychainItemService = "me.cocoagrinder.Juggler.JIRA"

    private let userDefaults: UserDefaults
    private let keychainManager: KeychainManager

    private var credentials: KeychainManager.Credentials? {
        didSet {
            if let credentials = credentials {
                keychainManager.setCredentials(credentials,
                                               forService: JIRADataProvider.jiraKeychainItemService,
                                               label: JIRADataProvider.jiraKeychainItemLabel)
            }
        }
    }
    
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
        get { return credentials?.account }
        set {
            if credentials != nil {
                credentials?.account = newValue ?? ""
            }
            else if newValue != nil {
                credentials = KeychainManager.Credentials(account: newValue!, secret: "")
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
                credentials = KeychainManager.Credentials(account: "", secret: newValue!)
            }
        }
    }

    init(userDefaults: UserDefaults, keychainManager: KeychainManager) {
        self.userDefaults = userDefaults
        self.keychainManager = keychainManager
        self.credentials = keychainManager.credentials(forService: JIRADataProvider.jiraKeychainItemService)
    }
    
    func ticketURL(for ticketID: String) -> URL {
        return baseURL.appendingPathComponent("browse").appendingPathComponent(ticketID)
    }

    func ticketID(from url: URL) -> String? {
        guard url.host == baseURL.host else {
            return nil
        }
        
        if url.pathComponents.dropLast() == ["/", "browse"] {
            return url.lastPathComponent
        }
        
        return URLComponents(url: url, resolvingAgainstBaseURL: true)?
            .queryItems?
            .first(where: { $0.name == "selectedIssue" })?
            .value
    }
    
    func fetchTicket(for ticketID: String, completion: @escaping (JIRATicket?, Error?) -> Void) {
        guard
            let user = credentials?.account, !user.isEmpty,
            let token = credentials?.secret, !token.isEmpty,
            let requestURL = URL(string: "https://shapr3d.atlassian.net/rest/api/latest/issue/\(ticketID)?fields=summary")
        else {
            DispatchQueue.main.async {
                completion(nil, nil)
            }
            return
        }
        
        var request = URLRequest(url: requestURL)
        let credentials = "\(user):\(token)".data(using: .utf8)!.base64EncodedString()
        request.addValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let task = session.dataTask(with: request) { data, response, error in
            guard
                let data = data,
                let result = try? JSONDecoder().decode(JIRAGetIssueResult.self, from: data)
            else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            let ticket = JIRATicket(id: ticketID,
                                    title: result.fields.summary,
                                    url: self.ticketURL(for: result.key))
            DispatchQueue.main.async {
                completion(ticket, nil)
            }
        }
        task.resume()
    }
}

private struct JIRAGetIssueResult: Decodable {
    struct Fields: Decodable {
        let summary: String
    }
    
    let key: String
    let fields: Fields
}
