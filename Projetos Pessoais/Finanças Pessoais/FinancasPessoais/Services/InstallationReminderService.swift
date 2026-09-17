import Foundation
import Combine
import UserNotifications

enum InstallationReminderNotification {
    static let identifier = "installation-validity-reminder"
}

struct InstallationNotificationAccess {
    let authorizationStatus: UNAuthorizationStatus
    let alertsEnabled: Bool

    var isAllowed: Bool {
        #if os(iOS)
        if authorizationStatus == .ephemeral { return true }
        #endif
        return authorizationStatus == .authorized || authorizationStatus == .provisional
    }
}

@MainActor
protocol InstallationNotificationCenter {
    func access() async -> InstallationNotificationAccess
    func requestAuthorization() async throws
    func pendingRequests() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async throws
    func removePending(identifiers: [String])
    func removeDelivered(identifiers: [String])
}

@MainActor
final class SystemInstallationNotificationCenter: InstallationNotificationCenter {
    private let center = UNUserNotificationCenter.current()

    func access() async -> InstallationNotificationAccess {
        let settings = await center.notificationSettings()
        return InstallationNotificationAccess(
            authorizationStatus: settings.authorizationStatus,
            alertsEnabled: settings.alertSetting == .enabled
        )
    }

    func requestAuthorization() async throws {
        _ = try await center.requestAuthorization(options: [.alert, .sound])
    }

    func pendingRequests() async -> [UNNotificationRequest] { await center.pendingNotificationRequests() }
    func add(_ request: UNNotificationRequest) async throws { try await center.add(request) }
    func removePending(identifiers: [String]) { center.removePendingNotificationRequests(withIdentifiers: identifiers) }
    func removeDelivered(identifiers: [String]) { center.removeDeliveredNotifications(withIdentifiers: identifiers) }
}

/// Only the renewal reminder opts into foreground presentation. Existing alert behaviour stays unchanged.
final class InstallationNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = InstallationNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler(notification.request.identifier == InstallationReminderNotification.identifier
            ? [.banner, .sound] : [])
    }
}

@MainActor
final class InstallationReminderService: ObservableObject {
    static let shared = InstallationReminderService(center: SystemInstallationNotificationCenter())

    @Published private(set) var expirationDate: Date?
    @Published private(set) var reminderDate: Date?
    @Published private(set) var status = "A verificar a validade indicada pelo perfil…"
    @Published private(set) var permissionDenied = false
    @Published private(set) var permissionNotDetermined = false
    @Published private(set) var lastError: String?
    @Published private(set) var enabled: Bool
    @Published private(set) var leadHours: Int
    @Published private(set) var isRefreshing = false

    private let center: InstallationNotificationCenter
    private let defaults: UserDefaults
    private let validityProvider: () -> InstallationValidity?
    private let now: () -> Date
    private var refreshActive = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private static let enabledKey = "installationReminder.enabled"
    private static let hoursKey = "installationReminder.leadHours"
    private static let receiptKey = "installationReminder.receipt"

    init(
        center: InstallationNotificationCenter,
        defaults: UserDefaults = .standard,
        validityProvider: @escaping () -> InstallationValidity? = { InstallationValidity.bundled() },
        now: @escaping () -> Date = { .now }
    ) {
        self.center = center
        self.defaults = defaults
        self.validityProvider = validityProvider
        self.now = now
        enabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
        let storedHours = defaults.integer(forKey: Self.hoursKey)
        leadHours = [6, 12, 24, 48].contains(storedHours) ? storedHours : 24
    }

    func configure(enabled: Bool, leadHours: Int) async {
        guard [6, 12, 24, 48].contains(leadHours) else { return }
        self.enabled = enabled
        self.leadHours = leadHours
        defaults.set(enabled, forKey: Self.enabledKey)
        defaults.set(leadHours, forKey: Self.hoursKey)
        await refresh()
    }

