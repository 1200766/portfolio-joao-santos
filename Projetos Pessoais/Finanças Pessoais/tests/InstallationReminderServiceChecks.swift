import Foundation
import UserNotifications

/// Exercises the actual service with an in-memory notification center; never contacts iOS services.
@MainActor
@main
struct InstallationReminderServiceChecks {
    static var assertions = 0
    static let ownedID = InstallationReminderNotification.identifier
    static let weeklyID = "weekly-budget-sunday-reminder"

    static func main() async throws {
        try await run(defaultsAndPreferences)
        try await run(absoluteSchedulingAndDeduplication)
        try await run(lateReminderAndPersistedReceipt)
        try await run(newExpirationReplacesOnlyOwnedRequests)
        try await run(missingExpiredAndDeniedProfiles)
        try await run(explicitPermissionOnly)
        try await run(disabledAndChangedLead)
        try await run(disabledBeforeFireCanBeReenabledLate)
        try await run(deniedBeforeFireCanRecoverLate)
        try await run(addFailureAndRetry)
        try await run(newExpirationAddFailureAndRetry)
        try await run(replacementFailureDoesNotSuppressLateRetry)
        try await run(permissionFailureAndSilentDelivery)
        try await run(roundingAndNearExpiration)
        print("Installation reminder service: \(assertions) checks passed using a fake notification center only.")
    }

    static func run(_ test: (Fixture) async throws -> Void) async throws {
        let fixture = Fixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        try await test(fixture)
        try check(fixture.center.pending[weeklyID] != nil, "The existing Sunday reminder is never removed")
        try check(fixture.center.delivered.contains(weeklyID), "The Sunday notification's delivered state is untouched")
        try check(fixture.center.removedPending.flatMap { $0 }.allSatisfy { $0 == ownedID }, "Pending cancellation only targets the renewal identifier")
        try check(fixture.center.removedDelivered.flatMap { $0 }.allSatisfy { $0 == ownedID }, "Delivered cancellation only targets the renewal identifier")
    }

    static func check(_ condition: @autoclosure () throws -> Bool, _ message: String, line: UInt = #line) throws {
        guard try condition() else { throw CheckFailure(message: "Line \(line): \(message)") }
        assertions += 1
    }

    static func receipt(_ fixture: Fixture) -> InstallationReminderReceipt? {
        fixture.defaults.data(forKey: "installationReminder.receipt").flatMap {
            try? JSONDecoder().decode(InstallationReminderReceipt.self, from: $0)
        }
    }

    static func triggerDate(_ request: UNNotificationRequest?) -> Date? {
        guard let trigger = request?.trigger as? UNCalendarNotificationTrigger else { return nil }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        return utc.date(from: trigger.dateComponents)
    }

    static func defaultsAndPreferences(_ fixture: Fixture) async throws {
        let service = fixture.service()
        try check(service.enabled && service.leadHours == 24, "Defaults enable the reminder with twenty-four-hour notice")
        try check(fixture.center.addAttempts == 0 && fixture.center.authorizationRequests == 0, "Construction has no notification effects")
        fixture.defaults.set(7, forKey: "installationReminder.leadHours")
        let invalidStored = fixture.service()
        try check(invalidStored.leadHours == 24, "An unsupported stored lead falls back to twenty-four hours")
        await invalidStored.configure(enabled: false, leadHours: -1)
        try check(invalidStored.enabled && invalidStored.leadHours == 24, "Invalid configuration does not change active preferences")
        try check(fixture.center.addAttempts == 0, "An invalid configuration does not schedule")
        fixture.defaults.set(false, forKey: "installationReminder.enabled")
        fixture.defaults.set(12, forKey: "installationReminder.leadHours")
        let stored = fixture.service()
        try check(!stored.enabled && stored.leadHours == 12, "Valid preferences survive service recreation")
    }

