import Foundation

/// Minimal runtime localization: English by default, Spanish when the system
/// prefers it. Kept as a plain struct so the SPM executable needs no resource
/// bundles.
enum L10n {
    private static let spanish = Locale.preferredLanguages.first?.hasPrefix("es") ?? false

    static var noAudio: String {
        spanish ? "Ninguna app está reproduciendo audio" : "No apps are playing audio"
    }

    static var hint: String {
        spanish
            ? "Las apps aparecen acá cuando emiten sonido."
            : "Apps show up here while they're making sound."
    }

    static var reset: String { spanish ? "Restablecer" : "Reset" }
    static var mute: String { spanish ? "Silenciar" : "Mute" }
    static var unmute: String { spanish ? "Reactivar sonido" : "Unmute" }
    static var playPause: String { spanish ? "Reproducir/Pausar" : "Play/Pause" }
    static var quit: String { spanish ? "Salir de SoundBar" : "Quit SoundBar" }
    static var switchToSolid: String { spanish ? "Panel sólido" : "Solid panel" }
    static var switchToGlass: String { spanish ? "Panel de vidrio" : "Glass panel" }

    static func volumeLabel(for name: String) -> String {
        spanish ? "Volumen de \(name)" : "\(name) volume"
    }
}
