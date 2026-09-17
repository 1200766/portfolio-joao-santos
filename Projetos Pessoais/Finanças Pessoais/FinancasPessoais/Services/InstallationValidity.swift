import Foundation

/// Best-effort metadata reading only. Provisioning profiles have no supported stable decoding
/// contract here: this does not validate CMS signatures, certificate trust or early revocation.
struct InstallationValidity: Equatable {
    let expirationDate: Date
    let creationDate: Date

    private static let maximumProfileBytes = 2 * 1_024 * 1_024

    static func read(from data: Data, expectedBundleIdentifier: String) -> InstallationValidity? {
        guard !data.isEmpty, data.count <= maximumProfileBytes,
              validBundleIdentifier(expectedBundleIdentifier),
              let metadata = metadataDictionary(in: data),
              let expiration = metadata["ExpirationDate"] as? Date,
              let creation = metadata["CreationDate"] as? Date,
              expiration.timeIntervalSinceReferenceDate.isFinite,
              creation.timeIntervalSinceReferenceDate.isFinite,
              expiration > creation,
              identifiersMatch(metadata, expected: expectedBundleIdentifier) else { return nil }
        return InstallationValidity(expirationDate: expiration, creationDate: creation)
    }

    /// Missing/unsupported profiles (including Simulator/App Store cases) return no inferred date.
    static func bundled(in bundle: Bundle = .main) -> InstallationValidity? {
        guard let identifier = bundle.bundleIdentifier,
              let url = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
              let file = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? file.close() }
        guard let data = try? file.read(upToCount: maximumProfileBytes + 1) else { return nil }
        return read(from: data, expectedBundleIdentifier: identifier)
    }

    private static func metadataDictionary(in data: Data) -> [String: Any]? {
        if let plain = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) {
            return plain as? [String: Any]
        }
        // Some locally signed profiles contain a UTF-8 XML plist inside an opaque CMS envelope.
        // Only a single unambiguous plist is considered; unsupported encodings fail closed.
        let opening = Data("<plist".utf8), closing = Data("</plist>".utf8)
        guard let start = data.range(of: opening), let end = data.range(of: closing),
              start.upperBound < end.lowerBound,
              data.range(of: opening, in: start.upperBound..<data.endIndex) == nil,
              data.range(of: closing, in: end.upperBound..<data.endIndex) == nil else { return nil }
        let payload = data.subdata(in: start.lowerBound..<end.upperBound)
        return (try? PropertyListSerialization.propertyList(from: payload, options: [], format: nil)) as? [String: Any]
    }

    private static func identifiersMatch(_ metadata: [String: Any], expected: String) -> Bool {
        guard let rawEntitlements = metadata["Entitlements"] else { return true }
        guard let entitlements = rawEntitlements as? [String: Any] else { return false }
        let keys = ["application-identifier", "com.apple.application-identifier"]
        let presentKeys = keys.filter { entitlements[$0] != nil }
        // Dates can still be read from a profile that does not expose an application identifier.
        guard !presentKeys.isEmpty else { return true }
        let teams: [String]?
        if let rawTeams = metadata["TeamIdentifier"] {
            guard let values = rawTeams as? [String], !values.isEmpty,
                  values.allSatisfy(validTeamIdentifier) else { return false }
            teams = values
        } else {
            teams = nil
        }
        return presentKeys.allSatisfy { key in
            guard let identifier = entitlements[key] as? String,
                  let separator = identifier.firstIndex(of: ".") else { return false }
            let team = String(identifier[..<separator])
            guard validTeamIdentifier(team), teams?.contains(team) != false else { return false }
            let pattern = String(identifier[identifier.index(after: separator)...])
            if pattern == "*" { return true }
            if pattern.hasSuffix(".*") {
                let prefix = String(pattern.dropLast(2))
                return validBundleIdentifier(prefix) && expected.hasPrefix(prefix + ".")
            }
            return validBundleIdentifier(pattern) && pattern == expected
        }
    }

    private static func validTeamIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 64 && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0)
        }
    }

    private static func validBundleIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 255 && !value.hasPrefix(".") && !value.hasSuffix(".") &&
        !value.contains("..") && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 46
        }
    }
}

struct InstallationReminderReceipt: Codable, Equatable {
    let expirationDate: Date
    let fireDate: Date
}

enum InstallationReminderPlanner {
    /// Uses elapsed hours, never an assumed seven-day lifetime or a calendar-day approximation.
    static func fireDate(expirationDate: Date?, leadHours: Int, now: Date,
                         previous: InstallationReminderReceipt? = nil) -> Date? {
        guard [6, 12, 24, 48].contains(leadHours), let expirationDate,
              expirationDate.timeIntervalSinceReferenceDate.isFinite,
              now.timeIntervalSinceReferenceDate.isFinite else { return nil }
        let soon = now.addingTimeInterval(60)
        guard expirationDate > soon else { return nil }
        let ideal = expirationDate.addingTimeInterval(-Double(leadHours) * 3_600)
        if ideal > now { return ideal }
        if let previous, previous.expirationDate == expirationDate,
           previous.fireDate.timeIntervalSinceReferenceDate.isFinite {
            if previous.fireDate <= now { return nil }
            if previous.fireDate < expirationDate { return min(previous.fireDate, soon) }
        }
        return soon
    }
}