    static func absoluteSchedulingAndDeduplication(_ fixture: Fixture) async throws {
        let service = fixture.service()
        let expiry = fixture.validity!.expirationDate
        await service.refresh()
        let request = fixture.center.pending[ownedID]
        let trigger = request?.trigger as? UNCalendarNotificationTrigger
        let expected = expiry.addingTimeInterval(-24 * 3_600)
        try check(request != nil && fixture.center.addAttempts == 1, "A valid profile schedules one owned request")
        try check(trigger?.repeats == false, "The expiry reminder never repeats automatically")
        try check(trigger?.dateComponents.timeZone?.secondsFromGMT() == 0, "The trigger uses absolute UTC components")
        try check(trigger?.dateComponents.calendar?.identifier == .gregorian, "The trigger has an explicit Gregorian calendar")
        try check(triggerDate(request) == expected && service.reminderDate == expected, "The default trigger is exactly twenty-four hours before expiry")
        try check(request?.content.userInfo["expiration"] as? Double == expiry.timeIntervalSince1970, "The notification records the observed expiry")
        try check(receipt(fixture)?.fireDate == expected && service.expirationDate == expiry, "Only a successfully scheduled date is persisted and published")
        try check(service.lastError == nil && !service.isRefreshing, "Successful refresh clears error and activity state")
        fixture.clock = fixture.clock.addingTimeInterval(10)
        await service.refresh()
        try check(fixture.center.addAttempts == 1, "Another launch does not add an identical pending reminder")
        fixture.validity = InstallationValidity(expirationDate: expiry, creationDate: fixture.clock)
        await fixture.service().refresh()
        try check(fixture.center.addAttempts == 1, "Recompiling with the same expiry does not manufacture a renewed deadline")
    }

    static func lateReminderAndPersistedReceipt(_ fixture: Fixture) async throws {
        fixture.validity = InstallationValidity(expirationDate: fixture.clock.addingTimeInterval(2 * 3_600), creationDate: fixture.clock.addingTimeInterval(-20_000))
        let service = fixture.service()
        let firstNow = fixture.clock
        await service.refresh()
        let fire = firstNow.addingTimeInterval(60)
        try check(service.reminderDate == fire, "Inside the notice window a single near-future reminder is scheduled")
        fixture.clock = firstNow.addingTimeInterval(10)
        await service.refresh()
        try check(service.reminderDate == fire && fixture.center.addAttempts == 1, "A late pending reminder is not pushed back by each refresh")
        let restartedBeforeFire = fixture.service()
        await restartedBeforeFire.refresh()
        try check(restartedBeforeFire.reminderDate == fire && fixture.center.addAttempts == 1, "A persisted receipt stabilizes the late date across service recreation")
        fixture.center.simulateDelivery(identifier: ownedID)
        fixture.clock = fire.addingTimeInterval(1)
        await service.refresh()
        try check(service.reminderDate == nil && fixture.center.addAttempts == 1, "Once its time passed, the service does not send the warning again")
        fixture.clock = fire.addingTimeInterval(60)
        let restartedAfterFire = fixture.service()
        await restartedAfterFire.refresh()
        try check(restartedAfterFire.reminderDate == nil && fixture.center.addAttempts == 1, "Restarting after the recorded reminder cannot cause repeated alerts")
        try check(receipt(fixture)?.fireDate == fire, "The passed receipt stays available to prevent repeated warnings")
    }

    static func newExpirationReplacesOnlyOwnedRequests(_ fixture: Fixture) async throws {
        let service = fixture.service()
        await service.refresh()
        let firstExpiry = fixture.validity!.expirationDate
        fixture.center.simulateDelivery(identifier: ownedID)
        let newExpiry = firstExpiry.addingTimeInterval(3 * 86_400)
        fixture.validity = InstallationValidity(expirationDate: newExpiry, creationDate: fixture.clock)
        await service.refresh()
        try check(fixture.center.addAttempts == 2, "A genuinely different expiry schedules a replacement")
        try check(!fixture.center.delivered.contains(ownedID), "A new validity clears the old delivered renewal reminder")
        try check(receipt(fixture)?.expirationDate == newExpiry && service.expirationDate == newExpiry, "The new profile date replaces the old receipt")
        try check(triggerDate(fixture.center.pending[ownedID]) == newExpiry.addingTimeInterval(-86_400), "The replacement is based on expiry, not time of opening")
        await service.refresh()
        try check(fixture.center.addAttempts == 2, "The new validity also deduplicates subsequent refreshes")
    }

