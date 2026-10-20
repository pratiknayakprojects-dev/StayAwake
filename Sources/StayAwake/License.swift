import Cocoa
import Security

/// 7-day trial, then a one-time license key sold through Gumroad.
/// Trial start and key live in the Keychain so reinstalling doesn't reset the trial.
/// ponytail: key is checked once at activation (a later refund doesn't revoke it), no
/// clock-tamper check, and the code is MIT, so this is an honest-user paywall.
/// Re-verify weekly with increment_uses_count=false only if refunds start to matter.
final class License {
    static let shared = License()

    static let priceLabel = "$4.99"
    static let trialDays = 7
    /// Gumroad counts every verify as a "use"; this is the most Macs one key can activate.
    static let maxActivations = 5

    // Fill both from the Gumroad product page once it exists.
    static let checkoutURL = URL(string: "https://pratikprojects.gumroad.com/l/efsecq")!
    static let productID = "I9wncJk2OLsDVAKc8pDjBA=="
    static var isConfigured: Bool { !productID.isEmpty }

    enum State: Equatable {
        case licensed
        case trial(daysLeft: Int)
        case expired
    }

    enum LicenseError: Error {
        case notConfigured
        case network
        case unreadable
        case rejected(String)

        var message: String {
            switch self {
            case .notConfigured: return "Purchasing isn't set up yet."
            case .network: return "Couldn't reach the license server. Check your connection and try again."
            case .unreadable: return "The license server sent a reply StayAwake couldn't read."
            case .rejected(let reason): return reason
            }
        }
    }

    static func state(trialStart: Date, hasKey: Bool, now: Date = Date()) -> State {
        if hasKey { return .licensed }
        let remaining = Double(trialDays) * 86_400 - now.timeIntervalSince(trialStart)
        if remaining <= 0 { return .expired }
        return .trial(daysLeft: min(trialDays, Int((remaining / 86_400).rounded(.up))))
    }

    var state: State {
        Self.state(trialStart: trialStart, hasKey: Self.keychainGet("licenseKey") != nil)
    }

    private var trialStart: Date {
        if let stored = Self.keychainGet("trialStart"), let seconds = TimeInterval(stored) {
            return Date(timeIntervalSince1970: seconds)
        }
        let now = Date()
        Self.keychainSet("trialStart", String(now.timeIntervalSince1970))
        return now
    }

    func activate(key: String, completion: @escaping (Result<Void, LicenseError>) -> Void) {
        guard Self.isConfigured else { return completion(.failure(.notConfigured)) }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.~"))
        func enc(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s }

        var request = URLRequest(url: URL(string: "https://api.gumroad.com/v2/licenses/verify")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "product_id=\(enc(Self.productID))&license_key=\(enc(key))&increment_uses_count=true".data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            let result: Result<Void, LicenseError> = data.map { Self.parseActivation($0, maxUses: Self.maxActivations) } ?? .failure(.network)
            if case .success = result { Self.keychainSet("licenseKey", key) }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    /// Gumroad answers 4xx with a JSON body too, so the status code is ignored. A key from
    /// another product comes back as "does not exist" because the lookup is scoped by product_id.
    static func parseActivation(_ data: Data, maxUses: Int) -> Result<Void, LicenseError> {
        struct Reply: Decodable {
            struct Purchase: Decodable {
                let refunded: Bool?
                let chargebacked: Bool?
            }
            let success: Bool?
            let message: String?
            let uses: Int?
            let purchase: Purchase?
        }
        guard let reply = try? JSONDecoder().decode(Reply.self, from: data) else { return .failure(.unreadable) }
        guard reply.success == true else { return .failure(.rejected(reply.message ?? "That license key isn't valid.")) }
        if reply.purchase?.refunded == true || reply.purchase?.chargebacked == true {
            return .failure(.rejected("That purchase was refunded, so the key no longer works."))
        }
        if let uses = reply.uses, uses > maxUses {
            return .failure(.rejected("That key has been used on too many Macs. Contact the seller from your Gumroad receipt."))
        }
        return .success(())
    }

    // MARK: Keychain

    private static let service = "com.pratiknayak.stayawake"

    private static func keychainGet(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func keychainSet(_ account: String, _ value: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        SecItemAdd(base.merging([kSecValueData as String: Data(value.utf8)]) { $1 } as CFDictionary, nil)
    }

    // MARK: Self-check (`StayAwake --selftest`)

    static func selfTest() {
        func check(_ ok: Bool, _ what: String) {
            guard ok else { print("FAIL: \(what)"); exit(1) }
        }
        let now = Date()
        let day: TimeInterval = 86_400
        check(state(trialStart: now, hasKey: false, now: now) == .trial(daysLeft: 7), "fresh trial is 7 days")
        check(state(trialStart: now - day - 3_600, hasKey: false, now: now) == .trial(daysLeft: 6), "day 1 shows 6 left")
        check(state(trialStart: now - 7 * day - 1, hasKey: false, now: now) == .expired, "expires after 7 days")
        check(state(trialStart: now - 30 * day, hasKey: true, now: now) == .licensed, "a key beats an expired trial")
        check(state(trialStart: now + 5 * day, hasKey: false, now: now) == .trial(daysLeft: 7), "clock set back never exceeds 7 days")

        func accepted(_ json: String) -> Bool {
            if case .success = parseActivation(Data(json.utf8), maxUses: 5) { return true }
            return false
        }
        check(accepted(#"{"success":true,"uses":1,"purchase":{"refunded":false,"chargebacked":false}}"#), "valid key accepted")
        check(accepted(#"{"success":true,"uses":5,"purchase":{"refunded":false,"chargebacked":false}}"#), "fifth use still accepted")
        check(!accepted(#"{"success":true,"uses":6,"purchase":{"refunded":false,"chargebacked":false}}"#), "sixth use rejected")
        check(!accepted(#"{"success":true,"uses":1,"purchase":{"refunded":true,"chargebacked":false}}"#), "refunded key rejected")
        check(!accepted(#"{"success":true,"uses":1,"purchase":{"refunded":false,"chargebacked":true}}"#), "chargebacked key rejected")
        check(!accepted(#"{"success":false,"message":"That license does not exist for the provided product."}"#), "unknown key rejected")
        check(!accepted("not json"), "garbage rejected")
        print("license selftest ok")
    }
}
