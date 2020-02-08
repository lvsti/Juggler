//
//  GitHubPreferencesViewController.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 09..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Cocoa

protocol GitHubPreferencesViewDelegate: class {
    var gitHubAPIToken: String { get }
    var gitHubTicketIDPattern: String { get }
    var gitHubNewPRTitlePattern: String { get }
    var gitHubNewPRBranchName: String { get }
    func gitHubPreferencesDidChangeAPIToken(to token: String)
    func gitHubPreferencesDidChangeTicketIDPattern(to pattern: String)
    func gitHubPreferencesDidChangeNewPRTitlePattern(to pattern: String)
    func gitHubPreferencesDidChangeNewPRBranch(to branchName: String)
}

final class GitHubPreferencesViewController: NSViewController {
    
    @IBOutlet private weak var gitHubAPITokenField: NSTextField!
    @IBOutlet private weak var gitHubTicketIDPatternField: NSTextField!
    @IBOutlet private weak var gitHubNewPRTitlePatternField: NSTextField!
    @IBOutlet private weak var gitHubNewPRBranchField: NSTextField!

    weak var delegate: GitHubPreferencesViewDelegate?
    
    override var nibName: NSNib.Name? {
        return "GitHubPreferencesView"
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        gitHubAPITokenField.stringValue = delegate?.gitHubAPIToken ?? ""
        gitHubTicketIDPatternField.stringValue = delegate?.gitHubTicketIDPattern ?? ""
        gitHubNewPRTitlePatternField.stringValue = delegate?.gitHubNewPRTitlePattern ?? ""
        gitHubNewPRBranchField.stringValue = delegate?.gitHubNewPRBranchName ?? ""
    }
    
    @IBAction private func gitHubAPITokenChanged(_ sender: Any) {
        delegate?.gitHubPreferencesDidChangeAPIToken(to: gitHubAPITokenField.stringValue)
    }

    @IBAction private func gitHubTicketIDPatternChanged(_ sender: Any) {
        delegate?.gitHubPreferencesDidChangeTicketIDPattern(to: gitHubTicketIDPatternField.stringValue)
        gitHubTicketIDPatternField.stringValue = delegate?.gitHubTicketIDPattern ?? ""
    }

    @IBAction private func gitHubNewPRTitlePatternChanged(_ sender: Any) {
        delegate?.gitHubPreferencesDidChangeNewPRTitlePattern(to: gitHubNewPRTitlePatternField.stringValue)
        gitHubNewPRTitlePatternField.stringValue = delegate?.gitHubNewPRTitlePattern ?? ""
    }

    @IBAction private func gitHubNewPRBranchChanged(_ sender: Any) {
        delegate?.gitHubPreferencesDidChangeNewPRTitlePattern(to: gitHubNewPRBranchField.stringValue)
        gitHubNewPRBranchField.stringValue = delegate?.gitHubNewPRBranchName ?? ""
    }

    @IBAction private func gitHubSetUpTokensLinkClicked(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://github.com/settings/tokens")!)
    }

}