    static func missingExpiredAndDeniedProfiles(_ fixture: Fixture) async throws {
        let service = fixture.service()
        await service.refresh()
        fixture.validity = nil
        await service.refresh()
        try check(service.expirationDate == nil && service.reminderDate == nil, "An unreadable profile does not invent an expiry or scheduled date")
        try check(fixture.center.pending[ownedID] == nil && receipt(fixture) == nil, "Missing validity cancels the old request and receipt")
        let previousAttempts = fixture.center.addAttempts
        await service.refresh(requestAuthorization: true)
        try check(fixture.center.addAttempts == previousAttempts && fixture.center.authorizationRequests == 0, "Missing validity causes neither scheduling nor permission requests")
        fixture.validity = InstallationValidity(expirationDate: fixture.clock.addingTimeInterval(-1), creationDate: fixture.clock.addingTimeInterval(-86_400))
        fixture.center.insertPlaceholder(identifier: ownedID)
        await service.refresh(requestAuthorization: true)
        try check(service.reminderDate == nil && fixture.center.pending[ownedID] == nil, "An expired profile cancels its request")
        try check(fixture.center.authorizationRequests == 0, "An expired installation does not prompt for notification access")
        fixture.validity = InstallationValidity(expirationDate: fixture.clock.addingTimeInterval(3 * 86_400), creationDate: fixture.clock)
        fixture.center.authorizationStatus = .denied
        fixture.center.insertPlaceholder(identifier: ownedID)
        await service.refresh(requestAuthorization: true)
        await service.refresh(requestAuthorization: true)
        try check(service.permissionDenied && service.reminderDate == nil, "Denied access is visible without a false scheduled state")
        try check(fixture.center.pending[ownedID] == nil && fixture.center.authorizationRequests == 0, "Denied permissions never re-prompt and only cancel the owned request")
    }

    static func explicitPermissionOnly(_ fixture: Fixture) async throws {
        fixture.center.authorizationStatus = .notDetermined
        let service = fixture.service()
        await service.refresh()
        try check(service.permissionNotDetermined && fixture.center.authorizationRequests == 0, "Launch reconciliation does not automatically ask for permission")
        try check(fixture.center.pending[ownedID] == nil, "An undetermined permission is not described as scheduled")
        await service.refresh(requestAuthorization: true)
        try check(fixture.center.authorizationRequests == 1 && fixture.center.addAttempts == 1, "An explicit request grants access and schedules")
        try check(!service.permissionNotDetermined && !service.permissionDenied, "Published access state updates after authorization")
        await service.refresh(requestAuthorization: true)
        try check(fixture.center.authorizationRequests == 1 && fixture.center.addAttempts == 1, "Already granted permission is not requested twice")
        fixture.center.authorizationStatus = .denied
        await service.refresh(requestAuthorization: true)
        try check(fixture.center.authorizationRequests == 1 && fixture.center.pending[ownedID] == nil, "Revoked access cancels its reminder without another system prompt")
    }

    static func disabledAndChangedLead(_ fixture: Fixture) async throws {
        let service = fixture.service()
        await service.refresh()
        let expiry = fixture.validity!.expirationDate
        await service.configure(enabled: false, leadHours: 24)
        try check(!service.enabled && service.reminderDate == nil && fixture.center.pending[ownedID] == nil, "Turning the option off cancels its notification")
        try check(fixture.defaults.object(forKey: "installationReminder.enabled") as? Bool == false, "The disabled preference is persisted")
        await service.configure(enabled: true, leadHours: 48)
        try check(service.enabled && service.leadHours == 48 && service.reminderDate == expiry.addingTimeInterval(-48 * 3_600), "Enabling with a new lead uses that lead, not the old receipt")
        await service.configure(enabled: true, leadHours: 6)
        try check(service.reminderDate == expiry.addingTimeInterval(-6 * 3_600), "A lead change updates the pending date")
        try check(receipt(fixture)?.fireDate == service.reminderDate && fixture.service().leadHours == 6, "The new lead and receipt survive recreation")
        let attempts = fixture.center.addAttempts
        await service.configure(enabled: true, leadHours: 6)
        try check(fixture.center.addAttempts == attempts, "Saving identical settings does not add another request")
    }