    /// Reconcile one absolute, non-repeating notification. Never touches financial data or other alerts.
    func refresh(requestAuthorization: Bool = false) async {
        await beginRefresh()
        isRefreshing = true
        defer { isRefreshing = false; endRefresh() }
        lastError = nil
        reminderDate = nil
        let validity = validityProvider()
        expirationDate = validity?.expirationDate
        var receipt = defaults.data(forKey: Self.receiptKey).flatMap {
            try? JSONDecoder().decode(InstallationReminderReceipt.self, from: $0)
        }
        let identifiers = [InstallationReminderNotification.identifier]
        if receipt?.expirationDate != expirationDate {
            center.removePending(identifiers: identifiers)
            center.removeDelivered(identifiers: identifiers)
            defaults.removeObject(forKey: Self.receiptKey)
            receipt = nil
        }

        do {
            var access = await center.access()
            if enabled, let expirationDate, expirationDate > now(),
               access.authorizationStatus == .notDetermined, requestAuthorization {
                try await center.requestAuthorization()
                access = await center.access()
            }
            permissionDenied = access.authorizationStatus == .denied
            permissionNotDetermined = access.authorizationStatus == .notDetermined

            guard enabled else {
                cancelPending(identifiers: identifiers, receipt: receipt)
                center.removeDelivered(identifiers: identifiers)
                status = "Aviso de renovação desativado."
                return
            }
            guard let expirationDate else {
                cancelPending(identifiers: identifiers, receipt: receipt)
                center.removeDelivered(identifiers: identifiers)
                status = "Data indisponível. Não foi possível ler a validade desta instalação; nenhum prazo foi estimado nem aviso agendado."
                return
            }
            guard expirationDate > now() else {
                cancelPending(identifiers: identifiers, receipt: receipt)
                status = "A data indicada pelo perfil já passou. Verifica a assinatura e volta a executar o projeto no Xcode."
                return
            }
            guard access.isAllowed else {
                cancelPending(identifiers: identifiers, receipt: receipt)
                status = permissionDenied
                    ? "As notificações estão bloqueadas nas Definições do iPhone."
                    : "Permite as notificações para receberes o aviso antes da expiração."
                return
            }

            let referenceDate = now()
            guard let proposedDate = InstallationReminderPlanner.fireDate(
                expirationDate: expirationDate, leadHours: leadHours, now: referenceDate, previous: receipt
            ) else {
                cancelPending(identifiers: identifiers, receipt: receipt)
                status = expirationDate.timeIntervalSince(referenceDate) <= 60
                    ? "A validade está a terminar. Renova a instalação no Xcode agora."
                    : "O horário do aviso desta validade já passou. Verifica a Central de Notificações; não será repetido a cada abertura."
                return
            }
            // Calendar triggers have second precision; round up, never schedule at/after expiry.
            let fireDate = Date(timeIntervalSince1970: ceil(proposedDate.timeIntervalSince1970))
            guard fireDate < expirationDate else {
                cancelPending(identifiers: identifiers, receipt: receipt)
                status = "A validade está a terminar. Renova a instalação no Xcode agora."
                return
            }
            let pending = await center.pendingRequests()
            let existing = pending.first { $0.identifier == InstallationReminderNotification.identifier }
            let existingDate = (existing?.trigger as? UNCalendarNotificationTrigger).flatMap {
                $0.repeats ? nil : Self.triggerCalendar.date(from: $0.dateComponents)
            }
            let existingExpiry = existing?.content.userInfo["expiration"] as? Double
            if existingDate != fireDate || existingExpiry != expirationDate.timeIntervalSince1970 {
                let content = UNMutableNotificationContent()
                content.title = "Renovar a app no Xcode"
                content.body = "A validade indicada para esta instalação termina em \(Self.dateDescription(expirationDate)). Liga o iPhone ao Mac e volta a executar o projeto no Xcode. Não apagues a app."
                content.sound = .default
                content.userInfo = ["expiration": expirationDate.timeIntervalSince1970]
                var components = Self.triggerCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
                components.calendar = Self.triggerCalendar
                components.timeZone = Self.triggerCalendar.timeZone
                cancelPending(identifiers: identifiers, receipt: receipt)
                try await center.add(UNNotificationRequest(
                    identifier: InstallationReminderNotification.identifier,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                ))
            }
            let savedReceipt = InstallationReminderReceipt(expirationDate: expirationDate, fireDate: fireDate)
            defaults.set(try JSONEncoder().encode(savedReceipt), forKey: Self.receiptKey)
            reminderDate = fireDate
            status = access.alertsEnabled && access.authorizationStatus != .provisional
                ? "Aviso agendado. Depois de atualizares pelo Xcode, abre a app para verificar a nova validade."
                : "Aviso agendado, mas o iOS pode apresentá-lo silenciosamente. Verifica as opções de alertas nas Definições do iPhone."
        } catch {
            lastError = "Não foi possível agendar o aviso de renovação. Tenta atualizar o estado novamente."
            status = "Aviso não confirmado."
        }
    }

    private func cancelPending(identifiers: [String], receipt: InstallationReminderReceipt?) {
        center.removePending(identifiers: identifiers)
        // A request cancelled BEFORE its fire date cannot be treated as already issued.
        // Keep past receipts to avoid repeating alerts that may already have appeared.
        if let receipt, receipt.fireDate > now() {
            defaults.removeObject(forKey: Self.receiptKey)
        }
    }

    private static var triggerCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func dateDescription(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_PT")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func beginRefresh() async {
        if !refreshActive { refreshActive = true; return }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func endRefresh() {
        if waiters.isEmpty { refreshActive = false } else { waiters.removeFirst().resume() }
    }
}
