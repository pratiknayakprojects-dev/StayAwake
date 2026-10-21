import Foundation
import Security
import StayAwakeShared

// Requirement string mirrors the one macOS generated for our Developer ID cert —
// only a process signed with this exact Team ID may connect to this root daemon.
private let clientRequirement = "anchor apple generic and certificate leaf[subject.OU] = \"5UZSA4DB7V\""

private func isConnectionAuthorized(_ connection: NSXPCConnection) -> Bool {
    var code: SecCode?
    let attributes = [kSecGuestAttributePid: connection.processIdentifier] as CFDictionary
    guard SecCodeCopyGuestWithAttributes(nil, attributes, [], &code) == errSecSuccess, let code else {
        return false
    }
    var requirement: SecRequirement?
    guard SecRequirementCreateWithString(clientRequirement as CFString, [], &requirement) == errSecSuccess,
          let requirement else {
        return false
    }
    return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
}

private func setPmsetDisableSleep(_ disabled: Bool) -> Bool {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    task.arguments = ["-a", "disablesleep", disabled ? "1" : "0"]
    do {
        try task.run()
        task.waitUntilExit()
        return task.terminationStatus == 0
    } catch {
        return false
    }
}

final class HelperService: NSObject, StayAwakeHelperProtocol {
    private var sleepDisabledByApp = false

    func setDisableSleep(_ disabled: Bool, reply: @escaping (Bool) -> Void) {
        let ok = setPmsetDisableSleep(disabled)
        if ok { sleepDisabledByApp = disabled }
        reply(ok)
    }

    /// The app owns this system setting. If it quits, crashes or is killed while closed-lid mode is
    /// on, give sleep back so a Mac in a bag can't stay awake until the battery dies.
    func restoreSleepIfNeeded() {
        guard sleepDisabledByApp else { return }
        if setPmsetDisableSleep(false) { sleepDisabledByApp = false }
    }
}

final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard isConnectionAuthorized(connection) else { return false }
        connection.exportedInterface = NSXPCInterface(with: StayAwakeHelperProtocol.self)
        let service = HelperService()
        connection.exportedObject = service
        connection.invalidationHandler = { service.restoreSleepIfNeeded() }
        connection.interruptionHandler = { service.restoreSleepIfNeeded() }
        connection.resume()
        return true
    }
}

let delegate = ListenerDelegate()
let listener = NSXPCListener(machServiceName: helperMachServiceName)
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
