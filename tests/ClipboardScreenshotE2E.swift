import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

private struct ItemSnapshot {
    let values: [(NSPasteboard.PasteboardType, Data)]
}

private let pasteboard = NSPasteboard.general
private let snapshot = (pasteboard.pasteboardItems ?? []).map { item in
    ItemSnapshot(values: item.types.compactMap { type in
        item.data(forType: type).map { (type, $0) }
    })
}

let source = CGEventSource(stateID: .hidSystemState)
let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_F13), keyDown: true)!
let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_F13), keyDown: false)!
for event in [down, up] {
    event.flags = [.maskControl, .maskSecondaryFn]
}
down.post(tap: .cgSessionEventTap)
usleep(80_000)
up.post(tap: .cgSessionEventTap)
sleep(3)

let capturedTypes = Set((pasteboard.pasteboardItems ?? []).flatMap(\.types))
let capturedImage = capturedTypes.contains(.tiff) || capturedTypes.contains(.png)

pasteboard.clearContents()
let restored = snapshot.map { saved -> NSPasteboardItem in
    let item = NSPasteboardItem()
    for (type, data) in saved.values { item.setData(data, forType: type) }
    return item
}
if !restored.isEmpty { pasteboard.writeObjects(restored) }

print(capturedImage ? "PASS ctrl+print_screen copied an image and restored clipboard" : "FAIL ctrl+print_screen did not copy an image")
exit(capturedImage ? 0 : 1)
