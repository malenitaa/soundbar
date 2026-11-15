import Accelerate
import CoreAudio
import Foundation

/// The realtime part of a tap: copies the tapped audio into the aggregate's
/// output buffers with the gain applied. Kept free of Core Audio objects so it
/// can be tested with hand-built buffer lists.
enum TapMixer {
    /// The aggregate's input lists the output device's own input streams (a
    /// headset mic, an interface's line inputs) before the tap, so the tap is
    /// the last input buffer. The output can be any layout: one interleaved
    /// buffer of N channels, or one buffer per channel. The tap's channels go
    /// to the first output channels (averaged for a mono device); the rest
    /// stay silent, as they would for a stereo app playing directly.
    static func mix(input: UnsafeMutableAudioBufferListPointer, output: UnsafeMutableAudioBufferListPointer, gain: Float) {
        for buffer in output {
            if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
        }
        guard let tap = input.last, let tapData = tap.mData, tap.mNumberChannels > 0 else { return }

        let tapChannels = Int(tap.mNumberChannels)
        let source = tapData.assumingMemoryBound(to: Float32.self)
        let tapFrames = Int(tap.mDataByteSize) / MemoryLayout<Float32>.size / tapChannels
        let outputChannels = output.reduce(0) { $0 + Int($1.mNumberChannels) }

        var firstChannel = 0
        for buffer in output {
            let channels = Int(buffer.mNumberChannels)
            defer { firstChannel += channels }
            guard let data = buffer.mData, channels > 0 else { continue }

            let destination = data.assumingMemoryBound(to: Float32.self)
            let bufferFrames = Int(buffer.mDataByteSize) / MemoryLayout<Float32>.size / channels
            let frames = vDSP_Length(min(tapFrames, bufferFrames))

            if outputChannels == 1 {
                var share = gain / Float(tapChannels)
                for channel in 0..<tapChannels {
                    vDSP_vsma(source + channel, tapChannels, &share, destination, 1, destination, 1, frames)
                }
                continue
            }
            for channel in 0..<channels where firstChannel + channel < tapChannels {
                var gainValue = gain
                vDSP_vsmul(
                    source + firstChannel + channel, tapChannels,
                    &gainValue,
                    destination + channel, channels,
                    frames
                )
            }
        }
    }
}
