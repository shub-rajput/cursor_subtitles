import Foundation

struct CursorOffset: Codable, Sendable {
    var x: CGFloat = 8
    var y: CGFloat = 8
}

struct StyleConfig: Codable, Sendable {
    var backgroundColor: String = "#2DA44E"
    var textColor: String = "#FFFFFF"
    var placeholderText: String = "Say something"
    var fontSize: CGFloat = 15
    var fontFamily: String = "system"
    var cornerRadius: CGFloat = 20
    var paddingH: CGFloat = 16
    var paddingV: CGFloat = 8
    var maxWidth: CGFloat = 300
    var cursorOffset: CursorOffset = CursorOffset()
}

struct BehaviorConfig: Codable, Sendable {
    var idleTimeout: Double = 10
    var fadeOutDuration: Double = 0.5
    var fadeInDuration: Double = 0.2
    var maxLines: Int = 5
    var charLimit: Int = 200
}

struct AppConfig: Codable, Sendable {
    var hotkey: String = "cmd+/"
    var style: StyleConfig = StyleConfig()
    var behavior: BehaviorConfig = BehaviorConfig()
}

@MainActor
class ConfigManager: ObservableObject {
    static let shared = ConfigManager()

    @Published var config: AppConfig = AppConfig()

    private nonisolated let configURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/cursor-subtitles")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }()

    private var fileMonitor: DispatchSourceFileSystemObject?

    init() {
        loadConfig()
        watchConfig()
    }

    func loadConfig() {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            saveDefaultConfig()
            return
        }
        do {
            let data = try Data(contentsOf: configURL)
            let decoder = JSONDecoder()
            config = try decoder.decode(AppConfig.self, from: data)
        } catch {
            print("Failed to load config: \(error). Using defaults.")
            config = AppConfig()
        }
    }

    private func saveDefaultConfig() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configURL)
        } catch {
            print("Failed to save default config: \(error)")
        }
    }

    private func watchConfig() {
        let fd = open(configURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        fileMonitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        fileMonitor?.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.loadConfig()
            }
        }
        fileMonitor?.setCancelHandler {
            close(fd)
        }
        fileMonitor?.resume()
    }
}
