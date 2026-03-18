import AppKit

@MainActor
class UpdateChecker {
    static let shared = UpdateChecker()

    private let repo = "shub-rajput/pubbles"
    private let installScriptURL = "https://raw.githubusercontent.com/shub-rajput/pubbles/main/scripts/install.sh"
    private let skippedVersionKey = "skippedUpdateVersion"

    private(set) var latestVersion: String?
    private(set) var updateAvailable = false

    var onUpdateStatusChanged: (() -> Void)?

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func checkForUpdates(silent: Bool = true) {
        let urlString = "https://api.github.com/repos/\(repo)/releases/latest"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let data = data, error == nil else {
                if !silent {
                    DispatchQueue.main.async { self?.showError("Could not reach GitHub. Check your internet connection.") }
                }
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                if !silent {
                    DispatchQueue.main.async { self?.showError("Could not parse release info from GitHub.") }
                }
                return
            }

            let remote = tagName.replacingOccurrences(of: "v", with: "")

            DispatchQueue.main.async {
                self?.latestVersion = remote
                self?.updateAvailable = self?.isNewer(remote: remote) ?? false
                self?.onUpdateStatusChanged?()

                if self?.updateAvailable == true {
                    let skipped = UserDefaults.standard.string(forKey: self?.skippedVersionKey ?? "")
                    if !silent || skipped != remote {
                        self?.promptAndUpdate()
                    }
                } else if !silent {
                    self?.showUpToDate()
                }
            }
        }.resume()
    }

    func promptAndUpdate() {
        guard updateAvailable, let latest = latestVersion else { return }

        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "Pubbles \(latest) is available (you have \(currentVersion)).\n\nThis will quit the app, install the update, and relaunch."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Update Now")
        alert.addButton(withTitle: "Skip This Version")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            runInstallScript()
        } else if response == .alertSecondButtonReturn {
            UserDefaults.standard.set(latest, forKey: skippedVersionKey)
        }
    }

    private func runInstallScript() {
        // Write a temporary script to /tmp (outside app sandbox)
        let scriptPath = "/tmp/pubbles_update.sh"
        let script = """
        #!/bin/bash
        sleep 1
        curl -fsSL '\(installScriptURL)' -o /tmp/pubbles_install.sh
        chmod +x /tmp/pubbles_install.sh
        /bin/bash /tmp/pubbles_install.sh
        rm -f /tmp/pubbles_install.sh \(scriptPath)
        """
        try? script.write(toFile: scriptPath, atomically: true, encoding: .utf8)

        // Launch as a detached launchd job so it survives app termination
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = [
            "submit", "-l", "com.pubbles.update",
            "--", "/bin/bash", scriptPath
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()

        // Quit ourselves so the install script can replace the app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.terminate(nil)
        }
    }

    private func isNewer(remote: String) -> Bool {
        let current = parseVersion(currentVersion)
        let latest = parseVersion(remote)

        for i in 0..<max(current.count, latest.count) {
            let c = i < current.count ? current[i] : 0
            let l = i < latest.count ? latest[i] : 0
            if l > c { return true }
            if l < c { return false }
        }
        return false
    }

    private func parseVersion(_ version: String) -> [Int] {
        version.split(separator: ".").compactMap { Int($0) }
    }

    private func showUpToDate() {
        let alert = NSAlert()
        alert.messageText = "You're up to date"
        alert.informativeText = "Pubbles \(currentVersion) is the latest version."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Update Check Failed"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
