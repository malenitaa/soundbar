import CoreAudio
import Testing
@testable import SoundBar

/// Un buffer con respaldo propio: `capacity` floats reales, de los cuales se
/// declaran `declaredBytes` en mDataByteSize. Lo que queda después de lo
/// declarado es un canario que nadie debería pisar.
private final class Raw {
    static let canary: Float32 = 777
    let data: UnsafeMutablePointer<Float32>
    let capacity: Int
    init(capacity: Int, fill: Float32 = -99) {
        self.capacity = capacity
        data = .allocate(capacity: max(capacity, 1))
        data.initialize(repeating: fill, count: max(capacity, 1))
    }
    deinit { data.deallocate() }
}

private func makeList(_ buffers: [(channels: UInt32, bytes: UInt32, raw: Raw?)]) -> UnsafeMutableAudioBufferListPointer {
    let list = AudioBufferList.allocate(maximumBuffers: max(buffers.count, 1))
    list.count = buffers.count
    for (i, b) in buffers.enumerated() {
        list[i] = AudioBuffer(mNumberChannels: b.channels, mDataByteSize: b.bytes, mData: b.raw.map { UnsafeMutableRawPointer($0.data) })
    }
    return list
}

private func free(_ list: UnsafeMutableAudioBufferListPointer) { Foundation.free(list.unsafeMutablePointer) }

@Test func tapSinFramesNoTocaNiRompeNada() {
    let tap = Raw(capacity: 4), out = Raw(capacity: 8)
    let input = makeList([(2, 0, tap)]), output = makeList([(2, 32, out)])
    defer { free(input); free(output) }
    TapMixer.mix(input: input, output: output, gain: 0.5)
    #expect((0..<8).allSatisfy { out.data[$0] == 0 })
}

@Test func tapConCeroCanalesDejaSilencio() {
    let tap = Raw(capacity: 8, fill: 1), out = Raw(capacity: 8)
    let input = makeList([(0, 32, tap)]), output = makeList([(2, 32, out)])
    defer { free(input); free(output) }
    TapMixer.mix(input: input, output: output, gain: 1)
    #expect((0..<8).allSatisfy { out.data[$0] == 0 })
}

@Test func tapConMDataNilDejaSilencio() {
    let out = Raw(capacity: 8)
    let input = makeList([(2, 32, nil)]), output = makeList([(2, 32, out)])
    defer { free(input); free(output) }
    TapMixer.mix(input: input, output: output, gain: 1)
    #expect((0..<8).allSatisfy { out.data[$0] == 0 })
}

@Test func salidaConMDataNilNoCrashea() {
    let tap = Raw(capacity: 8, fill: 1)
    let input = makeList([(2, 32, tap)]), output = makeList([(2, 32, nil)])
    defer { free(input); free(output) }
    TapMixer.mix(input: input, output: output, gain: 1)
}

@Test func salidaSinBuffersNoCrashea() {
    let tap = Raw(capacity: 8, fill: 1)
    let input = makeList([(2, 32, tap)]), output = makeList([])
    defer { free(input); free(output) }
    TapMixer.mix(input: input, output: output, gain: 1)
}

@Test func salidaMasCortaQueElTapNoEscribeFueraDeLoDeclarado() {
    // Salida: 4 frames estéreo declarados (32 bytes) sobre 16 floats reales.
    let tap = Raw(capacity: 32, fill: 1), out = Raw(capacity: 16, fill: Raw.canary)
    let input = makeList([(2, 128, tap)]), output = makeList([(2, 32, out)])
    defer { free(input); free(output) }
    TapMixer.mix(input: input, output: output, gain: 1)
    #expect((0..<8).allSatisfy { out.data[$0] == 1 })
    #expect((8..<16).allSatisfy { out.data[$0] == Raw.canary })
}

@Test func tapMasCortoQueLaSalidaDejaElRestoEnSilencio() {
    let tap = Raw(capacity: 8, fill: 1), out = Raw(capacity: 32)
    let input = makeList([(2, 32, tap)]), output = makeList([(2, 128, out)])
    defer { free(input); free(output) }
    TapMixer.mix(input: input, output: output, gain: 1)
    #expect((0..<8).allSatisfy { out.data[$0] == 1 })
    #expect((8..<32).allSatisfy { out.data[$0] == 0 })
}

