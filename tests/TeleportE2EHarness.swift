import ApplicationServices
import Carbon.HIToolbox
import Foundation

private let teleportMarker: Int64 = 0x54454C45504F5254
private let harnessMarker: Int64 = 0x54454C4553544552

private struct Chord {
    let key: CGKeyCode
    let flags: CGEventFlags
}

private struct TestCase {
    let name: String
    let source: Chord
    let target: Chord
}

private func chord(_ key: Int, _ flags: CGEventFlags = []) -> Chord {
    Chord(key: CGKeyCode(key), flags: flags)
}

private let ctrl: CGEventFlags = .maskControl
private let alt: CGEventFlags = .maskAlternate
private let cmd: CGEventFlags = .maskCommand
private let shift: CGEventFlags = .maskShift
private let fn: CGEventFlags = .maskSecondaryFn
private let relevant: CGEventFlags = [ctrl, alt, cmd, shift, fn]

private let tests: [TestCase] = [
    .init(name: "ctrl+a", source: chord(kVK_ANSI_A, ctrl), target: chord(kVK_ANSI_A, cmd)),
    .init(name: "ctrl+c", source: chord(kVK_ANSI_C, ctrl), target: chord(kVK_ANSI_C, cmd)),
    .init(name: "ctrl+v", source: chord(kVK_ANSI_V, ctrl), target: chord(kVK_ANSI_V, cmd)),
    .init(name: "ctrl+x", source: chord(kVK_ANSI_X, ctrl), target: chord(kVK_ANSI_X, cmd)),
    .init(name: "ctrl+z", source: chord(kVK_ANSI_Z, ctrl), target: chord(kVK_ANSI_Z, cmd)),
    .init(name: "ctrl+shift+z", source: chord(kVK_ANSI_Z, [ctrl, shift]), target: chord(kVK_ANSI_Z, [cmd, shift])),
    .init(name: "ctrl+f", source: chord(kVK_ANSI_F, ctrl), target: chord(kVK_ANSI_F, cmd)),
    .init(name: "ctrl+s", source: chord(kVK_ANSI_S, ctrl), target: chord(kVK_ANSI_S, cmd)),
    .init(name: "ctrl+p", source: chord(kVK_ANSI_P, ctrl), target: chord(kVK_ANSI_P, cmd)),
    .init(name: "ctrl+n", source: chord(kVK_ANSI_N, ctrl), target: chord(kVK_ANSI_N, cmd)),
    .init(name: "ctrl+o", source: chord(kVK_ANSI_O, ctrl), target: chord(kVK_ANSI_O, cmd)),
    .init(name: "ctrl+t", source: chord(kVK_ANSI_T, ctrl), target: chord(kVK_ANSI_T, cmd)),
    .init(name: "ctrl+w", source: chord(kVK_ANSI_W, ctrl), target: chord(kVK_ANSI_W, cmd)),
    .init(name: "ctrl+l", source: chord(kVK_ANSI_L, ctrl), target: chord(kVK_ANSI_L, cmd)),
    .init(name: "ctrl+delete", source: chord(kVK_ForwardDelete, ctrl), target: chord(kVK_ForwardDelete, alt)),
    .init(name: "alt+f4", source: chord(kVK_F4, alt), target: chord(kVK_ANSI_W, cmd)),
    .init(name: "alt+f2", source: chord(kVK_F2, alt), target: chord(kVK_Space, cmd)),
    .init(name: "alt+left", source: chord(kVK_LeftArrow, alt), target: chord(kVK_ANSI_LeftBracket, cmd)),
    .init(name: "alt+right", source: chord(kVK_RightArrow, alt), target: chord(kVK_ANSI_RightBracket, cmd)),
    .init(name: "win", source: chord(kVK_Command, cmd), target: chord(kVK_Space, cmd)),
    .init(name: "win+d", source: chord(kVK_ANSI_D, cmd), target: chord(kVK_F3, cmd)),
    .init(name: "win+l", source: chord(kVK_ANSI_L, cmd), target: chord(kVK_ANSI_Q, [ctrl, cmd])),
    .init(name: "win+tab", source: chord(kVK_Tab, cmd), target: chord(kVK_UpArrow, ctrl)),
    .init(name: "win+left", source: chord(kVK_LeftArrow, cmd), target: chord(kVK_LeftArrow, [fn, ctrl])),
    .init(name: "win+right", source: chord(kVK_RightArrow, cmd), target: chord(kVK_RightArrow, [fn, ctrl])),
    .init(name: "win+up", source: chord(kVK_UpArrow, cmd), target: chord(kVK_UpArrow, [fn, ctrl])),
    .init(name: "win+down", source: chord(kVK_DownArrow, cmd), target: chord(kVK_DownArrow, [fn, ctrl])),
    .init(name: "shift+print_screen", source: chord(kVK_F13, [shift, fn]), target: chord(kVK_ANSI_4, [cmd, shift])),
    .init(name: "ctrl+print_screen", source: chord(kVK_F13, [ctrl, fn]), target: chord(kVK_ANSI_3, [cmd, ctrl, shift])),
    .init(name: "ctrl+shift+print_screen", source: chord(kVK_F13, [ctrl, shift, fn]), target: chord(kVK_ANSI_4, [cmd, ctrl, shift])),
    .init(name: "ctrl+alt+delete", source: chord(kVK_ForwardDelete, [ctrl, alt]), target: chord(kVK_Escape, [cmd, alt])),
]

