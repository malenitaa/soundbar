import AppKit
import SwiftUI

/// The panel's finish: the system's translucent glass material, or an
/// opaque background for people who find text on glass hard to read.
enum PanelStyle: String {
    case glass
    case solid
}

struct MixerView: View {
    @EnvironmentObject private var mixer: MixerModel
    @AppStorage("panelStyle") private var panelStyleRaw = PanelStyle.glass.rawValue

    private var panelStyle: PanelStyle {
        PanelStyle(rawValue: panelStyleRaw) ?? .glass
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("SoundBar")
                    .font(.headline)
                Spacer()
                Button {
                    panelStyleRaw = (panelStyle == .glass ? PanelStyle.solid : .glass).rawValue
                } label: {
                    Image(systemName: panelStyle == .glass ? "circle.bottomhalf.filled" : "circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(panelStyle == .glass ? L10n.switchToSolid : L10n.switchToGlass)
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(L10n.quit)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if mixer.apps.isEmpty {
                VStack(spacing: 4) {
                    Text(L10n.noAudio)
                        .font(.callout)
                    Text(L10n.hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 14) {
                    ForEach(mixer.apps) { app in
                        AppVolumeRow(app: app)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .frame(width: 300)
        .background {
            if panelStyle == .solid {
                Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
            }
        }
    }
}

private struct AppVolumeRow: View {
    @EnvironmentObject private var mixer: MixerModel
    let app: AudioApp

    var body: some View {
        let volume = mixer.volume(for: app)

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: "app.dashed")
                        .frame(width: 18, height: 18)
                }
                Text(app.name)
                    .font(.callout)
                    .lineLimit(1)
                if PlaybackControl.supportsPlayPause(app.id) {
                    Button {
                        PlaybackControl.togglePlayPause(bundleID: app.id)
                        mixer.scheduleRefresh(after: 0.7)
                    } label: {
                        Image(systemName: app.isPlaying ? "pause.fill" : "play.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help(L10n.playPause)
                }
                Spacer()
                Text("\(Int(round(volume * 100)))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button {
                    mixer.toggleMute(for: app)
                } label: {
                    Image(systemName: volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.caption)
                        .frame(width: 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(volume == 0 ? Color.accentColor : Color.secondary)
                .help(volume == 0 ? L10n.unmute : L10n.mute)
                Slider(
                    value: Binding(
                        get: { mixer.volume(for: app) },
                        set: { mixer.setVolume($0, for: app) }
                    ),
                    in: 0...1
                )
                .accessibilityLabel(L10n.volumeLabel(for: app.name))
                Button {
                    mixer.reset(app)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(volume < 0.999 ? Color.accentColor : Color.secondary.opacity(0.4))
                .disabled(volume >= 0.999)
                .help(L10n.reset)
            }
        }
    }
}
