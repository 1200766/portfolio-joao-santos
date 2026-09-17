import Foundation
import SwiftData

// Compile with the actual app models, RecurrenceService and BalanceService.
@MainActor
@main
struct RecurrenceIntervalChecks {
    static var assertions = 0
    static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Lisbon")!
        return value
    }

    static func main() throws {
        try calendarCadences()
        try projectionsAndForecast()
        try materializationOverridesAndHistory()
        try persistedFrequencies()
        print("Recurrence intervals: \(assertions) assertions passed, including real SwiftData generation and disk roundtrip.")
    }

    static func check(_ condition: @autoclosure () throws -> Bool, _ message: String, line: UInt = #line) throws {
        guard try condition() else { throw CheckFailure(message: "Line \(line): \(message)") }
        assertions += 1
    }

    static func date(_ day: Int, month: Int = 9, year: Int = 2026, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    static func container(at url: URL? = nil) throws -> ModelContainer {
        let schema = Schema([FinanceCategory.self, Movement.self, RecurringRule.self, RecurringOverride.self])
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration("RecurrenceChecks", schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func calendarCadences() throws {
        try check(RecurrenceFrequency.allCases.count == 4, "All four frequencies are offered")
        try check(RecurrenceFrequency(rawValue: "weekly") == .weekly, "Existing weekly raw values remain valid")
        try check(RecurrenceFrequency(rawValue: "monthly") == .monthly, "Existing monthly raw values remain valid")
        for (frequency, weeks) in [(RecurrenceFrequency.weekly, 1), (.everyTwoWeeks, 2), (.everyThreeWeeks, 3)] {
            try check(frequency.weekInterval == weeks, "Week-based income overrides cover the selected cadence")
            let next = RecurrenceService.nextDate(after: date(7), frequency: frequency, calendar: calendar)
            try check(next == date(7 + weeks * 7), "Converting a movement starts after the original occurrence")
        }
        try check(RecurrenceFrequency.monthly.weekInterval == nil, "Monthly behaviour remains unchanged")
        try check(RecurrenceService.nextDate(after: date(15), frequency: .monthly, calendar: calendar) == date(15, month: 10),
                  "Monthly recurrence still uses calendar months")
        for (frequency, weeks) in [(RecurrenceFrequency.everyTwoWeeks, 2), (.everyThreeWeeks, 3)] {
            let start = date(12, month: 10)
            guard let next = RecurrenceService.nextDate(after: start, frequency: frequency, calendar: calendar) else {
                throw CheckFailure(message: "No next date across daylight saving")
            }
            try check(calendar.component(.hour, from: next) == 9, "The local hour stays fixed across daylight saving")
            try check(calendar.dateComponents([.day], from: start, to: next).day == weeks * 7,
                      "The interval is calendar weeks, not a fixed number of seconds")
        }
    }

    static func projectionsAndForecast() throws {
        let income = RecurringRule(details: "Ganho de duas em duas semanas", amountInCents: 15_000, type: .income,
                                   frequency: .everyTwoWeeks, nextDueDate: date(7), category: nil)
        let expense = RecurringRule(details: "Despesa de três em três semanas", amountInCents: 2_000, type: .expense,
                                    frequency: .everyThreeWeeks, nextDueDate: date(1), category: nil)
        let september = DateInterval(start: date(1, hour: 0), end: date(1, month: 10, hour: 0))
        try check(RecurrenceService.projectedDates(for: income, in: september, calendar: calendar) == [date(7), date(21)],
                  "The two-week rule projects the correct September dates")
        try check(RecurrenceService.projectedDates(for: expense, in: september, calendar: calendar) == [date(1), date(22)],
                  "The three-week rule projects the correct September dates")
        let october = DateInterval(start: date(1, month: 10, hour: 0), end: date(1, month: 11, hour: 0))
        try check(RecurrenceService.projectedDates(for: expense, in: october, calendar: calendar) == [date(13, month: 10)],
                  "Projection carries the original cadence across month boundaries")
        let original = Movement(date: date(7), details: income.details, amountInCents: 15_000, type: .income,
                                category: nil, sourceRecurringRuleID: income.id, occurrenceDate: date(7))
        let deduplicated = RecurrenceService.projectedOccurrences(for: [income], in: september, excluding: [original], calendar: calendar)
        try check(deduplicated.map(\.date) == [date(21)], "A materialized occurrence is not also projected")
        let override = RecurringOverride(recurringRuleID: income.id, occurrenceDate: date(21), amountInCents: 22_000)
        let snapshot = BalanceSnapshot(amountInCents: 60_000, referenceDate: date(7))
        // This existing movement is already part of the snapshot, not a new gain.
        original.createdAt = date(6)
        try check(BalanceService.monthEndForecast(snapshot: snapshot, movements: [original], recurringRules: [income, expense],
                                                recurringOverrides: [override], asOf: date(7), calendar: calendar) == 80_000,
                  "The real forecast includes only future two/three-week occurrences and the one-off override")
        income.isActive = false
        try check(RecurrenceService.projectedDates(for: income, in: september, calendar: calendar).isEmpty,
                  "Pausing a multiweek rule removes future projections")
    }

    static func materializationOverridesAndHistory() throws {
        let database = try container()
        let context = ModelContext(database)
        let income = RecurringRule(details: "Ganho", amountInCents: 15_000, type: .income, frequency: .everyTwoWeeks,
                                   nextDueDate: date(21), category: nil)
        let original = Movement(date: date(7), details: "Ganho original", amountInCents: 10_000, type: .income,
                                category: nil, sourceRecurringRuleID: income.id, occurrenceDate: date(7))
        context.insert(income)
        context.insert(original)
        context.insert(RecurringOverride(recurringRuleID: income.id, occurrenceDate: date(21), amountInCents: 22_000))
        try context.save()
        try RecurrenceService.generateDueMovements(in: context, through: date(5, month: 10), calendar: calendar)
        var movements = try context.fetch(FetchDescriptor<Movement>(sortBy: [SortDescriptor(\.date)]))
        try check(movements.map(\.date) == [date(7), date(21), date(5, month: 10)], "Catch-up creates only due two-week occurrences")
        try check(movements.map(\.amountInCents) == [10_000, 22_000, 15_000], "A one-off override affects only its occurrence")
        try check(movements.allSatisfy { $0.isConfirmed && $0.type == .income }, "Generated income stays confirmed")
        try check(income.nextDueDate == date(19, month: 10), "The next due date advances by two calendar weeks")
        try check(try context.fetchCount(FetchDescriptor<RecurringOverride>()) == 0, "A consumed override is cleared")
        try RecurrenceService.generateDueMovements(in: context, through: date(5, month: 10), calendar: calendar)
        try check(try context.fetchCount(FetchDescriptor<Movement>()) == 3, "Repeated processing cannot duplicate movements")

        income.frequency = .everyThreeWeeks
        income.amountInCents = 30_000
        try context.save()
        try RecurrenceService.generateDueMovements(in: context, through: date(19, month: 10), calendar: calendar)
        movements = try context.fetch(FetchDescriptor<Movement>(sortBy: [SortDescriptor(\.date)]))
        try check(movements.prefix(3).map(\.amountInCents) == [10_000, 22_000, 15_000], "Editing frequency and value never rewrites history")
        try check(movements.last?.amountInCents == 30_000, "An edited rule applies its new value at the selected next date")
        try check(income.nextDueDate == date(9, month: 11), "The new three-week cadence starts from the next due occurrence")
        income.isActive = false
        try context.save()
        try RecurrenceService.generateDueMovements(in: context, through: date(30, month: 11), calendar: calendar)
        try check(try context.fetchCount(FetchDescriptor<Movement>()) == 4, "Inactive multiweek rules create nothing")

        let expense = RecurringRule(details: "Despesa", amountInCents: 2_000, type: .expense, frequency: .everyThreeWeeks,
                                    nextDueDate: date(1), category: nil)
        context.insert(expense)
        try context.save()
        try RecurrenceService.generateDueMovements(in: context, through: date(13, month: 10), calendar: calendar)
        let expenses = try context.fetch(FetchDescriptor<Movement>(sortBy: [SortDescriptor(\.date)])).filter { $0.type == .expense }
        try check(expenses.map(\.date) == [date(1), date(22), date(13, month: 10)], "Three-week expense catch-up includes each due date")
        try check(expenses.allSatisfy { $0.amountInCents == 2_000 && $0.isConfirmed }, "The expense amount and confirmation remain intact")
        try check(expense.nextDueDate == date(3, month: 11), "No future occurrence is prematurely materialized")
    }

    static func persistedFrequencies() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("recurrence-interval-checks-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = directory.appendingPathComponent("recurrences.store")
        try autoreleasepool {
            let database = try container(at: store)
            let context = ModelContext(database)
            for frequency in RecurrenceFrequency.allCases {
                context.insert(RecurringRule(details: frequency.title, amountInCents: 1_000, type: .expense,
                                             frequency: frequency, nextDueDate: date(7), category: nil))
            }
            try context.save()
        }
        try autoreleasepool {
            let database = try container(at: store)
            let context = ModelContext(database)
            let rules = try context.fetch(FetchDescriptor<RecurringRule>())
            try check(rules.count == 4, "Old and new rules all survive reopening the data store")
            for frequency in RecurrenceFrequency.allCases {
                let rule = rules.first { $0.frequency == frequency }
                try check(rule?.frequencyRawValue == frequency.rawValue, "Each raw frequency persists without a schema migration")
                try check(rule?.details == frequency.title, "Reopening preserves the rule alongside its frequency")
            }
        }
    }

    struct CheckFailure: Error, CustomStringConvertible {
        let message: String
        var description: String { message }
    }
}