private var index = 0
private var observedTarget: Chord?

private let callback: CGEventTapCallBack = { _, type, event, _ in
    let marker = event.getIntegerValueField(.eventSourceUserData)
    guard marker == teleportMarker || marker == harnessMarker else {
        return Unmanaged.passUnretained(event)
    }

    if marker == harnessMarker {
        return Unmanaged.passUnretained(event)
    }

    if marker == teleportMarker && type == .keyDown {
        observedTarget = Chord(
            key: CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode)),
            flags: event.flags.intersection(relevant)
        )
    }

    // Suppress the resulting target so this test cannot lock the screen,
    // close windows, or switch apps.
    return nil
}

private func inject(_ value: Chord) {
    let source = CGEventSource(stateID: .hidSystemState)
    let down = CGEvent(keyboardEventSource: source, virtualKey: value.key, keyDown: true)!
    let up = CGEvent(keyboardEventSource: source, virtualKey: value.key, keyDown: false)!
    for event in [down, up] {
        event.flags = value.flags
        event.setIntegerValueField(.eventSourceUserData, value: harnessMarker)
    }
    if value.key == CGKeyCode(kVK_Command) || value.key == CGKeyCode(kVK_RightCommand) {
        down.type = .flagsChanged
        up.type = .flagsChanged
        up.flags = []
    }
    down.post(tap: .cgSessionEventTap)
    usleep(50_000)
    up.post(tap: .cgSessionEventTap)
}

private func runNext() {
    guard index < tests.count else {
        print("PASS: all \(tests.count) live key-remapping paths")
        fflush(stdout)
        exit(0)
    }

    let test = tests[index]
    observedTarget = nil
    inject(test.source)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        if let observed = observedTarget,
           observed.key == test.target.key,
           observed.flags == test.target.flags {
            print("PASS \(test.name)")
            index += 1
            runNext()
        } else {
            let actual = observedTarget.map { "key=\($0.key) flags=\($0.flags.rawValue)" } ?? "none"
            print("FAIL \(test.name): expected key=\(test.target.key) flags=\(test.target.flags.rawValue), got \(actual)")
            fflush(stdout)
            exit(1)
        }
    }
}

let mask = [CGEventType.keyDown, .keyUp, .flagsChanged].reduce(CGEventMask(0)) {
    $0 | (CGEventMask(1) << $1.rawValue)
}
guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .tailAppendEventTap,
    options: .defaultTap,
    eventsOfInterest: mask,
    callback: callback,
    userInfo: nil
), let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
    fputs("FAIL: could not install safety event tap\n", stderr)
    exit(2)
}

CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: runNext)
CFRunLoopRun()
