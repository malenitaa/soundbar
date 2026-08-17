import Foundation

/// Play/pause for the apps that expose it via Apple events. Browsers don't —
/// muting their slider is the equivalent gesture there.
enum PlaybackControl {
    private static let scriptableBundleIDs: Set<String> = [
        "com.spotify.client",
        "com.apple.Music",
        "com.apple.TV",
    ]

    static func supportsPlayPause(_ bundleID: String) -> Bool {
        scriptableBundleIDs.contains(bundleID)
    }

    static func togglePlayPause(bundleID: String) {
        guard supportsPlayPause(bundleID) else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "tell application id \"\(bundleID)\" to playpause"]
        try? process.run()
    }
}
