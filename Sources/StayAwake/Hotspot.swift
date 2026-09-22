import Cocoa
import ApplicationServices

/// Handles the "Carry My Workstation" feature: trigger Instant Hotspot the
/// same way a person clicking the Wi-Fi menu would, and alert the phone if it
/// doesn't connect.
///
/// There is no public API for Instant Hotspot's Bluetooth-triggered join —
/// it's a private handshake only Apple's own menu bar UI can invoke. This
/// drives that real menu via Accessibility automation instead, which means
/// it depends on Control Center's menu structure and can break on a macOS
/// update that changes it.
final class WorkstationCarrier {
    private static let contactKey = "carryWorkstationContact"

    private var contact: String? {
        get { UserDefaults.standard.string(forKey: Self.contactKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.contactKey) }
    }

    func start() {
        guard ensureContactConfigured() != nil else { return }
        guard ensureAccessibilityTrusted() else { return }
        triggerHotspotViaMenuBar { [weak self] success in
            guard let self, !success else { return }
            self.notifyFailure()
        }
    }

    /// Triggers macOS's own native "would like to control this computer"
    /// permission dialog the first time this runs, instead of failing
    /// silently. No app — including Apple's — can skip the human flipping
    /// the toggle in System Settings afterward; that's a hard OS gate.
    private func ensureAccessibilityTrusted() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let trusted = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        if !trusted {
            let alert = NSAlert()
            alert.messageText = "One More Permission"
            alert.informativeText = "StayAwake needs Accessibility access to trigger your iPhone's hotspot the same way clicking the Wi-Fi menu would. Turn on StayAwake in the Accessibility list that just opened, then try \"Carry My Workstation\" again."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        return trusted
    }

    private func ensureContactConfigured() -> String? {
        if let contact, !contact.isEmpty { return contact }

        let alert = NSAlert()
        alert.messageText = "One-Time Setup"
        alert.informativeText = "Where should StayAwake send an alert if it can't connect to your hotspot? Enter the phone number or Apple ID email you use for iMessage."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = "e.g. +1 555 123 4567 or you@icloud.com"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }

        let entered = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !entered.isEmpty else { return nil }
        contact = entered
        return entered
    }

    private func debugLog(_ message: String) {
        let line = "\(Date()): \(message)\n"
        if let data = line.data(using: .utf8) {
            let path = "/tmp/stayawake_debug.log"
            if FileManager.default.fileExists(atPath: path), let handle = FileHandle(forWritingAtPath: path) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                try? data.write(to: URL(fileURLWithPath: path))
            }
        }
    }

    private func triggerHotspotViaMenuBar(completion: @escaping (Bool) -> Void) {
        // LSUIElement apps never become the "active" app on their own, and macOS
        // seems to need that to know who to show the Apple Events consent dialog
        // for — without this, the permission request silently fails instead of
        // ever prompting.
        NSApp.activate(ignoringOtherApps: true)
        debugLog("=== Carry My Workstation: starting hotspot trigger ===")
        attemptClick(attempt: 1, maxAttempts: 6, completion: completion)
    }

    /// Control Center's Wi-Fi panel has no text labels on any of its rows —
    /// confirmed by dumping the real Accessibility tree. The Personal Hotspot
    /// entry is always the first checkbox inside the panel's scroll area; the
    /// master Wi-Fi on/off toggle lives outside that scroll area, so this
    /// never risks hitting the wrong control.
    private func attemptClick(attempt: Int, maxAttempts: Int, completion: @escaping (Bool) -> Void) {
        let script = """
        tell application "System Events"
            tell process "ControlCenter"
                set allDescriptions to description of every menu bar item of menu bar 1
                set targetIndex to 0
                repeat with i from 1 to count of allDescriptions
                    if (item i of allDescriptions) contains "Wi\u{2011}Fi" then
                        set targetIndex to i
                        exit repeat
                    end if
                end repeat
                if targetIndex is 0 then error "Wi-Fi menu bar item not found. Saw: " & (allDescriptions as string)
                set targetItem to item targetIndex of (menu bar items of menu bar 1)
                click targetItem
                delay 0.8
                set hotspotCheckbox to checkbox 1 of scroll area 1 of group 1 of window 1
                click hotspotCheckbox
            end tell
        end tell
        """
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)

        if let error {
            debugLog("attempt \(attempt)/\(maxAttempts) failed: \(error)")
        } else {
            debugLog("attempt \(attempt)/\(maxAttempts) succeeded")
        }

        guard error == nil else {
            guard attempt < maxAttempts else {
                debugLog("giving up after \(maxAttempts) attempts")
                completion(false)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.attemptClick(attempt: attempt + 1, maxAttempts: maxAttempts, completion: completion)
            }
            return
        }

        // Clicked the row successfully — Instant Hotspot's handshake still
        // takes a few seconds to actually finish connecting, and that time
        // varies — poll instead of checking once after a fixed wait.
        pollForConnection(secondsWaited: 0, completion: completion)
    }

    private func pollForConnection(secondsWaited: Int, completion: @escaping (Bool) -> Void) {
        let connected = isConnectedToHotspot()
        debugLog("connection check at +\(secondsWaited)s: \(connected ? "connected" : "not connected") (ip: \(currentIPAddress() ?? "none"))")
        if connected {
            completion(true)
            return
        }
        guard secondsWaited < 20 else {
            completion(false)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.pollForConnection(secondsWaited: secondsWaited + 2, completion: completion)
        }
    }

    /// Personal Hotspot always assigns clients an address in 172.20.10.0/24 —
    /// this is a fixed, documented Apple convention, unlike SSID name checks
    /// via `networksetup -getairportnetwork`, which proved unreliable and
    /// reported "not associated" even while genuinely connected.
    private func isConnectedToHotspot() -> Bool {
        currentIPAddress()?.hasPrefix("172.20.10.") ?? false
    }

    private func currentIPAddress() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/ipconfig")
        task.arguments = ["getifaddr", "en0"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (output?.isEmpty ?? true) ? nil : output
        } catch {
            return nil
        }
    }

    private func notifyFailure() {
        guard let contact else { return }
        let script = """
        tell application "Messages"
            set targetService to 1st service whose service type = iMessage
            set targetBuddy to buddy "\(contact)" of targetService
            send "StayAwake: couldn't connect to your iPhone's hotspot." to targetBuddy
        end tell
        """
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)
    }
}
