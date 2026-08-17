import AppKit
import SwiftUI

struct MixerView: View {
    @EnvironmentObject private var mixer: MixerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("SoundBar")
                    .font(.headline)
                Spacer()
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
                    } label: {
                        Image(systemName: "playpause.fill")
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
