import AppKit
import ServiceManagement

/// Icon sizes offered in the menu. Heights are in points; the menu bar is about 24 pt tall.
enum IconSize: String, CaseIterable {
    case small, medium, large

    var title: String { rawValue.capitalized }

    var height: CGFloat {
        switch self {
        case .small: 16
        case .medium: 20
        case .large: 24
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .small: 11
        case .medium: 12
        case .large: 13
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let customPrefix = "custom:"
    private static let showPercentKey = "showPercent"
    private static let sampleInterval: TimeInterval = 1.0
    private static let minFPS = 4.0     // idle CPU
    private static let maxFPS = 40.0    // fully loaded CPU

    private static let characterKey = "character"
    private static let sizeKey = "iconSize"

    // Fixed length (set in applyAppearance): a variable-length item is re-measured on every change.
    private let statusItem = NSStatusBar.system.statusItem(withLength: 40)
    private let monitor = CPUMonitor()
    private let runner = RunnerView()

    private var smoothedLoad = 0.0
    private var animationTimer: Timer?
    private var sampleTimer: Timer?

    private let totalItem = NSMenuItem(title: "CPU: —", action: nil, keyEquivalent: "")
    private let breakdownItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let coresItem = NSMenuItem(title: "Per core", action: nil, keyEquivalent: "")
    private let coresMenu = NSMenu()
    private let showPercentItem = NSMenuItem(title: "Show percentage", action: #selector(toggleShowPercent), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Launch at login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")

    private let characterMenu = NSMenu()
    private let sizeMenu = NSMenu()

    /// A built-in character's raw value ("cat"), or "custom:<name>" for one from the Runners folder.
    private var runnerID: String {
        get { UserDefaults.standard.string(forKey: Self.characterKey) ?? RunnerCharacter.cat.rawValue }
        set { UserDefaults.standard.set(newValue, forKey: Self.characterKey) }
    }

    private var iconSize: IconSize {
        get { UserDefaults.standard.string(forKey: Self.sizeKey).flatMap(IconSize.init) ?? .medium }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Self.sizeKey) }
    }

    private var showPercent: Bool {
        get { UserDefaults.standard.bool(forKey: Self.showPercentKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.showPercentKey) }
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [Self.showPercentKey: true])

        if let button = statusItem.button {
            runner.frame = button.bounds
            button.addSubview(runner)
            button.setAccessibilityLabel("SimaRun CPU activity")
        }
        buildMenu()
        applyAppearance()

        _ = monitor.sample() // prime the counters; the first real reading arrives one interval later
        let timer = Timer(timeInterval: Self.sampleInterval, target: self,
                          selector: #selector(sampleCPU), userInfo: nil, repeats: true)
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common) // .common keeps it firing while the menu is open
        sampleTimer = timer

        restartAnimation(fps: Self.minFPS)
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        totalItem.isEnabled = false
        breakdownItem.isEnabled = false
        coresItem.submenu = coresMenu
        coresMenu.autoenablesItems = false

        showPercentItem.target = self
        showPercentItem.state = showPercent ? .on : .off
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off

        let characterItem = NSMenuItem(title: "Character", action: nil, keyEquivalent: "")
        characterItem.submenu = characterMenu
        characterMenu.delegate = self // rebuilt each time it opens, so new custom runners appear
        rebuildCharacterMenu()

        let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        sizeMenu.items = IconSize.allCases.map { choice in
            let item = NSMenuItem(title: choice.title, action: #selector(chooseSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = choice.rawValue
            return item
        }

        let quit = NSMenuItem(title: "Quit SimaRun", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        menu.items = [totalItem, breakdownItem, coresItem, .separator(),
                      characterItem, sizeItem, showPercentItem, .separator(),
                      loginItem, .separator(), quit]
        statusItem.menu = menu
    }

    @objc private func toggleShowPercent() {
        showPercent.toggle()
        showPercentItem.state = showPercent ? .on : .off
        if !showPercent { runner.text = "" }
        applyAppearance()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === characterMenu { rebuildCharacterMenu() }
    }

    private func rebuildCharacterMenu() {
        func item(_ title: String, id: String) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: #selector(chooseCharacter(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = id
            item.state = id == runnerID ? .on : .off
            return item
        }

        var items = RunnerCharacter.allCases.map { item($0.title, id: $0.rawValue) }
        let custom = CustomRunners.names()
        if !custom.isEmpty {
            items.append(.separator())
            items += custom.map { item($0, id: Self.customPrefix + $0) }
        }
        items.append(.separator())
        let open = NSMenuItem(title: "Open Custom Runners Folder", action: #selector(openRunnersFolder), keyEquivalent: "")
        open.target = self
        items.append(open)
        characterMenu.items = items
    }

    @objc private func chooseCharacter(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        runnerID = id
        applyAppearance()
    }

    @objc private func openRunnersFolder() {
        try? FileManager.default.createDirectory(at: CustomRunners.folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(CustomRunners.folder)
    }

    @objc private func chooseSize(_ sender: NSMenuItem) {
        guard let choice = (sender.representedObject as? String).flatMap(IconSize.init) else { return }
        iconSize = choice
        applyAppearance()
    }

    /// Applies the chosen character, size and percentage setting to the status item.
    private func applyAppearance() {
        let size = iconSize
        var frames: [CGImage]
        var tinted = true
        var aspect: CGFloat // width / height

        if runnerID.hasPrefix(Self.customPrefix),
           let custom = CustomRunners.load(name: String(runnerID.dropFirst(Self.customPrefix.count))),
           let first = custom.frames.first {
            frames = custom.frames
            tinted = custom.tinted
            aspect = min(CGFloat(first.width) / CGFloat(first.height), 4) // keep very wide images in check
        } else {
            // Built-in, or a custom runner that has been removed: fall back to the cat.
            let character = RunnerCharacter(rawValue: runnerID) ?? .cat
            frames = character.makeFrames()
            aspect = character.canvas.width / character.canvas.height
        }

        // Never taller than the menu bar itself.
        let height = min(size.height, NSStatusBar.system.thickness - 2)
        let icon = NSSize(width: (height * aspect).rounded(), height: height)

        runner.configure(frames: frames, tinted: tinted, iconSize: icon, fontSize: size.fontSize)
        statusItem.length = runner.requiredWidth(showingText: showPercent)

        for item in sizeMenu.items {
            item.state = (item.representedObject as? String) == size.rawValue ? .on : .off
        }
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change the login item"
            alert.informativeText = "\(error.localizedDescription)\n\nMove SimaRun.app to /Applications and try again."
            NSApp.activate()
            alert.runModal()
        }
        loginItem.state = service.status == .enabled ? .on : .off
    }

    // MARK: - CPU sampling

    @objc private func sampleCPU() {
        guard let sample = monitor.sample() else { return }

        // Light smoothing so the runner doesn't change pace abruptly on short spikes.
        smoothedLoad = smoothedLoad * 0.5 + sample.total * 0.5
        restartAnimation(fps: Self.minFPS + (Self.maxFPS - Self.minFPS) * smoothedLoad)

        if showPercent {
            runner.text = percent(sample.total)
        }

        totalItem.title = "CPU: \(percent(sample.total))"
        breakdownItem.title = "User \(percent(sample.user))   System \(percent(sample.system))   Idle \(percent(sample.idle))"
        updateCoreRows(sample.cores)
    }

    private func updateCoreRows(_ cores: [Double]) {
        if coresMenu.items.count != cores.count {
            coresMenu.items = cores.map { _ in
                let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
                item.isEnabled = false
                return item
            }
        }
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        let width = String(cores.count).count
        for (index, load) in cores.enumerated() {
            let filled = Int((load * 10).rounded())
            let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: 10 - filled)
            let number = String(index + 1).leftPadded(to: width)
            let value = percent(load).leftPadded(to: 4)
            coresMenu.items[index].attributedTitle = NSAttributedString(
                string: "Core \(number)  \(bar)  \(value)", attributes: [.font: font])
        }
    }

    private func percent(_ fraction: Double) -> String {
        "\(Int((min(max(fraction, 0), 1) * 100).rounded()))%"
    }

    // MARK: - Animation

    private func restartAnimation(fps: Double) {
        let interval = 1.0 / fps
        if let current = animationTimer, abs(current.timeInterval - interval) / interval < 0.05 {
            return // close enough; avoid needless timer churn
        }
        animationTimer?.invalidate()
        let timer = Timer(timeInterval: interval, target: self,
                          selector: #selector(advanceFrame), userInfo: nil, repeats: true)
        timer.tolerance = interval * 0.1
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    @objc private func advanceFrame() {
        runner.advanceFrame()
    }
}

private extension String {
    func leftPadded(to length: Int) -> String {
        String(repeating: " ", count: max(0, length - count)) + self
    }
}
