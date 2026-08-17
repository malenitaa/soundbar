import AppKit
import Combine
import CoreAudio
import Foundation
import os

struct AudioApp: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: NSImage?
    let processObjectIDs: [AudioObjectID]

    static func == (lhs: AudioApp, rhs: AudioApp) -> Bool {
        lhs.id == rhs.id && lhs.processObjectIDs == rhs.processObjectIDs
    }
}

@MainActor
final class MixerModel: ObservableObject {
    private static let log = Logger(subsystem: "com.malenitaa.soundbar", category: "mixer")

    @Published private(set) var apps: [AudioApp] = []
    @Published private var volumes: [String: Float] = [:]

    private var taps: [String: ProcessTapController] = [:]
    private var refreshTimer: Timer?

    init() {
        refresh()
        // Poll for process changes; the process-list listener alone misses
        // apps that start/stop playing without launching or quitting.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        SystemAudio.addListener(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice) { [weak self] _, _ in
            Task { @MainActor in self?.rebuildAllTaps() }
        }
    }

    func volume(for app: AudioApp) -> Float {
        volumes[app.id] ?? 1.0
    }

    func setVolume(_ volume: Float, for app: AudioApp) {
        let clamped = max(0, min(volume, 1))
        volumes[app.id] = clamped

        if clamped >= 0.999 {
            // Full volume: tear the tap down entirely so audio flows directly
            // from the app to the output again, with zero added latency.
            volumes[app.id] = 1.0
            taps.removeValue(forKey: app.id)?.invalidate()
            return
        }

        if let tap = taps[app.id] {
            tap.gain = clamped
        } else if let tap = ProcessTapController(processObjectIDs: app.processObjectIDs, gain: clamped) {
            taps[app.id] = tap
        } else {
            Self.log.error("Could not create tap for \(app.name)")
            volumes[app.id] = 1.0
        }
    }

    func reset(_ app: AudioApp) {
        setVolume(1.0, for: app)
    }

    // MARK: - Discovery

    private func refresh() {
        let previousApps = apps
        apps = Self.discoverAudioApps(keepingIDs: Set(taps.keys))

        // If the set of helper processes behind a tapped app changed (a new
        // Chrome audio helper, for example), rebuild that tap so the new
        // process is captured too.
        for app in apps {
            guard let volume = volumes[app.id], volume < 0.999, taps[app.id] != nil else { continue }
            if previousApps.first(where: { $0.id == app.id })?.processObjectIDs != app.processObjectIDs {
                rebuildTap(for: app)
            }
        }

        // Drop taps for apps that no longer exist at all (process gone).
        let liveIDs = Set(apps.map(\.id))
        for (id, tap) in taps where !liveIDs.contains(id) {
            tap.invalidate()
            taps.removeValue(forKey: id)
            volumes.removeValue(forKey: id)
        }
    }

    private func rebuildAllTaps() {
        for app in apps where taps[app.id] != nil {
            rebuildTap(for: app)
        }
    }

    private func rebuildTap(for app: AudioApp) {
        guard let volume = volumes[app.id] else { return }
        taps.removeValue(forKey: app.id)?.invalidate()
        if let tap = ProcessTapController(processObjectIDs: app.processObjectIDs, gain: volume) {
            taps[app.id] = tap
        } else {
            volumes.removeValue(forKey: app.id)
        }
    }

    /// Resolves a helper process (like Safari's shared "Graphics and Media"
    /// WebKit process) to the app the user actually recognizes. The symbol is
    /// private but long-stable; when unavailable we fall back to the helper's
    /// own pid and the bundle-suffix heuristic.
    private static let responsibilityFunction: (@convention(c) (pid_t) -> pid_t)? = {
        guard let handle = dlopen(nil, RTLD_NOW),
              let symbol = dlsym(handle, "responsibility_get_pid_responsible_for_pid") else { return nil }
        return unsafeBitCast(symbol, to: (@convention(c) (pid_t) -> pid_t).self)
    }()

    private static func responsiblePID(for pid: pid_t) -> pid_t {
        guard let function = responsibilityFunction else { return pid }
        let responsible = function(pid)
        return responsible > 0 ? responsible : pid
    }

    /// Lists apps currently emitting audio, grouped so that helper processes
    /// (like Chrome's audio service) collapse into their parent app.
    private static func discoverAudioApps(keepingIDs: Set<String>) -> [AudioApp] {
        let processObjects = SystemAudio.objectList(
            AudioObjectID(kAudioObjectSystemObject),
            kAudioHardwarePropertyProcessObjectList
        )
        let ownPID = ProcessInfo.processInfo.processIdentifier

        var groups: [String: [AudioObjectID]] = [:]
        var groupPIDs: [String: pid_t] = [:]

        for object in processObjects {
            guard let pid = SystemAudio.pid(object, kAudioProcessPropertyPID) else { continue }
            let responsible = responsiblePID(for: pid)

            // Never list ourselves: our replay of tapped audio registers as
            // SoundBar output, and tapping it would silence everything.
            guard pid != ownPID, responsible != ownPID else { continue }

            let isPlaying = SystemAudio.uint32(object, kAudioProcessPropertyIsRunningOutput) == 1
            let bundleID = SystemAudio.string(object, kAudioProcessPropertyBundleID) ?? ""
            let rootID = NSRunningApplication(processIdentifier: responsible)?.bundleIdentifier
                ?? rootBundleID(bundleID)

            // Keep tapped apps in the list even while momentarily silent, so
            // their slider doesn't vanish mid-adjustment.
            guard isPlaying || (!rootID.isEmpty && keepingIDs.contains(rootID)) else { continue }

            let key = rootID.isEmpty ? "pid.\(responsible)" : rootID
            groups[key, default: []].append(object)
            if groupPIDs[key] == nil {
                groupPIDs[key] = responsible
            }
        }

        return groups.map { key, objects in
            let (name, icon) = displayInfo(bundleID: key, pid: groupPIDs[key])
            return AudioApp(id: key, name: name, icon: icon, processObjectIDs: objects.sorted())
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// com.google.Chrome.helper → com.google.Chrome, so all of an app's
    /// helpers share one slider.
    private static func rootBundleID(_ bundleID: String) -> String {
        var id = bundleID
        for suffix in [".helper", ".Helper", ".helper.plugin"] where id.hasSuffix(suffix) {
            id = String(id.dropLast(suffix.count))
        }
        return id
    }

    private static func displayInfo(bundleID: String, pid: pid_t?) -> (String, NSImage?) {
        let running = NSWorkspace.shared.runningApplications
        if let app = running.first(where: { $0.bundleIdentifier == bundleID }) {
            return (app.localizedName ?? bundleID, app.icon)
        }
        if let app = running.first(where: {
            guard let id = $0.bundleIdentifier else { return false }
            return bundleID.hasPrefix(id + ".")
        }) {
            return (app.localizedName ?? bundleID, app.icon)
        }
        if let pid, let app = NSRunningApplication(processIdentifier: pid) {
            return (app.localizedName ?? bundleID, app.icon)
        }
        let fallback = bundleID.split(separator: ".").last.map(String.init) ?? bundleID
        return (fallback, nil)
    }
}
