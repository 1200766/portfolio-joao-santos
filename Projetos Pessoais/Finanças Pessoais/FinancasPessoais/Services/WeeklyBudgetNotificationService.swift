import SwiftData
import UserNotifications

@MainActor
enum WeeklyBudgetNotificationService {
    private static let sundayReminderIdentifier = "weekly-budget-sunday-reminder"
    private static var isEvaluating = false
    private static var evaluationWaiters: [CheckedContinuation<Void, Never>] = []

    enum ReminderError: LocalizedError {
        case invalidTime

        var errorDescription: String? {
            "Escolha uma hora válida para o lembrete de domingo."
        }
    }

    /// A single repeating request follows the device's local Sunday and time.
    @discardableResult
    static func scheduleSundayReminder(
        hour: Int,
        minute: Int,
        requestAuthorization: Bool = false
    ) async throws -> Bool {
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            throw ReminderError.invalidTime
        }

        let center = UNUserNotificationCenter.current()
        guard try await notificationsAllowed(
            center: center,
            requestAuthorization: requestAuthorization
        ) else {
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = "Objetivos da próxima semana"
        content.body = "Personaliza ou confirma os limites para a semana que começa amanhã. Sem confirmação, os limites ficam inativos."
        content.sound = .default

        let pendingRequests = await center.pendingNotificationRequests()
        if let existing = pendingRequests.first(where: {
            $0.identifier == sundayReminderIdentifier
        }), let trigger = existing.trigger as? UNCalendarNotificationTrigger,
           trigger.repeats,
           trigger.dateComponents.weekday == 1,
           trigger.dateComponents.hour == hour,
           trigger.dateComponents.minute == minute,
           existing.content.title == content.title,
           existing.content.body == content.body {
            return true
        }

        var components = DateComponents()
        components.weekday = 1
        components.hour = hour
        components.minute = minute
        components.second = 0
        try await center.add(UNNotificationRequest(
            identifier: sundayReminderIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: true
            )
        ))
        return true
    }

    static func requestAuthorizationAndEvaluate(
        movements: [Movement],
        assignments: [MovementBudgetAssignment],
        records _: [BudgetNotificationRecord],
        in context: ModelContext,
        date: Date = .now,
        requestAuthorization: Bool = true
    ) async throws {
        // Main-actor isolation alone does not prevent reentry across notification awaits.
        // Queue evaluations so a movement saved during another evaluation is still checked.
        await beginEvaluation()
        defer { endEvaluation() }

        let defaults = UserDefaults.standard
        let reminderHour = defaults.object(forKey: "weeklyBudget.reminderHour") as? Int ?? 18
        let reminderMinute = defaults.object(forKey: "weeklyBudget.reminderMinute") as? Int ?? 0
        guard try await scheduleSundayReminder(
            hour: reminderHour,
            minute: reminderMinute,
            requestAuthorization: requestAuthorization
        ) else {
            return
        }

        let calendar = WeeklyBudgetService.calendar()
        let weekKey = WeeklyBudgetService.weekKey(containing: date, calendar: calendar)
        let plans = try context.fetch(FetchDescriptor<WeeklyBudgetPlan>())
        guard let plan = plans.first(where: { $0.weekKey == weekKey }) else {
            return
        }

        let center = UNUserNotificationCenter.current()
        let weekStart = WeeklyBudgetService.weekInterval(
            containing: date,
            calendar: calendar
        ).start
        let progresses = WeeklyBudgetService.progress(
            for: date,
            movements: movements,
            assignments: assignments,
            plan: plan,
            asOf: date,
            calendar: calendar
        )

        for progress in progresses {
            for threshold in WeeklyBudgetService.crossedThresholds(for: progress) {
                // Query results supplied by views can lag behind a just-saved notification.
                let records = try context.fetch(FetchDescriptor<BudgetNotificationRecord>())
                let alreadySent = records.contains {
                    $0.bucketRawValue == progress.bucket.rawValue &&
                    $0.thresholdRawValue == threshold.rawValue &&
                    calendar.isDate($0.weekStart, inSameDayAs: weekStart)
                }
                guard !alreadySent else { continue }

                let content = notificationContent(for: progress, threshold: threshold)
                let identifier = [
                    "weekly-budget",
                    progress.bucket.rawValue,
                    threshold.rawValue,
                    String(Int(weekStart.timeIntervalSince1970))
                ].joined(separator: "-")
                try await center.add(UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: nil
                ))
                context.insert(BudgetNotificationRecord(
                    bucket: progress.bucket,
                    threshold: threshold,
                    weekStart: weekStart
                ))
                try context.save()
            }
        }
    }

    private static func notificationsAllowed(
        center: UNUserNotificationCenter,
        requestAuthorization: Bool
    ) async throws -> Bool {
        var settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined, requestAuthorization {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
            settings = await center.notificationSettings()
        }
        return settings.authorizationStatus == .authorized ||
            settings.authorizationStatus == .provisional
    }

    private static func beginEvaluation() async {
        if !isEvaluating {
            isEvaluating = true
            return
        }
        await withCheckedContinuation { continuation in
            evaluationWaiters.append(continuation)
        }
    }

    private static func endEvaluation() {
        if evaluationWaiters.isEmpty {
            isEvaluating = false
        } else {
            evaluationWaiters.removeFirst().resume()
        }
    }

    private static func notificationContent(
        for progress: WeeklyBudgetProgress,
        threshold: BudgetNotificationThreshold
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.sound = .default
        let limit = Money.formatted(cents: progress.limitInCents ?? 0)

        switch threshold {
        case .approaching:
            content.title = "Orçamento de \(progress.bucket.title)"
            content.body = "Atingiu 80% do limite semanal de \(limit)."
        case .reached:
            content.title = "Limite semanal atingido"
            content.body = "A rubrica \(progress.bucket.title) atingiu o limite de \(limit)."
        case .exceeded:
            content.title = "Limite semanal excedido"
            content.body = "A rubrica \(progress.bucket.title) está \(Money.formatted(cents: progress.excessInCents ?? 0)) acima do limite de \(limit)."
        }
        return content
    }
}
