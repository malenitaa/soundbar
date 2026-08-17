import Accelerate
import AudioToolbox
import CoreAudio
import Foundation
import os

/// Owns one process tap + private aggregate device for a group of audio
/// processes (usually all the helper processes of one app). While active, the
/// tapped processes are muted at the system level and their audio is replayed
/// through the default output with our gain applied.
final class ProcessTapController {
    private static let log = Logger(subsystem: "com.malenitaa.soundbar", category: "tap")

    private let processObjectIDs: [AudioObjectID]
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?

    // Written from the UI thread, read from the realtime audio thread. A torn
    // read of a Float32 is not possible on arm64/x86_64, so a lock would only
    // add priority-inversion risk here.
    private let gainStorage = UnsafeMutablePointer<Float>.allocate(capacity: 1)

    var gain: Float {
        get { gainStorage.pointee }
        set { gainStorage.pointee = max(0, min(newValue, 1)) }
    }

    init?(processObjectIDs: [AudioObjectID], gain: Float) {
        self.processObjectIDs = processObjectIDs
        self.gainStorage.initialize(to: max(0, min(gain, 1)))
        do {
            try activate()
        } catch {
            Self.log.error("Failed to activate tap: \(error.localizedDescription)")
            invalidate()
            return nil
        }
    }

    deinit {
        invalidate()
        gainStorage.deallocate()
    }

    private func activate() throws {
        let description = CATapDescription(stereoMixdownOfProcesses: processObjectIDs)
        description.uuid = UUID()
        description.muteBehavior = .mutedWhenTapped
        description.isPrivate = true

        var newTapID = AudioObjectID(kAudioObjectUnknown)
        var status = AudioHardwareCreateProcessTap(description, &newTapID)
        guard status == noErr, newTapID != kAudioObjectUnknown else {
            throw SoundBarError.osStatus("AudioHardwareCreateProcessTap", status)
        }
        tapID = newTapID

        guard let outputUID = SystemAudio.defaultOutputDeviceUID else {
            throw SoundBarError.noOutputDevice
        }

        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey: "SoundBar Tap",
            kAudioAggregateDeviceUIDKey: "com.malenitaa.soundbar.\(description.uuid.uuidString)",
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [
                [kAudioSubDeviceUIDKey: outputUID]
            ],
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapUIDKey: description.uuid.uuidString,
                    kAudioSubTapDriftCompensationKey: true,
                ]
            ],
        ]

        var newAggregateID = AudioObjectID(kAudioObjectUnknown)
        status = AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &newAggregateID)
        guard status == noErr, newAggregateID != kAudioObjectUnknown else {
            throw SoundBarError.osStatus("AudioHardwareCreateAggregateDevice", status)
        }
        aggregateID = newAggregateID

        let gainPointer = gainStorage
        status = AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, nil) { _, inputData, _, outputData, _ in
            let inputBuffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inputData))
            let outputBuffers = UnsafeMutableAudioBufferListPointer(outputData)
            var gainValue = gainPointer.pointee

            for index in 0..<outputBuffers.count {
                let outputBuffer = outputBuffers[index]
                guard let outputPointer = outputBuffer.mData else { continue }

                guard index < inputBuffers.count,
                      let inputPointer = inputBuffers[index].mData else {
                    memset(outputPointer, 0, Int(outputBuffer.mDataByteSize))
                    continue
                }

                let byteCount = min(inputBuffers[index].mDataByteSize, outputBuffer.mDataByteSize)
                let sampleCount = Int(byteCount) / MemoryLayout<Float32>.size
                vDSP_vsmul(
                    inputPointer.assumingMemoryBound(to: Float32.self), 1,
                    &gainValue,
                    outputPointer.assumingMemoryBound(to: Float32.self), 1,
                    vDSP_Length(sampleCount)
                )
                if outputBuffer.mDataByteSize > byteCount {
                    memset(outputPointer + Int(byteCount), 0, Int(outputBuffer.mDataByteSize - byteCount))
                }
            }
        }
        guard status == noErr, ioProcID != nil else {
            throw SoundBarError.osStatus("AudioDeviceCreateIOProcIDWithBlock", status)
        }

        status = AudioDeviceStart(aggregateID, ioProcID)
        guard status == noErr else {
            throw SoundBarError.osStatus("AudioDeviceStart", status)
        }
    }

    func invalidate() {
        if let ioProcID, aggregateID != kAudioObjectUnknown {
            AudioDeviceStop(aggregateID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
        }
        ioProcID = nil
        if aggregateID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = kAudioObjectUnknown
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = kAudioObjectUnknown
        }
    }
}

enum SoundBarError: Error, LocalizedError {
    case osStatus(String, OSStatus)
    case noOutputDevice

    var errorDescription: String? {
        switch self {
        case let .osStatus(call, status):
            return "\(call) failed with status \(status)"
        case .noOutputDevice:
            return "No default output device found"
        }
    }
}