    static func addFailureAndRetry(_ fixture: Fixture) async throws {
        fixture.center.failNextAdd = true
        let service = fixture.service()
        await service.refresh()
        try check(service.lastError != nil && service.reminderDate == nil && !service.isRefreshing, "An add error is published and never reported as scheduled")
        try check(receipt(fixture) == nil && fixture.center.pending[ownedID] == nil, "A failed first add stores no success receipt")
        await service.refresh()
        try check(fixture.center.addAttempts == 2 && fixture.center.successfulAdds == 1, "A later refresh retries the failed request")
        try check(service.lastError == nil && service.reminderDate != nil && receipt(fixture) != nil, "Successful retry clears the error and stores its receipt")
    }

    static func disabledBeforeFireCanBeReenabledLate(_ fixture: Fixture) async throws {
        fixture.validity = InstallationValidity(expirationDate: fixture.clock.addingTimeInterval(48 * 3_600), creationDate: fixture.clock)
        let service = fixture.service()
        await service.refresh()
        let oldFire = service.reminderDate!
        fixture.clock = oldFire.addingTimeInterval(-3_600)
        await service.configure(enabled: false, leadHours: 24)
        try check(fixture.center.pending[ownedID] == nil && receipt(fixture) == nil, "Disabling before delivery clears the receipt for the canceled future reminder")
        fixture.clock = oldFire.addingTimeInterval(5)
        await service.configure(enabled: true, leadHours: 24)
        let newFire = fixture.clock.addingTimeInterval(60)
        try check(service.reminderDate == newFire && fixture.center.successfulAdds == 2, "Re-enabling after a canceled fire time schedules a single late warning")
        await fixture.service().refresh()
        try check(fixture.center.addAttempts == 2 && receipt(fixture)?.fireDate == newFire, "Recreated service keeps the replacement late reminder stable")
        fixture.center.simulateDelivery(identifier: ownedID)
        fixture.clock = newFire.addingTimeInterval(1)
        await service.refresh()
        await service.configure(enabled: false, leadHours: 24)
        try check(receipt(fixture)?.fireDate == newFire, "Disabling after the warning time retains its receipt to avoid repeats")
        await service.configure(enabled: true, leadHours: 24)
        try check(service.reminderDate == nil && fixture.center.addAttempts == 2, "Re-enabling after an already delivered warning does not repeat it")
    }

    static func deniedBeforeFireCanRecoverLate(_ fixture: Fixture) async throws {
        fixture.validity = InstallationValidity(expirationDate: fixture.clock.addingTimeInterval(48 * 3_600), creationDate: fixture.clock)
        let service = fixture.service()
        await service.refresh()
        let oldFire = service.reminderDate!
        fixture.clock = oldFire.addingTimeInterval(-3_600)
        fixture.center.authorizationStatus = .denied
        await service.refresh()
        try check(service.permissionDenied && fixture.center.pending[ownedID] == nil && receipt(fixture) == nil,
                  "Denied access before delivery cancels the request without leaving a false delivered receipt")
        fixture.clock = oldFire.addingTimeInterval(5)
        fixture.center.authorizationStatus = .authorized
        await service.refresh()
        let newFire = fixture.clock.addingTimeInterval(60)
        try check(!service.permissionDenied && service.reminderDate == newFire && fixture.center.successfulAdds == 2,
                  "Restored permission after the canceled fire time schedules one late warning")
        try check(fixture.center.authorizationRequests == 0, "Detecting restored authorization does not prompt again")
        await fixture.service().refresh()
        try check(fixture.center.addAttempts == 2, "Restored permission and restart still deduplicate the replacement")
        fixture.center.simulateDelivery(identifier: ownedID)
        fixture.clock = newFire.addingTimeInterval(1)
        fixture.center.authorizationStatus = .denied
        await service.refresh()
        fixture.center.authorizationStatus = .authorized
        await service.refresh()
        try check(service.reminderDate == nil && fixture.center.addAttempts == 2,
                  "Revoking and restoring access after actual delivery cannot repeat the warning")
    }

