import Foundation

struct CursorOffset: Codable, Sendable {
    var x: CGFloat = 12
    var y: CGFloat = 12
}

struct StyleConfig: Codable, Sendable {
    var backgroundColor: String = "#1F6BE8"
    var textColor: String = "#FFFFFF"
    var placeholderText: String = "Say something"
    var fontSize: CGFloat = 14
    var fontFamily: String = "system"
    var fontWeight: String = "regular"
    var cornerRadius: CGFloat = 16
    var pointerCorner: Bool = true
    var paddingH: CGFloat = 12
    var paddingV: CGFloat = 8
    var maxWidth: CGFloat = 300
    var cursorOffset: CursorOffset = CursorOffset()
    var borderColor: String = "#FFFFFF"
    var borderOpacity: Double = 0.2
    var borderWidth: CGFloat = 2
    var shadowColor: String = "#000000"
    var shadowOpacity: Double = 0.1
    var shadowRadius: CGFloat = 3
    var shadowX: CGFloat = 0
    var shadowY: CGFloat = 5
    var backgroundOpacity: Double = 1.0
    var vibrancy: String? = nil
    var backgroundGradient: [String]? = nil
    var glassEffect: Bool = false
}

struct BehaviorConfig: Codable, Sendable {
    var idleTimeout: Double = 10
    var fadeOutDuration: Double = 0.5
    var fadeInDuration: Double = 0.2
    var charLimit: Int = 30
}

struct AppConfig: Codable, Sendable {
    var hotkey: String = "cmd+/"
    var theme: String? = nil
    var style: StyleConfig = StyleConfig()
    var behavior: BehaviorConfig = BehaviorConfig()
}

@MainActor
class ConfigManager: ObservableObject {
    static let shared = ConfigManager()

    @Published var config: AppConfig = AppConfig()

    private nonisolated let configURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/pubbles")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }()

    private nonisolated let themesURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/pubbles/themes")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private var fileMonitor: DispatchSourceFileSystemObject?

    init() {
        seedBuiltInThemes()
        loadConfig()
        watchConfig()
    }

