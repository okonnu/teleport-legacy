import Foundation
import IOKit

enum DirectDDCError: Error, CustomStringConvertible {
    case unsupportedArchitecture
    case invalidInput(Int)
    case displayNotFound(String)
    case writeFailed(String)

    var description: String {
        switch self {
        case .unsupportedArchitecture:
            return "Direct DDC requires Apple Silicon"
        case .invalidInput(let value):
            return "Invalid DDC input value: \(value)"
        case .displayNotFound(let name):
            return "DDC display was not found: \(name)"
        case .writeFailed(let name):
            return "DDC input command failed for: \(name)"
        }
    }
}

enum DirectDDC {
    private static let ddcAddress: UInt8 = 0x37
    private static let dataAddress: UInt8 = 0x51
    private static let inputSelect: UInt8 = 0x60

    static func inputPacket(value: UInt16) -> [UInt8] {
        var packet: [UInt8] = [
            0x84,
            0x03,
            inputSelect,
            UInt8(value >> 8),
            UInt8(value & 0xff),
            0
        ]
        packet[packet.count - 1] = packet.dropLast().reduce(
            (ddcAddress << 1) ^ dataAddress,
            ^
        )
        return packet
    }

    static func setInput(displayName: String, value: Int) throws {
        guard let input = UInt16(exactly: value) else {
            throw DirectDDCError.invalidInput(value)
        }

        #if arch(arm64)
        guard let service = findService(productName: displayName) else {
            throw DirectDDCError.displayNotFound(displayName)
        }
        guard writeInput(service: service, value: input) else {
            throw DirectDDCError.writeFailed(displayName)
        }
        #else
        throw DirectDDCError.unsupportedArchitecture
        #endif
    }

    #if arch(arm64)
    private static func findService(productName: String) -> IOAVService? {
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        guard root != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(root) }

        var iterator: io_iterator_t = 0
        guard IORegistryEntryCreateIterator(
            root,
            kIOServicePlane,
            IOOptionBits(kIORegistryIterateRecursively),
            &iterator
        ) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var currentProductName = ""
        while true {
            let entry = IOIteratorNext(iterator)
            guard entry != IO_OBJECT_NULL else { break }
            defer { IOObjectRelease(entry) }

            var nameBuffer = [CChar](repeating: 0, count: 128)
            guard IORegistryEntryGetName(entry, &nameBuffer) == KERN_SUCCESS else {
                continue
            }
            let entryName = String(cString: nameBuffer)

            if entryName.contains("AppleCLCD2") || entryName.contains("IOMobileFramebufferShim") {
                currentProductName = readProductName(entry: entry) ?? ""
                continue
            }

            guard entryName.contains("DCPAVServiceProxy"),
                  currentProductName.caseInsensitiveCompare(productName) == .orderedSame,
                  readString(entry: entry, key: "Location") == "External"
            else { continue }

            return IOAVServiceCreateWithService(kCFAllocatorDefault, entry)?.takeRetainedValue()
        }
        return nil
    }

    private static func readProductName(entry: io_service_t) -> String? {
        guard let value = IORegistryEntryCreateCFProperty(
            entry,
            "DisplayAttributes" as CFString,
            kCFAllocatorDefault,
            IOOptionBits(kIORegistryIterateRecursively)
        )?.takeRetainedValue() as? NSDictionary,
        let product = value["ProductAttributes"] as? NSDictionary
        else { return nil }
        return product["ProductName"] as? String
    }

    private static func readString(entry: io_service_t, key: String) -> String? {
        IORegistryEntryCreateCFProperty(
            entry,
            key as CFString,
            kCFAllocatorDefault,
            IOOptionBits(kIORegistryIterateRecursively)
        )?.takeRetainedValue() as? String
    }

    private static func writeInput(service: IOAVService, value: UInt16) -> Bool {
        var packet = inputPacket(value: value)
        for _ in 0...4 {
            var result = kIOReturnError
            for _ in 0..<2 {
                usleep(10_000)
                result = packet.withUnsafeMutableBytes { bytes in
                    IOAVServiceWriteI2C(
                        service,
                        UInt32(ddcAddress),
                        UInt32(dataAddress),
                        bytes.baseAddress,
                        UInt32(bytes.count)
                    )
                }
            }
            if result == kIOReturnSuccess { return true }
            usleep(20_000)
        }
        return false
    }
    #endif
}