@Test func bufferDeSalidaConCeroCanalesNoDesplazaAlSiguiente() {
    let tap = Raw(capacity: 8, fill: 1), a = Raw(capacity: 4), b = Raw(capacity: 8)
    let input = makeList([(2, 32, tap)]), output = makeList([(0, 16, a), (2, 32, b)])
    defer { free(input); free(output) }
    TapMixer.mix(input: input, output: output, gain: 1)
    #expect((0..<8).allSatisfy { b.data[$0] == 1 })
}

@Test func salidaMonoConTapMonoNoAtenua() {
    let tap = Raw(capacity: 4, fill: 1), out = Raw(capacity: 4)
    let input = makeList([(1, 16, tap)]), output = makeList([(1, 16, out)])
    defer { free(input); free(output) }
    TapMixer.mix(input: input, output: output, gain: 0.5)
    #expect((0..<4).allSatisfy { out.data[$0] == 0.5 })
}

// MARK: - Bundle IDs

@MainActor @Test func rootBundleIDQuitaUnSoloSufijo() {
    #expect(MixerModel.rootBundleID("com.google.Chrome.helper") == "com.google.Chrome")
    #expect(MixerModel.rootBundleID("com.google.Chrome.Helper") == "com.google.Chrome")
}

@MainActor @Test func rootBundleIDConSufijosEncadenadosLosQuitaTodos() {
    // "x.helper.plugin": la lista itera ".helper" antes que ".helper.plugin".
    #expect(MixerModel.rootBundleID("com.google.Chrome.helper.plugin") == "com.google.Chrome")
}

@MainActor @Test func rootBundleIDNoRompeNombresQueSoloTerminanParecido() {
    #expect(MixerModel.rootBundleID("com.acme.myhelper") == "com.acme.myhelper")
}

@MainActor @Test func rootBundleIDDeSoloElSufijoDevuelveVacio() {
    // Documenta: ".helper" a secas termina vacío y discoverAudioApps lo trata
    // como "sin bundle" (clave pid.N).
    #expect(MixerModel.rootBundleID(".helper") == "")
}

@MainActor @Test func rootBundleIDVacioYUnicode() {
    #expect(MixerModel.rootBundleID("") == "")
    #expect(MixerModel.rootBundleID("com.ñandú.app.helper") == "com.ñandú.app")
}

@MainActor @Test func canonicalBundleIDMapeaLosDemoniosDeFaceTime() {
    #expect(MixerModel.canonicalBundleID("com.apple.avconferenced") == "com.apple.FaceTime")
    #expect(MixerModel.canonicalBundleID("com.apple.TelephonyUtilities") == "com.apple.FaceTime")
}

@MainActor @Test func canonicalBundleIDNoMapeaPorPrefijoNiPorMayusculas() {
    #expect(MixerModel.canonicalBundleID("com.apple.avconferenced.helper") == "com.apple.avconferenced.helper")
    #expect(MixerModel.canonicalBundleID("COM.APPLE.AVCONFERENCED") == "COM.APPLE.AVCONFERENCED")
    #expect(MixerModel.canonicalBundleID("") == "")
}

@MainActor @Test func helperDeUnDemonioAliasadoTerminaEnFaceTime() {
    // El orden en discoverAudioApps es canonical(root(id)): un helper del
    // demonio debería terminar también en FaceTime.
    #expect(MixerModel.canonicalBundleID(MixerModel.rootBundleID("com.apple.avconferenced.helper")) == "com.apple.FaceTime")
}

@Test func reproduccionSoloPermiteLaAllowlist() {
    #expect(PlaybackControl.supportsPlayPause("com.spotify.client"))
    #expect(!PlaybackControl.supportsPlayPause("com.spotify.client\" to quit\n--"))
    #expect(!PlaybackControl.supportsPlayPause("com.Spotify.client"))
    #expect(!PlaybackControl.supportsPlayPause(" com.spotify.client"))
    #expect(!PlaybackControl.supportsPlayPause(""))
}
