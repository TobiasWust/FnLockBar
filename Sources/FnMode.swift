// FnLockBar — menu bar indicator + toggle for the fn key mode.
// Reads the live HID parameter (HIDFKeyMode), which is what BTT's
// "Set Function Key Mode" action changes (com.apple.keyboard.fnState is NOT updated by it).

import Foundation
import IOKit
import IOKit.hidsystem

enum FnMode {
    /// true = F1–F12 are standard function keys ("fn lock" on)
    static func isFunctionKeys() -> Bool? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let params = IORegistryEntryCreateCFProperty(service, kIOHIDParametersKey as CFString,
                                                           kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any],
              let mode = params[kIOHIDFKeyModeKey] as? Int else { return nil }
        return mode == 1
    }

    static func set(functionKeys: Bool) -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        var connect: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect) == KERN_SUCCESS else { return false }
        defer { IOServiceClose(connect) }
        var value: UInt32 = functionKeys ? 1 : 0
        let kr = IOHIDSetParameter(connect, kIOHIDFKeyModeKey as CFString, &value,
                                   IOByteCount(MemoryLayout<UInt32>.size))
        // keep the System Settings toggle in sync too
        CFPreferencesSetValue("com.apple.keyboard.fnState" as CFString, functionKeys as CFBoolean,
                              kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        return kr == KERN_SUCCESS
    }
}
