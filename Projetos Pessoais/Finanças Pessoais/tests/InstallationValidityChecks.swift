import Foundation

// Run alongside InstallationValidity.swift. Fixtures contain no real signing identities.
@main
struct InstallationValidityChecks {
    static var assertions = 0
    static let expectedBundle = "com.example.Finance"
    static let creation = instant("2026-09-01T10:00:00Z")
    static let expiry = instant("2026-09-08T10:00:00Z")

    static func main() throws {
        try supportedMetadata(); try malformedMetadata(); try identifierChecks(); try boundedPayloads()
        try bundledProfile(); try planner(); try receiptRoundtrip(); try optionalActualProfile()
        print("InstallationValidity: \(assertions) checks passed.")
    }

    static func check(_ value: @autoclosure () throws -> Bool, _ message: String, line: UInt = #line) throws {
        guard try value() else { throw Failure(message: "Check at line \(line) failed: \(message)") }
        assertions += 1
    }

    static func instant(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    static func metadata(_ applicationID: String? = "TEAM123456.com.example.Finance") -> [String: Any] {
        var result: [String: Any] = ["CreationDate": creation, "ExpirationDate": expiry, "TeamIdentifier": ["TEAM123456"]]
        if let applicationID { result["Entitlements"] = ["application-identifier": applicationID] }
        return result
    }

    static func plist(_ value: Any, format: PropertyListSerialization.PropertyListFormat = .xml) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: value, format: format, options: 0)
    }

    static func wrapped(_ payload: Data) -> Data {
        var data = Data([0x30, 0x82, 0xFF, 0x00, 0x80])
        data.append(payload); data.append(contentsOf: [0x00, 0xFF, 0x80]); return data
    }

    static func read(_ metadata: [String: Any], bundle: String = expectedBundle) throws -> InstallationValidity? {
        InstallationValidity.read(from: try plist(metadata), expectedBundleIdentifier: bundle)
    }

    static func supportedMetadata() throws {
        let expected = InstallationValidity(expirationDate: expiry, creationDate: creation)
        try check(try read(metadata()) == expected, "Plain XML dates are preserved exactly")
        try check(InstallationValidity.read(from: try plist(metadata(), format: .binary), expectedBundleIdentifier: expectedBundle) == expected,
                  "Plain binary plist can be read")
        let xml = try plist(metadata())
        try check(InstallationValidity.read(from: wrapped(xml), expectedBundleIdentifier: expectedBundle) == expected,
                  "Single XML plist can be read from an opaque binary envelope")
        let text = String(data: xml, encoding: .utf8)!
        let bare = Data(text[text.range(of: "<plist")!.lowerBound...].utf8)
        try check(InstallationValidity.read(from: bare, expectedBundleIdentifier: expectedBundle) == expected,
                  "A plist without the XML declaration remains supported")
        try check(try read(metadata(nil)) == expected, "Profiles without optional entitlements can expose their dates")
        var empty = metadata(nil); empty["Entitlements"] = [String: Any]()
        try check(try read(empty) == expected, "Missing optional app identity does not replace the actual expiration date")
        var noTeam = metadata(); noTeam.removeValue(forKey: "TeamIdentifier")
        try check(try read(noTeam) == expected, "App suffix can be validated when optional team metadata is absent")
        var historical = metadata(); historical["CreationDate"] = instant("2020-01-01T00:00:00Z"); historical["ExpirationDate"] = instant("2020-01-02T00:00:00Z")
        try check(try read(historical)?.expirationDate == instant("2020-01-02T00:00:00Z"), "Reading metadata never substitutes seven days for an expired date")
    }

    static func malformedMetadata() throws {
        for payload in [Data(), Data("not a profile".utf8), Data([0xFF, 0x00, 0x80]), Data("<plist><dict>".utf8), Data("</plist><plist>".utf8)] {
            try check(InstallationValidity.read(from: payload, expectedBundleIdentifier: expectedBundle) == nil,
                      "Missing or malformed data returns no expiry")
        }
        try check(InstallationValidity.read(from: try plist([creation, expiry]), expectedBundleIdentifier: expectedBundle) == nil,
                  "A non-dictionary root is unsupported")
        for field in ["CreationDate", "ExpirationDate"] {
            var missing = metadata(); missing.removeValue(forKey: field)
            try check(try read(missing) == nil, "Both real dates are required")
            var string = metadata(); string[field] = "2026-09-08T10:00:00Z"
            try check(try read(string) == nil, "Date-looking strings are not silently converted")
            var number = metadata(); number[field] = 12345
            try check(try read(number) == nil, "Numeric date guesses are rejected")
        }
        var same = metadata(); same["CreationDate"] = expiry
        try check(try read(same) == nil, "An empty validity interval is rejected")
        var reversed = metadata(); reversed["CreationDate"] = expiry.addingTimeInterval(1)
        try check(try read(reversed) == nil, "Creation after expiration is rejected")
        let xml = try plist(metadata())
        var multiple = wrapped(xml); multiple.append(xml)
        try check(InstallationValidity.read(from: multiple, expectedBundleIdentifier: expectedBundle) == nil, "Multiple embedded plist candidates are rejected")
        var extraOpening = wrapped(xml); extraOpening.append(Data("<plist".utf8))
        try check(InstallationValidity.read(from: extraOpening, expectedBundleIdentifier: expectedBundle) == nil, "A second opening marker is ambiguous")
        var extraClosing = wrapped(xml); extraClosing.append(Data("</plist>".utf8))
        try check(InstallationValidity.read(from: extraClosing, expectedBundleIdentifier: expectedBundle) == nil, "A second closing marker is ambiguous")
        var invalidEntitlements = metadata(); invalidEntitlements["Entitlements"] = "invalid"
        try check(try read(invalidEntitlements) == nil, "Malformed entitlements are not treated as missing")
    }

    static func identifierChecks() throws {
        let mismatches = ["TEAM123456.com.example.Other", "TEAM123456.badcom.example.Finance", "TEAM123456.com.example.Finance.extra",
            "WRONGTEAM1.com.example.Finance", "TEAM123456com.example.Finance", "TEAM123456.", ".com.example.Finance",
            "TEAM123456.com.example.Finan*", "TEAM123456.com.*.Finance", "TEAM123456.com.example.Finance.*",
            "TEAM123456.com.examples.*"]
        for value in mismatches { try check(try read(metadata(value)) == nil, "App identity must match the exact suffix and allowed team") }
        for value in ["TEAM123456.*", "TEAM123456.com.example.*"] {
            try check(try read(metadata(value))?.expirationDate == expiry, "Only complete trailing wildcard components are accepted")
        }
        try check(try read(metadata("TEAM123456.com.example.*"), bundle: "com.example") == nil, "Wildcard requires an actual child bundle component")
        var alternate = metadata(nil); alternate["Entitlements"] = ["com.apple.application-identifier": "TEAM123456.com.example.Finance"]
        try check(try read(alternate)?.expirationDate == expiry, "Alternate application-identifier key is supported")
        alternate["Entitlements"] = ["application-identifier": "TEAM123456.com.example.Finance", "com.apple.application-identifier": "TEAM123456.com.example.Other"]
        try check(try read(alternate) == nil, "Conflicting identifier keys are rejected")
        var invalidValue = metadata(); invalidValue["Entitlements"] = ["application-identifier": 7]
        try check(try read(invalidValue) == nil, "A present non-string app identity is rejected")
        for teams: Any in [[], [""], ["WRONGTEAM1"], ["TEAM.123456"], "TEAM123456"] {
            var value = metadata(); value["TeamIdentifier"] = teams
            try check(try read(value) == nil, "Malformed or mismatched team metadata is rejected")
        }
        var multiple = metadata(); multiple["TeamIdentifier"] = ["OTHERTEAM1", "TEAM123456"]
        try check(try read(multiple)?.expirationDate == expiry, "A matching valid team within the declared array is accepted")
        for bundle in ["", "com..example", ".com.example", "com.example.", "com.example.*", "com.example/Foo", "com.example Foo", String(repeating: "a", count: 256)] {
            try check(try read(metadata("TEAM123456.*"), bundle: bundle) == nil, "Malformed expected bundle identifiers cannot pass a wildcard")
        }
    }

    static func boundedPayloads() throws {
        let payload = wrapped(try plist(metadata()))
        var atLimit = payload
        atLimit.append(Data(repeating: 0, count: 2 * 1_024 * 1_024 - payload.count))
        try check(InstallationValidity.read(from: atLimit, expectedBundleIdentifier: expectedBundle)?.expirationDate == expiry,
                  "The exact two-mebibyte limit is supported")
        atLimit.append(0)
        try check(InstallationValidity.read(from: atLimit, expectedBundleIdentifier: expectedBundle) == nil,
                  "An oversized profile is rejected before parsing")
    }

    static func bundledProfile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("installation-validity-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for (name, profile, expected): (String, Data?, InstallationValidity?) in [
            ("Present", wrapped(try plist(metadata())), InstallationValidity(expirationDate: expiry, creationDate: creation)),
            ("Missing", nil, nil), ("Invalid", Data("invalid".utf8), nil)] {
            let url = directory.appendingPathComponent(name + ".bundle")
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try plist(["CFBundleIdentifier": expectedBundle, "CFBundleName": name, "CFBundlePackageType": "BNDL"])
                .write(to: url.appendingPathComponent("Info.plist"))
            if let profile { try profile.write(to: url.appendingPathComponent("embedded.mobileprovision")) }
            guard let bundle = Bundle(url: url) else { throw Failure(message: "Unable to open synthetic test bundle") }
            try check(InstallationValidity.bundled(in: bundle) == expected, "Bundle lookup is best effort and never guesses for absent metadata")
        }
    }

    static func planner() throws {
        let now = expiry.addingTimeInterval(-72 * 3_600)
        for hours in [6, 12, 24, 48] {
            try check(InstallationReminderPlanner.fireDate(expirationDate: expiry, leadHours: hours, now: now)
                == expiry.addingTimeInterval(-Double(hours) * 3_600), "Supported lead hours schedule relative to the exact expiration instant")
        }
        for hours in [-24, 0, 1, 7, 23, 49, Int.max] {
            try check(InstallationReminderPlanner.fireDate(expirationDate: expiry, leadHours: hours, now: now) == nil, "Unsupported lead intervals are rejected")
        }
        try check(InstallationReminderPlanner.fireDate(expirationDate: nil, leadHours: 24, now: now) == nil, "No actual date means no reminder")
        for expiration in [now.addingTimeInterval(-1), now, now.addingTimeInterval(30), now.addingTimeInterval(60)] {
            try check(InstallationReminderPlanner.fireDate(expirationDate: expiration, leadHours: 24, now: now) == nil,
                      "Expired or too-near deadlines never create a late notification")
        }
        let nearExpiry = now.addingTimeInterval(61)
        try check(InstallationReminderPlanner.fireDate(expirationDate: nearExpiry, leadHours: 24, now: now) == now.addingTimeInterval(60), "One minute is allowed only strictly before expiration")
        let exactIdeal = expiry.addingTimeInterval(-24 * 3_600)
        try check(InstallationReminderPlanner.fireDate(expirationDate: expiry, leadHours: 24, now: exactIdeal) == exactIdeal.addingTimeInterval(60), "At the exact warning boundary a near-immediate reminder is planned")
        let late = expiry.addingTimeInterval(-3_600)
        let firstFire = late.addingTimeInterval(60)
        try check(InstallationReminderPlanner.fireDate(expirationDate: expiry, leadHours: 24, now: late) == firstFire, "First launch inside the warning window schedules a minute ahead")
        let previous = InstallationReminderReceipt(expirationDate: expiry, fireDate: firstFire)
        try check(InstallationReminderPlanner.fireDate(expirationDate: expiry, leadHours: 24, now: late.addingTimeInterval(30), previous: previous) == firstFire, "Repeated launch does not keep postponing the warning")
        try check(InstallationReminderPlanner.fireDate(expirationDate: expiry, leadHours: 24, now: firstFire, previous: previous) == nil, "A receipt at its due time prevents repetition")
        try check(InstallationReminderPlanner.fireDate(expirationDate: expiry, leadHours: 24, now: firstFire.addingTimeInterval(10), previous: previous) == nil, "A delivered/due receipt stays deduplicated")
        let laterReceipt = InstallationReminderReceipt(expirationDate: expiry, fireDate: expiry.addingTimeInterval(-30))
        try check(InstallationReminderPlanner.fireDate(expirationDate: expiry, leadHours: 24, now: late, previous: laterReceipt) == firstFire, "An unnecessarily late pending warning is brought forward")
        let invalidReceipt = InstallationReminderReceipt(expirationDate: expiry, fireDate: expiry)
        try check(InstallationReminderPlanner.fireDate(expirationDate: expiry, leadHours: 24, now: late, previous: invalidReceipt) == firstFire, "A receipt at expiry is not reused as a valid future deadline")
        let oldReceipt = InstallationReminderReceipt(expirationDate: expiry.addingTimeInterval(-7 * 86_400), fireDate: late.addingTimeInterval(-100))
        try check(InstallationReminderPlanner.fireDate(expirationDate: expiry, leadHours: 24, now: late, previous: oldReceipt) == firstFire, "A renewed profile is not blocked by the previous profile receipt")
        let renewed = expiry.addingTimeInterval(7 * 86_400)
        try check(InstallationReminderPlanner.fireDate(expirationDate: renewed, leadHours: 24, now: late, previous: previous) == renewed.addingTimeInterval(-86_400), "Renewal schedules using the changed exact expiration date")
        let earlier = expiry.addingTimeInterval(-1_800)
        try check(InstallationReminderPlanner.fireDate(expirationDate: earlier, leadHours: 24, now: late, previous: previous) == firstFire, "A shortened profile is planned from its own deadline")
        let dstExpiry = instant("2026-10-25T10:00:00Z")
        let dstNow = instant("2026-10-23T00:00:00Z")
        let dstFire = InstallationReminderPlanner.fireDate(expirationDate: dstExpiry, leadHours: 24, now: dstNow)
        try check(dstFire == instant("2026-10-24T10:00:00Z") && dstExpiry.timeIntervalSince(dstFire!) == 86_400,
                  "A 24-hour warning remains elapsed 24 hours across the autumn clock change")
        let springExpiry = instant("2026-03-29T10:00:00Z")
        try check(InstallationReminderPlanner.fireDate(expirationDate: springExpiry, leadHours: 24, now: instant("2026-03-27T00:00:00Z")) == instant("2026-03-28T10:00:00Z"), "Spring clock change also uses elapsed hours")
        try check(InstallationReminderPlanner.fireDate(expirationDate: Date(timeIntervalSinceReferenceDate: .infinity), leadHours: 24, now: now) == nil,
                  "Non-finite expiration is rejected")
        try check(InstallationReminderPlanner.fireDate(expirationDate: expiry, leadHours: 24, now: Date(timeIntervalSinceReferenceDate: .nan)) == nil,
                  "Non-finite current time is rejected")
    }

    static func receiptRoundtrip() throws {
        let receipt = InstallationReminderReceipt(expirationDate: expiry, fireDate: expiry.addingTimeInterval(-86_400))
        let data = try JSONEncoder().encode(receipt)
        try check(try JSONDecoder().decode(InstallationReminderReceipt.self, from: data) == receipt, "The minimal receipt persists without profile identifiers")
    }

    static func optionalActualProfile() throws {
        guard CommandLine.arguments.count > 1 else { return }
        let input = URL(fileURLWithPath: CommandLine.arguments[1])
        let bundleURL = input.lastPathComponent == "embedded.mobileprovision" ? input.deletingLastPathComponent() : input
        guard let bundle = Bundle(url: bundleURL), let validity = InstallationValidity.bundled(in: bundle) else {
            throw Failure(message: "Actual signed application metadata could not be read")
        }
        print("Actual profile read successfully; expiration: \(ISO8601DateFormatter().string(from: validity.expirationDate))")
        try check(validity.expirationDate > validity.creationDate, "Actual signed bundle contains a valid date interval")
    }

    struct Failure: Error, CustomStringConvertible { let message: String; var description: String { message } }
}
