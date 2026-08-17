import CoreAudio
import Foundation

// Thin wrappers over the C-style AudioObject property API.
enum SystemAudio {
    static func propertyAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    static func objectList(_ objectID: AudioObjectID, _ selector: AudioObjectPropertySelector) -> [AudioObjectID] {
        var address = propertyAddress(selector)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &size) == noErr, size > 0 else {
            return []
        }
        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var list = [AudioObjectID](repeating: AudioObjectID(kAudioObjectUnknown), count: count)
        guard AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &list) == noErr else {
            return []
        }
        return list
    }

    static func string(_ objectID: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = propertyAddress(selector)
        var size = UInt32(MemoryLayout<CFString?>.size)
        var value: CFString? = nil
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, pointer)
        }
        guard status == noErr else { return nil }
        return value as String?
    }

    static func uint32(_ objectID: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32? {
        var address = propertyAddress(selector)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var value: UInt32 = 0
        guard AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        return value
    }

    static func pid(_ objectID: AudioObjectID, _ selector: AudioObjectPropertySelector) -> pid_t? {
        var address = propertyAddress(selector)
        var size = UInt32(MemoryLayout<pid_t>.size)
        var value: pid_t = 0
        guard AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        return value
    }

    static var defaultOutputDeviceID: AudioObjectID? {
        var address = propertyAddress(kAudioHardwarePropertyDefaultOutputDevice)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID) == noErr,
              deviceID != kAudioObjectUnknown else {
            return nil
        }
        return deviceID
    }

    static var defaultOutputDeviceUID: String? {
        guard let deviceID = defaultOutputDeviceID else { return nil }
        return string(deviceID, kAudioDevicePropertyDeviceUID)
    }

    static func addListener(
        _ objectID: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        block: @escaping AudioObjectPropertyListenerBlock
    ) {
        var address = propertyAddress(selector)
        AudioObjectAddPropertyListenerBlock(objectID, &address, .main, block)
    }
}
