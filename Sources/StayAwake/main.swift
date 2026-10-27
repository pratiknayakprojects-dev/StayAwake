import Cocoa
import IOKit.pwr_mgt
import IOKit.ps
import UserNotifications
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
        // Never unregister to "refresh" the helper: that revokes the user's approval in System Settings.
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
    private let workstationCarrier = WorkstationCarrier()
    private let license = License.shared
    private var timer: Timer?
    private var signalSources: [DispatchSourceSignal] = []
    /// Plus-address on the project mailbox: lands in the same inbox, filterable by the +stayawake tag.
    private let supportEmail = "pratiknayakprojects+stayawake@gmail.com"
    private var secondsRemaining: Int = 0
    private var selectedDuration: Duration = .untilOff
    /// Why the last session ended on its own (hot Mac, low battery); shown in the menu until the next start.
    private var lastStopReason: String?
    private let defaults = UserDefaults.standard
    private var thermalCutoffOn: Bool { defaults.bool(forKey: "thermalCutoff") }
    /// Battery percent below which closed-lid mode stops; 0 = off.
    private var batteryCutoff: Int { defaults.integer(forKey: "batteryCutoff") }

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

    /// An accessory app has no main menu, so ⌘V/⌘C/⌘X/⌘A never reach text fields (the license
    /// dialog). An invisible Edit menu supplies those key equivalents.
    private func installEditMenu() {
        let edit = NSMenu(title: "Edit")
        for (title, action, key) in [("Cut", #selector(NSText.cut(_:)), "x"), ("Copy", #selector(NSText.copy(_:)), "c"),
                                     ("Paste", #selector(NSText.paste(_:)), "v"), ("Select All", #selector(NSText.selectAll(_:)), "a")] {
            edit.addItem(withTitle: title, action: action, keyEquivalent: key)
        }
        let item = NSMenuItem()
        item.submenu = edit
        let main = NSMenu()
        main.addItem(item)
        NSApp.mainMenu = main
    }

    /// Two install mistakes: running straight from the disk image, and opening a new copy while an
    /// old one is still running (duplicate icons, stale version). Returns false if this launch must stop.
    private func resolveLaunchProblems() -> Bool {
        if Bundle.main.bundlePath.hasPrefix("/Volumes/") {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Move StayAwake to Applications first"
            alert.informativeText = "Drag StayAwake onto the Applications folder in the disk image window, eject the disk image, then open StayAwake from Applications."
            alert.addButton(withTitle: "Show Me")
            alert.addButton(withTitle: "Quit")
            if alert.runModal() == .alertFirstButtonReturn {
                // The volume root holds StayAwake.app and the Applications shortcut side by side.
                NSWorkspace.shared.open(URL(fileURLWithPath: Bundle.main.bundlePath).deletingLastPathComponent())
            }
            NSApp.terminate(nil)
            return false
        }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0 != NSRunningApplication.current }
        others.forEach { $0.terminate() }
        let deadline = Date().addingTimeInterval(3)
        while others.contains(where: { !$0.isTerminated }) && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard resolveLaunchProblems() else { return }
        installEditMenu()
        // `kill`/`pkill` (SIGTERM) would otherwise skip applicationWillTerminate and leave sleep blocked.
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { NSApp.terminate(nil) }
            source.resume()
            signalSources.append(source)
        }
        // A session started before the trial ended (e.g. "Until Off") must not outlive it.
        _ = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self, self.power.isAwake, self.license.state == .expired else { return }
            self.stop()
            _ = self.ensureAllowed()
        }
        defaults.register(defaults: ["thermalCutoff": true, "batteryCutoff": 10])
        NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.checkSafety()
        }
        _ = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.checkSafety() }
        power.syncFromSystem()
        _ = license.state // first launch starts the trial clock
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

        let statusText = power.isAwake ? statusLine() : (lastStopReason ?? "Not keeping your Mac awake")
        let statusEntry = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusEntry.isEnabled = false
        menu.addItem(statusEntry)
        switch license.state {
        case .licensed:
            break
        case .trial(let daysLeft):
            let trialEntry = NSMenuItem(title: "Free trial: \(daysLeft) day\(daysLeft == 1 ? "" : "s") left", action: nil, keyEquivalent: "")
            trialEntry.isEnabled = false
            menu.addItem(trialEntry)
        case .expired:
            let trialEntry = NSMenuItem(title: "Trial ended. Buy a license to keep using StayAwake.", action: nil, keyEquivalent: "")
            trialEntry.isEnabled = false
            menu.addItem(trialEntry)
        }
        menu.addItem(.separator())

        let carryItem = NSMenuItem(title: "Carry My Workstation (Beta)", action: #selector(carryMyWorkstation), keyEquivalent: "")
        carryItem.target = self
        menu.addItem(carryItem)

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

        let safety = NSMenuItem(title: "Lid-Closed Safety", action: nil, keyEquivalent: "")
        let safetyMenu = NSMenu()
        let hot = NSMenuItem(title: "Stop if Mac Gets Hot", action: #selector(toggleThermalCutoff), keyEquivalent: "")
        hot.target = self
        hot.state = thermalCutoffOn ? .on : .off
        safetyMenu.addItem(hot)
        safetyMenu.addItem(.separator())
        let header = NSMenuItem(title: "Stop When Battery Falls Below", action: nil, keyEquivalent: "")
        header.isEnabled = false
        safetyMenu.addItem(header)
        for pct in [0, 10, 20, 30] {
            let item = NSMenuItem(title: pct == 0 ? "Never" : "\(pct)%", action: #selector(pickBatteryCutoff(_:)), keyEquivalent: "")
            item.target = self
            item.tag = pct
            item.state = (pct == batteryCutoff) ? .on : .off
            safetyMenu.addItem(item)
        }
        safety.submenu = safetyMenu
        menu.addItem(safety)

        menu.addItem(.separator())
        let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)
        menu.addItem(.separator())
        if license.state != .licensed {
            let buy = NSMenuItem(title: "Buy StayAwake (\(License.priceLabel))…", action: #selector(buyLicense), keyEquivalent: "")
            buy.target = self
            menu.addItem(buy)
            let enter = NSMenuItem(title: "Enter License Key…", action: #selector(enterLicenseKey), keyEquivalent: "")
            enter.target = self
            menu.addItem(enter)
            menu.addItem(.separator())
        }
        let support = NSMenuItem(title: "Contact Support…", action: #selector(contactSupport), keyEquivalent: "")
        support.target = self
        menu.addItem(support)
        let version = NSMenuItem(title: "Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")", action: nil, keyEquivalent: "")
        version.isEnabled = false
        menu.addItem(version)
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

    @objc private func toggleThermalCutoff() {
        defaults.set(!thermalCutoffOn, forKey: "thermalCutoff")
        buildMenu()
    }

    @objc private func pickBatteryCutoff(_ sender: NSMenuItem) {
        defaults.set(sender.tag, forKey: "batteryCutoff")
        buildMenu()
    }

    /// Battery percent, or nil when on AC power or there is no battery (a desktop Mac never trips this).
    private func batteryPercentOnBattery() -> Int? {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        for source in IOPSCopyPowerSourcesList(info).takeRetainedValue() as Array {
            guard let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  d[kIOPSPowerSourceStateKey] as? String == kIOPSBatteryPowerValue,
                  let cur = d[kIOPSCurrentCapacityKey] as? Int, let max = d[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            return cur * 100 / max
        }
        return nil
    }

    /// A Mac with the lid shut in a bag can't cool or be noticed, so closed-lid mode gives sleep back
    /// when it runs hot or the battery is low. Plain Keep Awake (lid open) is left alone.
    private func checkSafety() {
        guard power.isAwake, power.lidClosedAllowed else { return }
        var reason: String?
        if thermalCutoffOn, ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue {
            reason = "Stopped: your Mac was getting hot"
        } else if batteryCutoff > 0, let pct = batteryPercentOnBattery(), pct < batteryCutoff {
            reason = "Stopped: battery fell below \(batteryCutoff)%"
        }
        guard let reason else { return }
        stop()
        lastStopReason = reason
        buildMenu()
        notify(reason)
    }

    private func notify(_ text: String) {
        let content = UNMutableNotificationContent()
        content.title = "StayAwake"
        content.body = text + ". Your Mac can sleep normally again."
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    /// Preset: lid-closed protection for exactly one hour, plus an attempt to
    /// rejoin the iPhone's hotspot so the Mac stays networked in a bag too.
    @objc private func carryMyWorkstation() {
        guard ensureAllowed() else { return }
        lastStopReason = nil
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
        power.startAwake(lidClosed: true)
        selectedDuration = .oneHour
        startCountdownIfNeeded(reset: true)
        updateButton()
        buildMenu()
        workstationCarrier.start()
    }

    @objc private func chooseAwake() {
        guard ensureAllowed() else { return }
        lastStopReason = nil
        power.startAwake(lidClosed: false)
        startCountdownIfNeeded(reset: true)
        updateButton()
        buildMenu()
    }

    @objc private func chooseAwakeLidClosed() {
        guard ensureAllowed() else { return }
        lastStopReason = nil
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
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

    @objc private func toggleLoginItem() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            showMessage("Couldn't change Open at Login: \(error.localizedDescription)")
        }
        if service.status == .requiresApproval {
            showMessage("Turn on StayAwake in System Settings > General > Login Items to finish.")
            SMAppService.openSystemSettingsLoginItems()
        }
        buildMenu()
    }

    // MARK: Licensing

    private func ensureAllowed() -> Bool {
        if license.state != .expired { return true }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Your \(License.trialDays)-day trial has ended"
        alert.informativeText = "StayAwake is \(License.priceLabel), one time. Buy a license, or enter the key you already have."
        alert.addButton(withTitle: "Buy StayAwake")
        alert.addButton(withTitle: "Enter License Key")
        alert.addButton(withTitle: "Not Now")
        switch alert.runModal() {
        case .alertFirstButtonReturn: buyLicense()
        case .alertSecondButtonReturn: enterLicenseKey()
        default: break
        }
        return false
    }

    @objc private func buyLicense() {
        guard License.isConfigured else { return showMessage("Purchasing isn't set up yet.") }
        NSWorkspace.shared.open(License.checkoutURL)
    }

    @objc private func contactSupport() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        var mail = URLComponents()
        mail.scheme = "mailto"
        mail.path = supportEmail
        mail.queryItems = [
            URLQueryItem(name: "subject", value: "StayAwake \(version) support"),
            URLQueryItem(name: "body", value: "What happened?\n\n\n--\nStayAwake \(version), \(ProcessInfo.processInfo.operatingSystemVersionString)"),
        ]
        if let url = mail.url { NSWorkspace.shared.open(url) }
    }

    @objc private func enterLicenseKey() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Enter your license key"
        alert.informativeText = "It's in the email you got after buying StayAwake."
        alert.addButton(withTitle: "Activate")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        license.activate(key: key) { [weak self] result in
            switch result {
            case .success: self?.showMessage("Thanks. StayAwake is unlocked.")
            case .failure(let error): self?.showMessage(error.message)
            }
            self?.buildMenu()
        }
    }

    private func showMessage(_ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = text
        alert.runModal()
    }
}

if CommandLine.arguments.contains("--selftest") {
    License.selfTest()
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
