import SwiftUI

@main
struct SoundBarApp: App {
    @StateObject private var mixer = MixerModel()

    var body: some Scene {
        MenuBarExtra("SoundBar", systemImage: "slider.horizontal.3") {
            MixerView()
                .environmentObject(mixer)
        }
        .menuBarExtraStyle(.window)
    }
}
