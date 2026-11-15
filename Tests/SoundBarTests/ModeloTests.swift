import CoreAudio
import Foundation
import Testing
@testable import SoundBar

// Estos tests crean taps reales (con lista de procesos vacía, que no silencian
// a nadie) y un MixerModel real con su timer. Necesitan una Mac con audio.

private func fakeApp(_ id: String = "test.soundbar.falsa") -> AudioApp {
    AudioApp(id: id, name: id, icon: nil, isPlaying: true, processObjectIDs: [])
}

@MainActor @Test func volumenNaNNoSeGuardaComoNaN() {
    let model = MixerModel(), app = fakeApp()
    defer { model.reset(app) }
    model.setVolume(.nan, for: app)
    #expect(!model.volume(for: app).isNaN)
}

@MainActor @Test func volumenNaNQuedaEnCero() {
    // Decisión del cierre del 15/11/2026: el slider no puede mandar NaN, y si
    // llegara, max(0, min(NaN, 1)) lo deja en 0 (silencio), igual que
    // ProcessTapController.gain. Se documenta en vez de cambiarlo.
    let model = MixerModel(), app = fakeApp()
    defer { model.reset(app) }
    model.setVolume(.nan, for: app)
    #expect(model.volume(for: app) == 0)
}

@MainActor @Test func volumenesImposiblesQuedanEnRango() {
    let model = MixerModel(), app = fakeApp()
    defer { model.reset(app) }
    for v: Float in [-1, -.infinity, .infinity, 2, 1e30, -0.0] {
        model.setVolume(v, for: app)
        let got = model.volume(for: app)
        #expect(got >= 0 && got <= 1, "setVolume(\(v)) dejó \(got)")
    }
}

@MainActor @Test func casiCienPorCientoSeAjustaACien() {
    let model = MixerModel(), app = fakeApp()
    model.setVolume(0.9995, for: app)
    #expect(model.volume(for: app) == 1)
    model.setVolume(0.998, for: app)
    #expect(model.volume(for: app) == 0.998)
    model.reset(app)
}

@MainActor @Test func silenciarYReactivarDevuelveElVolumenPrevio() {
    let model = MixerModel(), app = fakeApp()
    model.setVolume(0.4, for: app)
    model.toggleMute(for: app)
    #expect(model.volume(for: app) == 0)
    model.toggleMute(for: app)
    #expect(model.volume(for: app) == 0.4)
    model.reset(app)
}

@MainActor @Test func resetEnMuteVuelveACienYElSiguienteToggleSilencia() {
    let model = MixerModel(), app = fakeApp()
    model.setVolume(0.4, for: app)
    model.toggleMute(for: app)
    model.reset(app)
    #expect(model.volume(for: app) == 1)
    model.toggleMute(for: app)
    #expect(model.volume(for: app) == 0)
    model.toggleMute(for: app)
    #expect(model.volume(for: app) == 1) // no resucita el 0.4 viejo
    model.reset(app)
}

@MainActor @Test func silenciarDesdeCienYReactivarVuelveACien() {
    let model = MixerModel(), app = fakeApp()
    model.toggleMute(for: app)
    #expect(model.volume(for: app) == 0)
    model.toggleMute(for: app)
    #expect(model.volume(for: app) == 1)
}

@MainActor @Test func moverElSliderEnMuteYSilenciarDeNuevoGuardaElNuevoVolumen() {
    let model = MixerModel(), app = fakeApp()
    model.setVolume(0.4, for: app)
    model.toggleMute(for: app)       // pre = 0.4, volumen 0
    model.setVolume(0.7, for: app)   // el usuario arrastra el slider
    model.toggleMute(for: app)       // pre = 0.7
    model.toggleMute(for: app)
    #expect(model.volume(for: app) == 0.7)
    model.reset(app)
}

@MainActor @Test func dosAppsNoSePisanElVolumen() {
    let model = MixerModel(), a = fakeApp("test.soundbar.a"), b = fakeApp("test.soundbar.b")
    model.setVolume(0.2, for: a)
    model.toggleMute(for: b)
    #expect(model.volume(for: a) == 0.2)
    #expect(model.volume(for: b) == 0)
    model.reset(a); model.reset(b)
}

@MainActor @Test func repetirElMismoVolumenEsIdempotente() {
    let model = MixerModel(), app = fakeApp()
    for _ in 0..<3 { model.setVolume(0.5, for: app) }
    #expect(model.volume(for: app) == 0.5)
    for _ in 0..<3 { model.reset(app) }
    #expect(model.volume(for: app) == 1)
}

@MainActor @Test func unaAppQueDesapareceSuelta_suEstadoEnElRefresh() async throws {
    // La app falsa no existe entre los procesos de audio: el refresh tiene
    // que tirar su tap y su volumen, no dejarla silenciada sin control.
    let model = MixerModel(), app = fakeApp()
    model.setVolume(0.3, for: app)
    #expect(model.volume(for: app) == 0.3)
    model.scheduleRefresh(after: 0)
    try await Task.sleep(nanoseconds: 300_000_000)
    #expect(model.volume(for: app) == 1)
}

@MainActor @Test func tapConGananciaImposibleQuedaEnRango() {
    for g: Float in [.nan, .infinity, -.infinity, -1, 2] {
        guard let tap = ProcessTapController(processObjectIDs: [], gain: g) else { continue }
        #expect(tap.gain >= 0 && tap.gain <= 1)
        tap.gain = g
        #expect(tap.gain >= 0 && tap.gain <= 1)
        tap.invalidate()
    }
}

@MainActor @Test func invalidarDosVecesNoRompe() {
    guard let tap = ProcessTapController(processObjectIDs: [], gain: 0.5) else { return }
    tap.invalidate()
    tap.invalidate()
}
