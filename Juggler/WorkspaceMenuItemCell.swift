//
//  WorkspaceMenuItemCell.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2019. 06. 04..
//  Copyright © 2019. Tamas Lustyik. All rights reserved.
//

import Cocoa

final class WorkspaceMenuItemCell: NSVisualEffectView {
    @IBOutlet weak var badge: NSView!
    @IBOutlet weak var badgeTitle: NSTextField!
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var disclosureArrow: NSTextField!
    @IBOutlet weak var spinner: NSProgressIndicator!
    
    var color: NSColor? {
        didSet {
            let bgColor = color?.withAlphaComponent(0.8) ?? NSColor(calibratedWhite: 0.5, alpha: 0.8)
            badge.layer?.backgroundColor = bgColor.cgColor
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        badge.layer?.cornerRadius = 6
        badge.layer?.backgroundColor = NSColor(calibratedWhite: 0.5, alpha: 0.8).cgColor
    }
    
    override func draw(_ dirtyRect: NSRect) {
        isEmphasized = enclosingMenuItem?.isHighlighted ?? false
        material = isEmphasized ? .selection : .menu
        state = .active
        super.draw(dirtyRect)
    }
}
