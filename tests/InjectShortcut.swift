import ApplicationServices
import Carbon.HIToolbox
import Foundation

private let harnessMarker: Int64 = 0x54454C4553544552

private let shortcuts: [String: (CGKeyCode, CGEventFlags)] = [
    "ctrl-a": (CGKeyCode(kVK_ANSI_A), [.maskControl]),
    "ctrl-c": (CGKeyCode(kVK_ANSI_C), [.maskControl]),
    "win-e": (CGKeyCode(kVK_ANSI_E), [.maskCommand]),
    "print": (CGKeyCode(kVK_F13), [.maskSecondaryFn]),
    "shift-print": (CGKeyCode(kVK_F13), [.maskShift, .maskSecondaryFn]),
    "alt-print": (CGKeyCode(kVK_F13), [.maskAlternate, .maskSecondaryFn]),
    "ctrl-print": (CGKeyCode(kVK_F13), [.maskControl, .maskSecondaryFn]),
    "ctrl-shift-print": (CGKeyCode(kVK_F13), [.maskControl, .maskShift, .maskSecondaryFn]),
    "ctrl-alt-t": (CGKeyCode(kVK_ANSI_T), [.maskControl, .maskAlternate]),
    "ctrl-alt-m": (CGKeyCode(kVK_ANSI_M), [.maskControl, .maskAlternate]),
    "ctrl-alt-u": (CGKeyCode(kVK_ANSI_U), [.maskControl, .maskAlternate]),
]

guard CommandLine.arguments.count == 2,
      let shortcut = shortcuts[CommandLine.arguments[1]] else {
    fputs("Usage: InjectShortcut <\(shortcuts.keys.sorted().joined(separator: "|"))>\n", stderr)
    exit(2)
}

let source = CGEventSource(stateID: .hidSystemState)
let down = CGEvent(keyboardEventSource: source, virtualKey: shortcut.0, keyDown: true)!
let up = CGEvent(keyboardEventSource: source, virtualKey: shortcut.0, keyDown: false)!
for event in [down, up] {
    event.flags = shortcut.1
    event.setIntegerValueField(.eventSourceUserData, value: harnessMarker)
}
down.post(tap: .cgSessionEventTap)
usleep(80_000)
up.post(tap: .cgSessionEventTap)