    static func replacementFailureDoesNotSuppressLateRetry(_ fixture: Fixture) async throws {
        fixture.validity = InstallationValidity(expirationDate: fixture.clock.addingTimeInterval(72 * 3_600), creationDate: fixture.clock)
        let service = fixture.service()
        await service.refresh()
        let oldFire = service.reminderDate!
        fixture.clock = fixture.clock.addingTimeInterval(3_600)
        fixture.center.failNextAdd = true
        await service.configure(enabled: true, leadHours: 48)
        try check(service.lastError != nil && service.reminderDate == nil && fixture.center.pending[ownedID] == nil,
                  "A failed lead-time replacement reports no pending reminder")
        try check(receipt(fixture) == nil, "Canceling the old future request before a failed replacement cannot leave a success receipt")
        fixture.clock = oldFire.addingTimeInterval(5)
        let restarted = fixture.service()
        await restarted.refresh()
        let newFire = fixture.clock.addingTimeInterval(60)
        try check(restarted.leadHours == 48 && restarted.reminderDate == newFire && restarted.lastError == nil,
                  "Retry after the old canceled fire time schedules a late warning with the persisted new lead")
        try check(fixture.center.addAttempts == 3 && fixture.center.successfulAdds == 2 && receipt(fixture)?.fireDate == newFire,
                  "A failed replacement is retried exactly once and saves only the successful replacement")
        await restarted.refresh()
        try check(fixture.center.addAttempts == 3, "The late retry does not create repeated requests")
    }

    static func newExpirationAddFailureAndRetry(_ fixture: Fixture) async throws {
        let service = fixture.service()
        await service.refresh()
        let expiry = fixture.validity!.expirationDate.addingTimeInterval(86_400)
        fixture.validity = InstallationValidity(expirationDate: expiry, creationDate: fixture.clock)
        fixture.center.failNextAdd = true
        await service.refresh()
        try check(service.expirationDate == expiry && service.reminderDate == nil && service.lastError != nil, "A failed replacement publishes the new validity but no stale scheduled state")
        try check(receipt(fixture) == nil && fixture.center.pending[ownedID] == nil, "The receipt from the previous expiry cannot masquerade as replacement success")
        await fixture.service().refresh()
        try check(fixture.center.successfulAdds == 2 && receipt(fixture)?.expirationDate == expiry, "Restart can retry a failed replacement without losing the real expiry")
    }

    static func permissionFailureAndSilentDelivery(_ fixture: Fixture) async throws {
        fixture.center.authorizationStatus = .notDetermined
        fixture.center.failNextAuthorization = true
        let service = fixture.service()
        await service.refresh(requestAuthorization: true)
        try check(service.lastError != nil && fixture.center.addAttempts == 0 && receipt(fixture) == nil, "Permission errors never produce a success receipt")
        fixture.center.authorizationStatus = .provisional
        fixture.center.alertsEnabled = false
        await service.refresh()
        try check(fixture.center.addAttempts == 1 && service.reminderDate != nil, "Provisional authorization allows a quiet notification")
        try check(service.status.contains("silenciosamente"), "Quiet permission is distinguished from banner delivery")
        fixture.center.authorizationStatus = .authorized
        await service.refresh()
        try check(service.status.contains("silenciosamente") && fixture.center.addAttempts == 1, "Disabled alerts are still described honestly with full authorization")
    }

