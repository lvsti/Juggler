//
//  JIRAPreferencesViewController.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 09..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Cocoa

protocol JIRAPreferencesViewDelegate: class {
    var jiraBaseURL: URL { get }
    var jiraUserName: String { get }
    var jiraAPIToken: String { get }
    func jiraPreferencesDidChangeBaseURL(to url: URL)
    func jiraPreferencesDidChangeUserName(to userName: String)
    func jiraPreferencesDidChangeAPIToken(to token: String)
}

final class JIRAPreferencesViewController: NSViewController {
    
    @IBOutlet weak var jiraBaseURLField: NSTextField!
    @IBOutlet weak var jiraUserNameField: NSTextField!
    @IBOutlet weak var jiraAPITokenField: NSTextField!

    weak var delegate: JIRAPreferencesViewDelegate?
    
    override var nibName: NSNib.Name? {
        return "JIRAPreferencesView"
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        jiraBaseURLField.stringValue = delegate?.jiraBaseURL.absoluteString ?? ""
        jiraUserNameField.stringValue = delegate?.jiraUserName ?? ""
        jiraAPITokenField.stringValue = delegate?.jiraAPIToken ?? ""
    }
    
    @IBAction private func jiraBaseURLChanged(_ sender: Any) {
        if let url = URL(string: jiraBaseURLField.stringValue) {
            delegate?.jiraPreferencesDidChangeBaseURL(to: url)
        }
    }

    @IBAction private func jiraUserNameChanged(_ sender: Any) {
        delegate?.jiraPreferencesDidChangeUserName(to: jiraUserNameField.stringValue)
    }

    @IBAction private func jiraAPITokenChanged(_ sender: Any) {
        delegate?.jiraPreferencesDidChangeAPIToken(to: jiraAPITokenField.stringValue)
    }

    @IBAction private func jiraSetUpTokensLinkClicked(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://id.atlassian.com/manage/api-tokens")!)
    }

}
