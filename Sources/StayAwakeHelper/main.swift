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

final class HelperService: NSObject, StayAwakeHelperProtocol {
    func setDisableSleep(_ disabled: Bool, reply: @escaping (Bool) -> Void) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["-a", "disablesleep", disabled ? "1" : "0"]
        do {
            try task.run()
            task.waitUntilExit()
            reply(task.terminationStatus == 0)
        } catch {
            reply(false)
        }
    }
}

final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard isConnectionAuthorized(connection) else { return false }
        connection.exportedInterface = NSXPCInterface(with: StayAwakeHelperProtocol.self)
        connection.exportedObject = HelperService()
        connection.resume()
        return true
    }
}

let delegate = ListenerDelegate()
let listener = NSXPCListener(machServiceName: helperMachServiceName)
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