    static func roundingAndNearExpiration(_ fixture: Fixture) async throws {
        fixture.clock = fixture.clock.addingTimeInterval(0.25)
        fixture.validity = InstallationValidity(expirationDate: fixture.clock.addingTimeInterval(2 * 86_400), creationDate: fixture.clock)
        let service = fixture.service()
        let ideal = fixture.validity!.expirationDate.addingTimeInterval(-86_400)
        await service.refresh()
        let rounded = Date(timeIntervalSince1970: ceil(ideal.timeIntervalSince1970))
        try check(service.reminderDate == rounded && triggerDate(fixture.center.pending[ownedID]) == rounded, "Fractional trigger dates round up to a representable second")
        await service.refresh()
        try check(fixture.center.addAttempts == 1, "Rounding does not defeat deduplication")
        fixture.validity = InstallationValidity(expirationDate: fixture.clock.addingTimeInterval(60), creationDate: fixture.clock.addingTimeInterval(-100))
        await service.refresh()
        try check(service.reminderDate == nil && fixture.center.pending[ownedID] == nil, "No request is scheduled within the last sixty seconds")
        fixture.validity = InstallationValidity(expirationDate: fixture.clock.addingTimeInterval(60.1), creationDate: fixture.clock.addingTimeInterval(-100))
        await service.refresh()
        try check(service.reminderDate == nil && fixture.center.pending[ownedID] == nil, "Rounding never schedules a request at or after expiration")
    }

    @MainActor
    final class Fixture {
        let suite = "InstallationReminderServiceChecks.\(UUID().uuidString)"
        let defaults: UserDefaults
        let center = FakeCenter()
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        var validity: InstallationValidity?

        init() {
            defaults = UserDefaults(suiteName: suite)!
            validity = InstallationValidity(expirationDate: clock.addingTimeInterval(7 * 86_400), creationDate: clock.addingTimeInterval(-60))
            center.insertPlaceholder(identifier: weeklyID)
            center.delivered.insert(weeklyID)
        }

        func service() -> InstallationReminderService {
            InstallationReminderService(center: center, defaults: defaults,
                                        validityProvider: { self.validity }, now: { self.clock })
        }
    }

    @MainActor
    final class FakeCenter: InstallationNotificationCenter {
        var authorizationStatus = UNAuthorizationStatus.authorized
        var authorizationResult = UNAuthorizationStatus.authorized
        var alertsEnabled = true
        var authorizationRequests = 0
        var addAttempts = 0
        var successfulAdds = 0
        var failNextAdd = false
        var failNextAuthorization = false
        var pending: [String: UNNotificationRequest] = [:]
        var delivered: Set<String> = []
        var removedPending: [[String]] = []
        var removedDelivered: [[String]] = []

        func access() async -> InstallationNotificationAccess {
            InstallationNotificationAccess(authorizationStatus: authorizationStatus, alertsEnabled: alertsEnabled)
        }

        func requestAuthorization() async throws {
            authorizationRequests += 1
            if failNextAuthorization {
                failNextAuthorization = false
                throw FakeError.expectedFailure
            }
            authorizationStatus = authorizationResult
        }

        func pendingRequests() async -> [UNNotificationRequest] { Array(pending.values) }

        func add(_ request: UNNotificationRequest) async throws {
            addAttempts += 1
            if failNextAdd {
                failNextAdd = false
                throw FakeError.expectedFailure
            }
            pending[request.identifier] = request
            successfulAdds += 1
        }

        func removePending(identifiers: [String]) {
            removedPending.append(identifiers)
            for identifier in identifiers { pending.removeValue(forKey: identifier) }
        }

        func removeDelivered(identifiers: [String]) {
            removedDelivered.append(identifiers)
            for identifier in identifiers { delivered.remove(identifier) }
        }

        func insertPlaceholder(identifier: String) {
            let content = UNMutableNotificationContent()
            content.title = "Existing test notification"
            pending[identifier] = UNNotificationRequest(identifier: identifier, content: content,
                                                       trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3_600, repeats: false))
        }

        func simulateDelivery(identifier: String) {
            pending.removeValue(forKey: identifier)
            delivered.insert(identifier)
        }

        enum FakeError: Error { case expectedFailure }
    }

    struct CheckFailure: Error, CustomStringConvertible {
        let message: String
        var description: String { message }
    }
}
