import ApplicationServices
import Carbon.HIToolbox
import Foundation

private let teleportMarker: Int64 = 0x54454C45504F5254
private let harnessMarker: Int64 = 0x54454C4553544552
private var sourceObserved = false
private var transformedEventObserved = false
private let testingAltTab = CommandLine.arguments.contains("--alt-tab")

private let callback: CGEventTapCallBack = { _, type, event, _ in
    guard type == .keyDown || type == .keyUp else {
        return Unmanaged.passUnretained(event)
    }
    let marker = event.getIntegerValueField(.eventSourceUserData)
    if marker == harnessMarker { sourceObserved = true }
    if marker == teleportMarker { transformedEventObserved = true }
    if marker == harnessMarker || marker == teleportMarker { return nil }
    return Unmanaged.passUnretained(event)
}

let mask = [CGEventType.keyDown, .keyUp].reduce(CGEventMask(0)) {
    $0 | (CGEventMask(1) << $1.rawValue)
}
guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .tailAppendEventTap,
    options: .defaultTap,
    eventsOfInterest: mask,
    callback: callback,
    userInfo: nil
), let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
    fputs("FAIL could not install fail-open observer\n", stderr)
    exit(2)
}
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
    let eventSource = CGEventSource(stateID: .hidSystemState)
    let keyCode = CGKeyCode(testingAltTab ? kVK_Tab : kVK_ANSI_A)
    let modifiers: CGEventFlags = testingAltTab ? [.maskAlternate] : [.maskControl]
    let down = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true)!
    let up = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false)!
    for event in [down, up] {
        event.flags = modifiers
        event.setIntegerValueField(.eventSourceUserData, value: harnessMarker)
    }
    down.post(tap: .cgSessionEventTap)
    usleep(50_000)
    up.post(tap: .cgSessionEventTap)
}

DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
    if sourceObserved || transformedEventObserved {
        let result = sourceObserved ? "original event passed through" : "event transformed in place"
        let testName = testingAltTab ? "Alt Tab ownership" : "permission-revocation safety"
        print("PASS \(testName): \(result)")
        exit(0)
    }
    print("FAIL keyboard event was swallowed")
    exit(1)
}
CFRunLoopRun()
