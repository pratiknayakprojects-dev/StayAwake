import Foundation

public let helperMachServiceName = "com.pratiknayak.stayawake.helper"
public let helperDaemonPlistName = "com.pratiknayak.stayawake.helper.plist"

@objc public protocol StayAwakeHelperProtocol {
    func setDisableSleep(_ disabled: Bool, reply: @escaping (Bool) -> Void)
}
