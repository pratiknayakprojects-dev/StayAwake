import Cocoa
import IOKit.pwr_mgt
import ServiceManagement
import StayAwakeShared

// MARK: - Power control

enum Duration: Int, CaseIterable {
    case tenMin = 600
    case thirtyMin = 1800
    case oneHour = 3600
    case threeHours = 10800
    case untilOff = 0

    var label: String {
        switch self {
        case .tenMin: return "10 Minutes"
        case .thirtyMin: return "30 Minutes"
        case .oneHour: return "1 Hour"
        case .threeHours: return "3 Hours"
        case .untilOff: return "Until I Turn It Off"
        }
    }
}

final class PowerManager {
    private var assertionID: IOPMAssertionID = 0
    private(set) var isAwake = false
    private(set) var lidClosedAllowed = false

    /// Reads the real system state so the app never lies about what's active,
    /// even if it was force-quit last time instead of stopped normally.
    func syncFromSystem() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["-g"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            lidClosedAllowed = output.contains("SleepDisabled") && output.contains("SleepDisabled\t\t1") || output.range(of: #"SleepDisabled\s+1"#, options: .regularExpression) != nil
        } catch {
            lidClosedAllowed = false
        }
    }

    func startAwake(lidClosed: Bool) {
        if !isAwake {
            let reason = "StayAwake: user requested" as CFString
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoIdleSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &assertionID
            )
            isAwake = (result == kIOReturnSuccess)
        }
        if lidClosed != lidClosedAllowed {
            setLidClosedAllowed(lidClosed)
        }
    }

    func stop() {
        if isAwake {
            IOPMAssertionRelease(assertionID)
            isAwake = false
        }
        if lidClosedAllowed {
            setLidClosedAllowed(false)
        }
    }

    // MARK: - Privileged helper (one-time authorization, zero prompts after)

    private let daemonService = SMAppService.daemon(plistName: helperDaemonPlistName)
    private var helperConnection: NSXPCConnection?

    enum HelperRegistrationResult {
        case ready
        case needsApprovalInSystemSettings
        case failed(Error)
    }

    /// Registers the root-running helper daemon. On a brand-new install this is
    /// the ONE point where the user authorizes anything — either a system prompt
    /// or a one-time manual approval in System Settings > Login Items. Every
    /// future lid-closed toggle after this talks to the already-running daemon
    /// with no further authorization of any kind.
    @discardableResult
    func registerHelperIfNeeded() -> HelperRegistrationResult {
        switch daemonService.status {
        case .enabled:
            return .ready
        case .requiresApproval:
            return .needsApprovalInSystemSettings
        default:
            do {
                try daemonService.register()
                return daemonService.status == .enabled ? .ready : .needsApprovalInSystemSettings
            } catch {
                return .failed(error)
            }
        }
    }

    private func connection() -> NSXPCConnection {
        if let helperConnection { return helperConnection }
        let connection = NSXPCConnection(machServiceName: helperMachServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: StayAwakeHelperProtocol.self)
        connection.invalidationHandler = { [weak self] in self?.helperConnection = nil }
        connection.resume()
        helperConnection = connection
        return connection
    }

    /// No admin prompt of any kind — the daemon already runs as root.
    private func setLidClosedAllowed(_ allowed: Bool) {
        guard case .ready = registerHelperIfNeeded() else { return }
        let proxy = connection().remoteObjectProxyWithErrorHandler { _ in } as? StayAwakeHelperProtocol
        let semaphore = DispatchSemaphore(value: 0)
        var succeeded = false
        proxy?.setDisableSleep(allowed) { ok in
            succeeded = ok
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 5)
        if succeeded {
            lidClosedAllowed = allowed
        }
    }
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let power = PowerManager()
    private var timer: Timer?
    private var secondsRemaining: Int = 0
    private var selectedDuration: Duration = .untilOff

    /// Draws a coffee cup whose fill level reflects time remaining.
    /// fraction 0 = empty outline, 1 = full cup. Template image so it
    /// auto-adapts to light/dark menu bars.
    private func cupImage(fraction: CGFloat) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let body = NSRect(x: 3, y: 3, width: 10, height: 11)
            let bodyPath = NSBezierPath(roundedRect: body, xRadius: 2, yRadius: 2)

            if fraction > 0 {
                NSGraphicsContext.current?.saveGraphicsState()
                bodyPath.addClip()
                let fillHeight = body.height * min(max(fraction, 0), 1)
                let fillRect = NSRect(x: body.minX, y: body.minY, width: body.width, height: fillHeight)
                NSColor.black.setFill()
                NSBezierPath(rect: fillRect).fill()
                NSGraphicsContext.current?.restoreGraphicsState()
            }

            NSColor.black.setStroke()
            bodyPath.lineWidth = 1.3
            bodyPath.stroke()

            let handle = NSBezierPath()
            handle.appendArc(withCenter: NSPoint(x: 13.5, y: 8.5), radius: 2.6, startAngle: -80, endAngle: 80)
            handle.lineWidth = 1.3
            handle.stroke()

            return true
        }
        image.isTemplate = true
        return image
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        power.syncFromSystem()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateButton()
        buildMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        power.stop()
    }

    // MARK: Menu

    private func buildMenu() {
        let menu = NSMenu()

        let statusText = power.isAwake ? statusLine() : "Not keeping your Mac awake"
        let statusEntry = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusEntry.isEnabled = false
        menu.addItem(statusEntry)
        menu.addItem(.separator())

        // Three mutually exclusive states — exactly one is ever checked.
        let offItem = NSMenuItem(title: "Off", action: #selector(chooseOff), keyEquivalent: "")
        offItem.target = self
        offItem.state = (!power.isAwake) ? .on : .off
        menu.addItem(offItem)

        let awakeItem = NSMenuItem(title: "Keep Awake", action: #selector(chooseAwake), keyEquivalent: "")
        awakeItem.target = self
        awakeItem.state = (power.isAwake && !power.lidClosedAllowed) ? .on : .off
        menu.addItem(awakeItem)

        let lidItem = NSMenuItem(title: "Keep Awake When Lid Closed", action: #selector(chooseAwakeLidClosed), keyEquivalent: "")
        lidItem.target = self
        lidItem.state = (power.isAwake && power.lidClosedAllowed) ? .on : .off
        menu.addItem(lidItem)

        menu.addItem(.separator())

        // Advanced option, tucked away so it doesn't compete with the two switches above.
        let autoStop = NSMenuItem(title: "Auto-Stop After", action: nil, keyEquivalent: "")
        let autoStopMenu = NSMenu()
        for duration in Duration.allCases {
            let item = NSMenuItem(title: duration.label, action: #selector(pickDuration(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = duration
            item.state = (duration == selectedDuration) ? .on : .off
            autoStopMenu.addItem(item)
        }
        autoStop.submenu = autoStopMenu
        menu.addItem(autoStop)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit StayAwake", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func statusLine() -> String {
        let lidNote = power.lidClosedAllowed ? " (lid can be closed)" : ""
        if selectedDuration == .untilOff || secondsRemaining <= 0 {
            return "Awake\(lidNote)"
        }
        let mins = secondsRemaining / 60
        let secs = secondsRemaining % 60
        return String(format: "Awake%@ — %d:%02d left", lidNote, mins, secs)
    }

    /// Keeps the menu-bar icon itself showing live status (filled cup + countdown),
    /// so the state is visible without opening the dropdown.
    private func updateButton() {
        guard let button = statusItem.button else { return }
        if power.isAwake {
            let fraction: CGFloat
            if selectedDuration != .untilOff, selectedDuration.rawValue > 0 {
                fraction = CGFloat(secondsRemaining) / CGFloat(selectedDuration.rawValue)
                let mins = secondsRemaining / 60
                let secs = secondsRemaining % 60
                button.title = String(format: " %d:%02d", mins, secs)
            } else {
                fraction = 1
                button.title = ""
            }
            button.image = cupImage(fraction: fraction)
            button.image?.accessibilityDescription = "StayAwake — awake"
        } else {
            button.image = cupImage(fraction: 0)
            button.image?.accessibilityDescription = "StayAwake — asleep"
            button.title = ""
        }
    }

    // MARK: Actions

    @objc private func chooseOff() {
        stop()
    }

    @objc private func chooseAwake() {
        power.startAwake(lidClosed: false)
        startCountdownIfNeeded(reset: true)
        updateButton()
        buildMenu()
    }

    @objc private func chooseAwakeLidClosed() {
        power.startAwake(lidClosed: true)
        startCountdownIfNeeded(reset: true)
        updateButton()
        buildMenu()
    }

    @objc private func pickDuration(_ sender: NSMenuItem) {
        guard let duration = sender.representedObject as? Duration else { return }
        selectedDuration = duration
        if power.isAwake {
            startCountdownIfNeeded(reset: true)
            updateButton()
        }
        buildMenu()
    }

    private func startCountdownIfNeeded(reset: Bool = true) {
        timer?.invalidate()
        timer = nil
        guard selectedDuration != .untilOff else { return }
        if reset {
            secondsRemaining = selectedDuration.rawValue
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.secondsRemaining -= 1
            if self.secondsRemaining <= 0 {
                self.stop()
            } else {
                self.updateButton()
                self.buildMenu()
            }
        }
    }

    @objc private func stop() {
        power.stop()
        timer?.invalidate()
        timer = nil
        updateButton()
        buildMenu()
    }

    @objc private func quit() {
        stop()
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
