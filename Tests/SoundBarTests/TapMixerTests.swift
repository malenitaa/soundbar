import CoreAudio
import Testing
@testable import SoundBar

/// Hand-built AudioBufferList: one buffer per entry, each `channels` wide and
/// interleaved, `frames` long. Samples are read and written frame by frame.
private final class BufferList {
    let list: UnsafeMutableAudioBufferListPointer
    let shape: [Int]
    let frames: Int

    init(_ shape: [Int], frames: Int) {
        self.shape = shape
        self.frames = frames
        list = AudioBufferList.allocate(maximumBuffers: max(shape.count, 1))
        list.count = shape.count
        for (index, channels) in shape.enumerated() {
            let bytes = channels * frames * MemoryLayout<Float32>.size
            let data = UnsafeMutableRawPointer.allocate(byteCount: bytes, alignment: 16)
            data.initializeMemory(as: Float32.self, repeating: -99, count: channels * frames) // garbage
            list[index] = AudioBuffer(mNumberChannels: UInt32(channels), mDataByteSize: UInt32(bytes), mData: data)
        }
    }

    deinit {
        for buffer in list { buffer.mData?.deallocate() }
        free(list.unsafeMutablePointer)
    }

    func set(buffer: Int, _ sample: (_ frame: Int, _ channel: Int) -> Float32) {
        let channels = shape[buffer]
        let data = list[buffer].mData!.assumingMemoryBound(to: Float32.self)
        for frame in 0..<frames { for channel in 0..<channels { data[frame * channels + channel] = sample(frame, channel) } }
    }

    func get(buffer: Int, frame: Int, channel: Int) -> Float32 {
        list[buffer].mData!.assumingMemoryBound(to: Float32.self)[frame * shape[buffer] + channel]
    }
}

private let frames = 64
private func left(_ frame: Int) -> Float32 { Float32(frame + 1) }
private func right(_ frame: Int) -> Float32 { -Float32(frame + 1) * 10 }
private func stereoTap(_ frame: Int, _ channel: Int) -> Float32 { channel == 0 ? left(frame) : right(frame) }

/// Input as the aggregate delivers it: the output device's own input streams
/// first (`deviceInputs`), then the stereo tap.
private func makeInput(deviceInputs: [Int] = []) -> BufferList {
    let input = BufferList(deviceInputs + [2], frames: frames)
    for index in deviceInputs.indices { input.set(buffer: index) { _, _ in 0.5 } } // "microphone"
    input.set(buffer: deviceInputs.count, stereoTap)
    return input
}

@Test func stereoOutput() {
    let input = makeInput(), output = BufferList([2], frames: frames)
    TapMixer.mix(input: input.list, output: output.list, gain: 0.5)
    for frame in 0..<frames {
        #expect(output.get(buffer: 0, frame: frame, channel: 0) == left(frame) * 0.5)
        #expect(output.get(buffer: 0, frame: frame, channel: 1) == right(frame) * 0.5)
    }
}

@Test func outputDeviceWithItsOwnInputPlaysTheTapNotTheMic() {
    let input = makeInput(deviceInputs: [2]), output = BufferList([2], frames: frames)
    TapMixer.mix(input: input.list, output: output.list, gain: 0.5)
    for frame in 0..<frames {
        #expect(output.get(buffer: 0, frame: frame, channel: 0) == left(frame) * 0.5)
        #expect(output.get(buffer: 0, frame: frame, channel: 1) == right(frame) * 0.5)
    }
}

@Test func monoOutputGetsTheAverage() {
    let input = makeInput(deviceInputs: [1]), output = BufferList([1], frames: frames)
    TapMixer.mix(input: input.list, output: output.list, gain: 0.5)
    for frame in 0..<frames {
        #expect(output.get(buffer: 0, frame: frame, channel: 0) == (left(frame) + right(frame)) / 2 * 0.5)
    }
}

@Test func multichannelInterleavedOutput() {
    let input = makeInput(), output = BufferList([6], frames: frames)
    TapMixer.mix(input: input.list, output: output.list, gain: 0.5)
    for frame in 0..<frames {
        #expect(output.get(buffer: 0, frame: frame, channel: 0) == left(frame) * 0.5)
        #expect(output.get(buffer: 0, frame: frame, channel: 1) == right(frame) * 0.5)
        for channel in 2..<6 { #expect(output.get(buffer: 0, frame: frame, channel: channel) == 0) }
    }
}

@Test func nonInterleavedOutput() {
    let input = makeInput(), output = BufferList([1, 1, 1, 1], frames: frames)
    TapMixer.mix(input: input.list, output: output.list, gain: 0.5)
    for frame in 0..<frames {
        #expect(output.get(buffer: 0, frame: frame, channel: 0) == left(frame) * 0.5)
        #expect(output.get(buffer: 1, frame: frame, channel: 0) == right(frame) * 0.5)
        #expect(output.get(buffer: 2, frame: frame, channel: 0) == 0)
        #expect(output.get(buffer: 3, frame: frame, channel: 0) == 0)
    }
}

@Test func noTapInputIsSilence() {
    let input = BufferList([], frames: frames), output = BufferList([2], frames: frames)
    TapMixer.mix(input: input.list, output: output.list, gain: 0.5)
    for frame in 0..<frames {
        #expect(output.get(buffer: 0, frame: frame, channel: 0) == 0)
        #expect(output.get(buffer: 0, frame: frame, channel: 1) == 0)
    }
}
