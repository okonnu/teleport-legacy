import ApplicationServices
import Carbon.HIToolbox
import Foundation

let allLocations: [(String, CGEventTapLocation)] = [
    ("hid", .cghidEventTap),
    ("session", .cgSessionEventTap),
    ("annotated", .cgAnnotatedSessionEventTap),
]
let requested = CommandLine.arguments.dropFirst().first
let locations = allLocations.filter { requested == nil || $0.0 == requested }

for (name, location) in locations {
    let source = CGEventSource(stateID: .hidSystemState)
    let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_A), keyDown: true)!
    let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_A), keyDown: false)!
    down.flags = [.maskControl]
    up.flags = [.maskControl]
    down.post(tap: location)
    usleep(80_000)
    up.post(tap: location)
    print("posted ctrl+a at \(name)")
    sleep(1)
}
