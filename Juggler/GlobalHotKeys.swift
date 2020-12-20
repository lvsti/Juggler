//
//  GlobalHotKeys.swift
//  Juggler
//
//  Created by Tamas Lustyik on 2020. 12. 20..
//  Copyright © 2020. Tamas Lustyik. All rights reserved.
//

import Foundation
import Carbon

protocol HotKeyBinding {}

private struct Context {
    let hotKeyID: EventHotKeyID
    let handler: () -> Void
}

private struct Binding: HotKeyBinding {
    let ref: EventHotKeyRef
    let context: UnsafeMutablePointer<Context>
}

enum GlobalHotKeys {
    private static func carbonEventFlags(from cocoaFlags: NSEvent.ModifierFlags) -> UInt32 {
        var newFlags: Int = 0

        if cocoaFlags.contains(.control) {
            newFlags |= controlKey
        }

        if cocoaFlags.contains(.command) {
            newFlags |= cmdKey
        }

        if cocoaFlags.contains(.shift) {
            newFlags |= shiftKey;
        }

        if cocoaFlags.contains(.option) {
            newFlags |= optionKey
        }

        if cocoaFlags.contains(.capsLock) {
            newFlags |= alphaLock
        }

        return UInt32(newFlags)
    }

    static func addHandler(for keyCode: Int, modifiers: NSEvent.ModifierFlags, handler: @escaping () -> Void) -> HotKeyBinding? {
        var hotKeyID = EventHotKeyID()
        hotKeyID.id = UInt32(keyCode)
        // Not sure what "swat" vs "htk1" do.
        hotKeyID.signature = OSType("swat".fourCharCodeValue)

        var hotKeyRef: EventHotKeyRef?
        guard RegisterEventHotKey(UInt32(keyCode),
                                  carbonEventFlags(from: modifiers),
                                  hotKeyID,
                                  GetApplicationEventTarget(),
                                  0,
                                  &hotKeyRef) == noErr, hotKeyRef != nil
        else { return nil }

        let ctx = UnsafeMutablePointer<Context>.allocate(capacity: 1)
        ctx.initialize(to: Context(hotKeyID: hotKeyID, handler: handler))

        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyReleased)

        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            var hkID = EventHotKeyID()

            guard GetEventParameter(event,
                                    EventParamName(kEventParamDirectObject),
                                    EventParamType(typeEventHotKeyID),
                                    nil,
                                    MemoryLayout<EventHotKeyID>.size,
                                    nil,
                                    &hkID) == noErr
            else { return OSStatus(eventNotHandledErr) }

            guard let ctx = userData?.assumingMemoryBound(to: Context.self),
                  ctx.pointee.hotKeyID.signature == hkID.signature
            else {
                return OSStatus(eventNotHandledErr)
            }
            ctx.pointee.handler()

            return noErr
        }, 1, &eventType, ctx, nil)
        guard status == noErr else { return nil }

        return Binding(ref: hotKeyRef!, context: ctx)
    }
}

extension String {
    var fourCharCodeValue: Int {
        var result: Int = 0
        if let data = data(using: .macOSRoman) {
            data.withUnsafeBytes { rawBytes in
                let bytes = rawBytes.bindMemory(to: UInt8.self)
                for i in 0 ..< data.count {
                    result = (result << 8) | Int(bytes[i])
                }
            }
        }
        return result
    }
}
