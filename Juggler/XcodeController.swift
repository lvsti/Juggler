//
//  XcodeController.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 15..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Cocoa

final class XcodeController {
    private static let xcodeAppPathKey = "XcodeAppPath"
    
    private let scriptingBridge: ScriptingBridge
    private let userDefaults: UserDefaults
    private let fileManager: FileManager
    
    var appPath: String {
        get {
            return userDefaults.string(forKey: XcodeController.xcodeAppPathKey) ?? "/Applications/Xcode.app"
        }
        set {
            userDefaults.set(newValue, forKey: XcodeController.xcodeAppPathKey)
        }
    }
    
    init(scriptingBridge: ScriptingBridge, userDefaults: UserDefaults, fileManager: FileManager) {
        self.scriptingBridge = scriptingBridge
        self.userDefaults = userDefaults
        self.fileManager = fileManager
    }
    
    func focusOnProject(at projectURL: URL) {
        if scriptingBridge.requestPermissionsToAutomateXcode() {
            scriptingBridge.closeAllXcodeProjects(except: projectURL.path, withXcodeAt: appPath)
        }
        
        NSWorkspace.shared.openFile(projectURL.path, withApplication: appPath)
    }
    
    func removeUserData(forProjectAt url: URL) {
        let urls: [URL]
        if isWorkspaceURL(url) {
            urls = containedProjectURLs(forWorkspaceAt: url)
        }
        else {
            urls = [url]
        }
        
        for url in urls {
            do {
                try fileManager.removeItem(at: url.appendingPathComponent("xcuserdata"))
            }
            catch {
            }
        }
    }

    func derivedDataFolderURLs(forProjectAt projectURL: URL) -> [URL] {
        guard let libraryFolderURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return []
        }
        
        let derivedDataFolderURL = libraryFolderURL.appendingPathComponent("Developer/Xcode/DerivedData")
        let enumerator = fileManager.enumerator(at: derivedDataFolderURL,
                                                includingPropertiesForKeys: [],
                                                options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants])!

        var folderURLs: [URL] = []
        for entry in enumerator {
            guard
                let url = entry as? URL,
                let infoPlistData = try? Data(contentsOf: url.appendingPathComponent("info.plist")),
                let plist = try? PropertyListSerialization.propertyList(from: infoPlistData, options: [], format: nil) as? [String: Any],
                let wsPath = plist["WorkspacePath"] as? String,
                wsPath == projectURL.path
            else {
                continue
            }
            
            folderURLs.append(url)
        }
        
        return folderURLs
    }
    
    func removeDerivedData(forProjectAt projectURL: URL) {
        let folderURLs = derivedDataFolderURLs(forProjectAt: projectURL)
        for url in folderURLs {
            do {
                try fileManager.removeItem(at: url)
            }
            catch {
            }
        }
    }
    
    private func isWorkspaceURL(_ url: URL) -> Bool {
        return url.pathExtension == "xcworkspace"
    }
    
    private func containedProjectURLs(forWorkspaceAt url: URL) -> [URL] {
        let wsDataURL = url.appendingPathComponent("contents.xcworkspacedata")
        guard
            fileManager.fileExists(atPath: wsDataURL.path),
            let xml = try? XMLDocument(contentsOf: wsDataURL, options: []),
            let projectRefs = try? xml.nodes(forXPath: "/Workspace/FileRef") as? [XMLElement]
        else {
            return []
        }
        
        let groupPrefix = "group:"
        var projectURLs: [URL] = []
        for ref in projectRefs {
            guard let loc = ref.attribute(forName: "location")?.stringValue, loc.hasPrefix(groupPrefix) else {
                continue
            }
            
            let projectURL = URL(fileURLWithPath: String(loc.dropFirst(groupPrefix.count)), relativeTo: url.deletingLastPathComponent())
            projectURLs.append(projectURL)
        }
        
        return projectURLs
    }
}