    nonisolated func seedBuiltInThemes() {
        guard let bundlePath = Bundle.main.resourcePath else { return }
        let bundleThemes = URL(fileURLWithPath: bundlePath).appendingPathComponent("themes")
        guard FileManager.default.fileExists(atPath: bundleThemes.path) else { return }
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: bundleThemes, includingPropertiesForKeys: nil
        ) else { return }
        for file in files where file.pathExtension == "json" {
            let dest = themesURL.appendingPathComponent(file.lastPathComponent)
            if !FileManager.default.fileExists(atPath: dest.path) {
                try? FileManager.default.copyItem(at: file, to: dest)
            }
        }
    }

    private nonisolated static func deepMerge(
        _ base: [String: Any],
        _ override: [String: Any]
    ) -> [String: Any] {
        var result = base
        for (key, value) in override {
            if let baseDict = result[key] as? [String: Any],
               let overrideDict = value as? [String: Any] {
                result[key] = deepMerge(baseDict, overrideDict)
            } else {
                result[key] = value
            }
        }
        return result
    }

    func loadConfig() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let defaultData = try? encoder.encode(AppConfig()),
              var merged = try? JSONSerialization.jsonObject(with: defaultData) as? [String: Any]
        else {
            config = AppConfig()
            return
        }

        var userDict: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: configURL.path),
           let userData = try? Data(contentsOf: configURL),
           let userObj = try? JSONSerialization.jsonObject(with: userData) as? [String: Any] {
            userDict = userObj
        } else {
            saveDefaultConfig()
            // Don't return early — continue loading so defaults are applied properly
        }

        if let themeName = userDict["theme"] as? String {
            let themeFile = themesURL.appendingPathComponent("\(themeName).json")
            if let themeData = try? Data(contentsOf: themeFile),
               let themeDict = try? JSONSerialization.jsonObject(with: themeData) as? [String: Any] {
                var themeConfig = themeDict
                themeConfig.removeValue(forKey: "name")
                merged = ConfigManager.deepMerge(merged, themeConfig)
            }
        }

        merged = ConfigManager.deepMerge(merged, userDict)

        // Apply colorPreset only if the user hasn't manually set style.backgroundColor
        if let preset = userDict["colorPreset"] as? String {
            let userHasManualBgColor = (userDict["style"] as? [String: Any])?["backgroundColor"] != nil
            if !userHasManualBgColor {
                var styleDict = merged["style"] as? [String: Any] ?? [:]
                styleDict["backgroundColor"] = preset
                merged["style"] = styleDict
            }
        }

        do {
            let mergedData = try JSONSerialization.data(withJSONObject: merged)
            config = try JSONDecoder().decode(AppConfig.self, from: mergedData)
        } catch {
            print("Failed to load config: \(error). Using defaults.")
            config = AppConfig()
        }
    }

    private func saveDefaultConfig() {
        do {
            // Write minimal config so themes and color presets can take effect
            // (a full dump of defaults would override all theme values during merge)
            let minimal: [String: Any] = ["hotkey": "cmd+/"]
            let data = try JSONSerialization.data(withJSONObject: minimal, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
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

    func availableThemes() -> [(name: String, filename: String)] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: themesURL, includingPropertiesForKeys: nil
        ) else { return [] }

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { file -> (String, String)? in
                guard let data = try? Data(contentsOf: file),
                      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let name = dict["name"] as? String
                else { return nil }
                let filename = file.deletingPathExtension().lastPathComponent
                return (name, filename)
            }
            .sorted { $0.name < $1.name }
    }

    func setTheme(_ themeName: String?) {
        guard var dict = readConfigDict() else { return }
        if let themeName {
            dict["theme"] = themeName
        } else {
            dict.removeValue(forKey: "theme")
        }
        dict.removeValue(forKey: "colorPreset")
        writeConfigDict(dict)
    }

    func resetStyleOverrides() {
        guard var dict = readConfigDict() else { return }
        dict.removeValue(forKey: "style")
        dict.removeValue(forKey: "behavior")
        dict.removeValue(forKey: "colorPreset")
        writeConfigDict(dict)
    }

    func cycleTheme(forward: Bool) {
        let themes = availableThemes()
        guard !themes.isEmpty else { return }

        // Cycle order: default (nil) → themes[0] → themes[1] → ... → default → ...
        let currentTheme = config.theme
        let currentIndex = themes.firstIndex { $0.filename == currentTheme }

        if let currentIndex = currentIndex {
            if forward {
                let next = currentIndex + 1
                if next >= themes.count {
                    setTheme(nil) // wrap to default
                } else {
                    setTheme(themes[next].filename)
                }
            } else {
                let prev = currentIndex - 1
                if prev < 0 {
                    setTheme(nil) // wrap to default
                } else {
                    setTheme(themes[prev].filename)
                }
            }
        } else {
            // Currently on default
            setTheme(forward ? themes[0].filename : themes[themes.count - 1].filename)
        }
    }

    func adjustFontSize(increase: Bool) {
        let current = config.style.fontSize
        let step: CGFloat = 2
        let newSize = increase ? min(current + step, 48) : max(current - step, 8)
        guard newSize != current else { return }
        guard var dict = readConfigDict() else { return }
        var styleDict = dict["style"] as? [String: Any] ?? [:]
        styleDict["fontSize"] = newSize
        dict["style"] = styleDict
        writeConfigDict(dict)
    }

    func setColor(_ hex: String) {
        guard var dict = readConfigDict() else { return }
        dict["colorPreset"] = hex
        writeConfigDict(dict)
    }

    private func readConfigDict() -> [String: Any]? {
        guard let data = try? Data(contentsOf: configURL),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return dict
    }

    private func writeConfigDict(_ dict: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            try data.write(to: configURL)
        } catch {
            print("Failed to write config: \(error)")
        }
    }
}
