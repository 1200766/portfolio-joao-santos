import Foundation
import SwiftData

struct ProjectedOccurrence: Identifiable {
    let rule: RecurringRule
    let date: Date

    var id: String {
        "\(rule.id.uuidString)-\(date.timeIntervalSinceReferenceDate)"
    }
}

@MainActor
enum RecurrenceService {
    static func generateDueMovements(
        in context: ModelContext,
        through date: Date = .now,
        calendar: Calendar = .current
    ) throws {
        let descriptor = FetchDescriptor<RecurringRule>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.nextDueDate)]
        )
        let rules = try context.fetch(descriptor)
        let today = calendar.startOfDay(for: date)

        for rule in rules {
            while calendar.startOfDay(for: rule.nextDueDate) <= today {
                let dueDate = rule.nextDueDate
                let ruleID = rule.id
                let dueDay = calendar.startOfDay(for: dueDate)
                let nextDay = calendar.date(byAdding: .day, value: 1, to: dueDay) ?? dueDay

                let existingDescriptor = FetchDescriptor<Movement>(
                    predicate: #Predicate { $0.sourceRecurringRuleID == ruleID }
                )
                let alreadyExists = try context.fetch(existingDescriptor).contains { movement in
                    guard let occurrenceDate = movement.occurrenceDate else { return false }
                    return occurrenceDate >= dueDay && occurrenceDate < nextDay
                }

                if !alreadyExists {
                    let overrideDescriptor = FetchDescriptor<RecurringOverride>(
                        predicate: #Predicate { $0.recurringRuleID == ruleID }
                    )
                    let override = try context.fetch(overrideDescriptor).first {
                        $0.occurrenceDate >= dueDay && $0.occurrenceDate < nextDay
                    }
                    let movement = Movement(
                        date: dueDate,
                        details: rule.details,
                        amountInCents: override?.amountInCents ?? rule.amountInCents,
                        type: rule.type,
                        category: rule.category,
                        isConfirmed: true,
                        sourceRecurringRuleID: rule.id,
                        occurrenceDate: dueDate
                    )
                    context.insert(movement)
                    if let override {
                        context.delete(override)
                    }
                }

                guard let nextDate = nextDate(after: dueDate, frequency: rule.frequency, calendar: calendar),
                      nextDate > dueDate else {
                    rule.isActive = false
                    break
                }
                rule.nextDueDate = nextDate
            }
        }

        try context.save()
    }

    static func projectedOccurrences(
        for rules: [RecurringRule],
        in interval: DateInterval,
        excluding movements: [Movement],
        calendar: Calendar = .current
    ) -> [ProjectedOccurrence] {
        rules
            .filter(\.isActive)
            .flatMap { rule in
                projectedDates(for: rule, in: interval, calendar: calendar)
                    .filter { date in
                        !movements.contains { movement in
                            movement.sourceRecurringRuleID == rule.id &&
                            movement.occurrenceDate.map {
                                calendar.isDate($0, inSameDayAs: date)
                            } == true
                        }
                    }
                    .map { ProjectedOccurrence(rule: rule, date: $0) }
            }
            .sorted { $0.date < $1.date }
    }

    static func projectedDates(
        for rule: RecurringRule,
        in interval: DateInterval,
        calendar: Calendar = .current
    ) -> [Date] {
        guard rule.isActive else { return [] }

        var dates: [Date] = []
        var cursor = rule.nextDueDate

        while cursor < interval.start {
            guard let next = nextDate(after: cursor, frequency: rule.frequency, calendar: calendar),
                  next > cursor else {
                return dates
            }
            cursor = next
        }

        while cursor < interval.end {
            dates.append(cursor)
            guard let next = nextDate(after: cursor, frequency: rule.frequency, calendar: calendar),
                  next > cursor else {
                break
            }
            cursor = next
        }

        return dates
    }

    static func removeLegacyFutureMaterializationsIfNeeded(
        in context: ModelContext,
        after date: Date = .now,
        defaults: UserDefaults = .standard
    ) throws {
        let migrationKey = "didRemoveLimitedFutureMaterializationsV1"
        guard !defaults.bool(forKey: migrationKey) else { return }

        let calendar = Calendar.current
        let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: date)
        ) ?? date
        let movements = try context.fetch(FetchDescriptor<Movement>())
        let rules = try context.fetch(FetchDescriptor<RecurringRule>())
        let rulesByID = Dictionary(uniqueKeysWithValues: rules.map { ($0.id, $0) })

        for movement in movements where movement.date >= tomorrow {
            guard let ruleID = movement.sourceRecurringRuleID,
                  let rule = rulesByID[ruleID],
                  let occurrenceDate = movement.occurrenceDate else {
                continue
            }
            if occurrenceDate < rule.nextDueDate {
                rule.nextDueDate = occurrenceDate
            }
            context.delete(movement)
        }

        try context.save()
        defaults.set(true, forKey: migrationKey)
    }

    static func nextDate(
        after date: Date,
        frequency: RecurrenceFrequency,
        calendar: Calendar = .current
    ) -> Date? {
        switch frequency {
        case .weekly:
            calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .everyTwoWeeks:
            calendar.date(byAdding: .weekOfYear, value: 2, to: date)
        case .everyThreeWeeks:
            calendar.date(byAdding: .weekOfYear, value: 3, to: date)
        case .monthly:
            calendar.date(byAdding: .month, value: 1, to: date)
        }
    }
}
