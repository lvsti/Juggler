//
//  MenuController.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 01..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Foundation
import AppKit

class MenuController: NSObject, NSMenuDelegate {
    // dependencies
    private let menu: NSMenu

    // state
    private var menuItems: [NSMenuItem]
    
    init(menu: NSMenu) {
        self.menu = menu
        
        menuItems = []
        
        super.init()
        
        menu.delegate = self
    }
    
    private func rebuildMenu() {
        menuItems.removeAll(keepingCapacity: true)
        
        menuItems.append(NSMenuItem.separator())
        menuItems.append(NSMenuItem(title: "Quit Juggler", keyEquivalent: "q") { _ in
            NSApplication.shared.terminate(nil)
        })
    }
    
    private func renderMenu() {
        menu.removeAllItems()
        for item in menuItems {
            menu.addItem(item)
        }
    }

//    private func menuItemForService(service: NetService) -> NSMenuItem {
//        let menuItem = NSMenuItem(title: service.name) { [unowned self] _ in
//            guard let pasteboardItem = self.pasteboardController.currentItem else {
//                return
//            }
//            let reps = self.pasteboardController.representationsForItem(item: pasteboardItem)
//            self.service.sendPasteboardItemsWithRepresentations(reps: [reps], to: service)
//        }
//
//        menuItem.indentationLevel = 1
//
//        return menuItem
//    }
//
    // MARK: - from NSMenuDelegate:
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu == self.menu else {
            return
        }

        rebuildMenu()
        renderMenu()
    }
    
}
