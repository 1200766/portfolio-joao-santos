import Foundation

struct WeeklyBudgetProgress: Identifiable {
    let bucket: BudgetBucket
    let spentInCents: Int
    let limitInCents: Int?

    var id: BudgetBucket { bucket }
    var remainingInCents: Int? { limitInCents.map { max($0 - spentInCents, 0) } }
    var excessInCents: Int? { limitInCents.map { max(spentInCents - $0, 0) } }
}

enum WeeklyBudgetService {
    static func calendar(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timeZone
        return calendar
    }

    static func weekInterval(
        containing date: Date,
        calendar: Calendar = calendar()
    ) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(
            start: calendar.startOfDay(for: date),
            duration: 7 * 24 * 60 * 60
        )
    }

    static func bucket(
        for movement: Movement,
        assignments: [MovementBudgetAssignment]
    ) -> BudgetBucket? {
        if let assignment = assignments.first(where: { $0.movementID == movement.id }) {
            if assignment.selection != .automatic {
                return assignment.selection.bucket
            }
        }
        return automaticBucket(forCategoryNamed: movement.category?.name)
    }

    static func automaticBucket(forCategoryNamed categoryName: String?) -> BudgetBucket? {
        guard let categoryName else { return nil }
        switch CategorizationService.normalize(categoryName) {
        case "alimentacao": return .groceries
        case "transportes": return .transport
        case "lazer": return .leisure
        default: return nil
        }
    }

    static func progress(
        for week: Date,
        movements: [Movement],
        assignments: [MovementBudgetAssignment],
        plan: WeeklyBudgetPlan? = nil,
        asOf date: Date = .now,
        calendar: Calendar = calendar()
    ) -> [WeeklyBudgetProgress] {
        let interval = weekInterval(containing: week, calendar: calendar)
        let currentDay = calendar.startOfDay(for: date)
        let activePlan = plan.flatMap {
            $0.weekKey == weekKey(containing: week, calendar: calendar) ? $0 : nil
        }
        let eligibleMovements = movements.filter {
            $0.isConfirmed &&
            $0.type == .expense &&
            $0.date >= interval.start &&
            $0.date < interval.end &&
            calendar.startOfDay(for: $0.date) <= currentDay
        }

        return BudgetBucket.allCases.map { bucket in
            let spent = eligibleMovements
                .filter { self.bucket(for: $0, assignments: assignments) == bucket }
                .reduce(0) { $0 + $1.amountInCents }
            return WeeklyBudgetProgress(
                bucket: bucket,
                spentInCents: spent,
                limitInCents: activePlan.map { $0.limit(for: bucket) }
            )
        }
    }

    static func crossedThresholds(
        for progress: WeeklyBudgetProgress
    ) -> [BudgetNotificationThreshold] {
        guard progress.bucket.sendsNotifications,
              let limit = progress.limitInCents,
              limit >= 0 else { return [] }
        if limit == 0 {
            return progress.spentInCents > 0 ? [.exceeded] : []
        }

        var thresholds: [BudgetNotificationThreshold] = []
        if Double(progress.spentInCents) / Double(limit) >= 0.8 {
            thresholds.append(.approaching)
        }
        if progress.spentInCents >= limit {
            thresholds.append(.reached)
        }
        if progress.spentInCents > limit {
            thresholds.append(.exceeded)
        }
        return thresholds
    }

    // A local calendar key keeps a week's identity stable across timezone changes.
    static func weekKey(containing date: Date, calendar: Calendar = calendar()) -> String {
        let start = weekInterval(containing: date, calendar: calendar).start
        let components = calendar.dateComponents([.year, .month, .day], from: start)
        return String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
    }

    static func title(for date: Date, calendar: Calendar = calendar()) -> String {
        let interval = weekInterval(containing: date, calendar: calendar)
        let end = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_PT")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: interval.start)) – \(formatter.string(from: end))"
    }

    // Fully validate the text so invalid prefixes and excessive decimals cannot be saved.
    static func limitCents(from text: String) -> Int? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.range(of: #"^[0-9]{1,7}([,.][0-9]{1,2})?$"#, options: .regularExpression) != nil else {
            return nil
        }
        let parts = value.replacingOccurrences(of: ",", with: ".").split(separator: ".")
        guard let euros = Int(parts[0]) else { return nil }
        let fraction = parts.count > 1 ? String(parts[1]).padding(toLength: 2, withPad: "0", startingAt: 0) : "00"
        return euros * 100 + (Int(fraction) ?? 0)
    }
}
