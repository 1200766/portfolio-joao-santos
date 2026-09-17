import Foundation
import SwiftData

// Compile this executable alongside the app models and services, outside the iOS target.
@MainActor
@main
struct WeeklyBudgetServiceChecks {
    static var assertions = 0
    static let calendar = WeeklyBudgetService.calendar(timeZone: TimeZone(identifier: "Europe/Lisbon")!)

    static func main() throws {
        try calendarAndInactiveWeeks()
        try configuredLimitsAndEligibleMovements()
        try associationOverrides()
        try thresholdPolicy()
        try strictLimitParsing()
        try persistenceAndAdditiveSchema()
        print("WeeklyBudgetService: \(assertions) assertions passed, including SwiftData migration and disk roundtrip.")
    }

    static func check(_ condition: @autoclosure () throws -> Bool, _ message: String, line: UInt = #line) throws {
        guard try condition() else { throw CheckFailure(message: "Line \(line): \(message)") }
        assertions += 1
    }

    static func date(_ day: Int, month: Int = 9, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    static func plan(for date: Date) -> WeeklyBudgetPlan {
        WeeklyBudgetPlan(
            weekKey: WeeklyBudgetService.weekKey(containing: date, calendar: calendar),
            weekStart: WeeklyBudgetService.weekInterval(containing: date, calendar: calendar).start,
            totalLimitInCents: 6_000,
            groceriesLimitInCents: 500,
            transportLimitInCents: 5_000,
            leisureLimitInCents: 2_000,
            confirmedAt: self.date(9)
        )
    }

    static func movement(_ amount: Int, day: Int, category: String, type: MovementType = .expense,
                         isConfirmed: Bool = true) -> Movement {
        Movement(date: date(day), details: "Despesa de teste", amountInCents: amount, type: type,
                 category: FinanceCategory(name: category), isConfirmed: isConfirmed)
    }

    static func progress(on day: Int, movements: [Movement], plan: WeeklyBudgetPlan? = nil,
                         asOf: Int? = nil, assignments: [MovementBudgetAssignment] = []) -> [WeeklyBudgetProgress] {
        WeeklyBudgetService.progress(for: date(day), movements: movements, assignments: assignments,
                                     plan: plan, asOf: date(asOf ?? day), calendar: calendar)
    }

    static func calendarAndInactiveWeeks() throws {
        let interval = WeeklyBudgetService.weekInterval(containing: date(13), calendar: calendar)
        try check(interval.start == date(7, hour: 0), "A week starts on Monday at midnight")
        try check(interval.end == date(14, hour: 0), "A week ends before the next Monday")
        try check(WeeklyBudgetService.weekKey(containing: date(13), calendar: calendar) == "2026-09-07",
                  "Sunday belongs to the previous Monday's week")
        let dst = WeeklyBudgetService.weekInterval(containing: date(25, month: 10), calendar: calendar)
        try check(calendar.component(.hour, from: dst.end) == 0 && dst.duration == 169 * 60 * 60,
                  "The Sunday clock change preserves a local Monday boundary")

        let purchases = [movement(300, day: 9, category: "Alimentação"), movement(700, day: 14, category: "Alimentação")]
        let noPlan = progress(on: 9, movements: purchases)
        try check(noPlan[0].spentInCents == 300, "Spending remains visible before personalization")
        try check(noPlan.allSatisfy { $0.limitInCents == nil && $0.remainingInCents == nil && $0.excessInCents == nil },
                  "No plan means no active limit, remaining allowance or excess")
        try check(noPlan.allSatisfy { WeeklyBudgetService.crossedThresholds(for: $0).isEmpty },
                  "An unconfigured week produces no budget warnings")
        let confirmed = plan(for: date(7))
        let sunday = progress(on: 13, movements: purchases, plan: confirmed)
        try check(sunday[0].remainingInCents == 200, "Confirmation remains active through Sunday")
        let nextMonday = progress(on: 14, movements: purchases, plan: confirmed)
        try check(nextMonday[0].spentInCents == 700, "The new week keeps its own spending")
        try check(nextMonday.allSatisfy { $0.limitInCents == nil }, "A previous plan never carries into the new week")
    }

    static func configuredLimitsAndEligibleMovements() throws {
        let confirmed = plan(for: date(7))
        let purchases = [
            movement(200, day: 7, category: "Alimentação"),
            movement(250, day: 9, category: "Alimentação"),
            movement(100, day: 10, category: "Alimentação"),
            movement(1_000, day: 6, category: "Alimentação"),
            movement(9_000, day: 9, category: "Alimentação", isConfirmed: false),
            movement(9_000, day: 9, category: "Alimentação", type: .income),
            movement(4_000, day: 9, category: "Transportes"),
            movement(2_500, day: 9, category: "Lazer"),
            movement(9_000, day: 9, category: "Habitação")
        ]
        let current = progress(on: 9, movements: purchases, plan: confirmed)
        try check(current[0].spentInCents == 450 && current[0].remainingInCents == 50,
                  "Midweek confirmation includes earlier and current expenses immediately")
        try check(current[1].limitInCents == 5_000 && current[1].remainingInCents == 1_000,
                  "Transport supports a customized fifty-euro limit")
        try check(current[2].limitInCents == 2_000 && current[2].excessInCents == 500,
                  "The leisure limit may be decreased independently")
        try check(current.reduce(0) { $0 + $1.spentInCents } == 6_950,
                  "Only eligible, associated expenses contribute once to the weekly objectives")
        try check(confirmed.totalLimitInCents == 6_000 &&
                  confirmed.totalLimitInCents != BudgetBucket.allCases.reduce(0) { $0 + confirmed.limit(for: $1) },
                  "The total limit is independent of the category sum")
        let tomorrow = progress(on: 9, movements: purchases, plan: confirmed, asOf: 10)
        try check(tomorrow[0].spentInCents == 550 && tomorrow[0].excessInCents == 50,
                  "A future expense joins the objective when its date arrives")
        confirmed.groceriesLimitInCents = 1_000
        confirmed.transportLimitInCents = 7_000
        let edited = progress(on: 9, movements: purchases, plan: confirmed)
        try check(edited[0].remainingInCents == 550 && edited[1].remainingInCents == 3_000,
                  "Editing active limits recalculates existing spending immediately")
        try check(confirmed.totalLimitInCents == 6_000, "Editing category limits does not rewrite the global limit")
    }

    static func associationOverrides() throws {
        let transport = movement(1_000, day: 9, category: "tRANsPOrtes")
        let automatic = MovementBudgetAssignment(movementID: transport.id, selection: .automatic)
        try check(WeeklyBudgetService.bucket(for: transport, assignments: []) == .transport,
                  "Automatic mapping ignores case and accents")
        try check(WeeklyBudgetService.bucket(for: transport, assignments: [automatic]) == .transport,
                  "An explicit automatic assignment still resolves the category")
        automatic.selection = .leisure
        try check(WeeklyBudgetService.bucket(for: transport, assignments: [automatic]) == .leisure,
                  "A manual assignment overrides the automatic category")
        automatic.selection = .excluded
        try check(WeeklyBudgetService.bucket(for: transport, assignments: [automatic]) == nil,
                  "An excluded expense contributes to no objective")
        automatic.selection = .automatic
        transport.category?.name = "Alimentação"
        try check(WeeklyBudgetService.bucket(for: transport, assignments: [automatic]) == .groceries,
                  "Restoring automatic mapping follows later category edits")
    }

    static func thresholdPolicy() throws {
        for bucket in BudgetBucket.allCases {
            let noLimit = WeeklyBudgetProgress(bucket: bucket, spentInCents: 9_000, limitInCents: nil)
            let zeroEmpty = WeeklyBudgetProgress(bucket: bucket, spentInCents: 0, limitInCents: 0)
            let zeroSpent = WeeklyBudgetProgress(bucket: bucket, spentInCents: 1, limitInCents: 0)
            try check(WeeklyBudgetService.crossedThresholds(for: noLimit).isEmpty, "Nil limits never alert")
            try check(WeeklyBudgetService.crossedThresholds(for: zeroEmpty).isEmpty, "Zero spending against zero never alerts")
            try check(WeeklyBudgetService.crossedThresholds(for: zeroSpent) == (bucket == .transport ? [] : [.exceeded]),
                      "A zero limit alerts only for actual excess, with transport still silent")
        }
        let cases: [(Int, [BudgetNotificationThreshold])] = [
            (399, []), (400, [.approaching]), (500, [.approaching, .reached]),
            (501, [.approaching, .reached, .exceeded])
        ]
        for (spent, expected) in cases {
            try check(WeeklyBudgetService.crossedThresholds(for: WeeklyBudgetProgress(
                bucket: .groceries, spentInCents: spent, limitInCents: 500
            )) == expected, "Thresholds track the configured limit exactly")
        }
        try check(WeeklyBudgetService.crossedThresholds(for: WeeklyBudgetProgress(
            bucket: .transport, spentInCents: 9_000, limitInCents: 5_000
        )).isEmpty, "Transport stays silent above a positive limit")
    }

    static func strictLimitParsing() throws {
        let valid: [(String, Int)] = [
            ("0", 0), ("0,00", 0), ("50", 5_000), ("50,5", 5_050), ("50.05", 5_005),
            (" 90,00 \n", 9_000), ("9999999,99", 999_999_999)
        ]
        for (input, cents) in valid {
            try check(WeeklyBudgetService.limitCents(from: input) == cents, "Valid limits parse without changing cents")
        }
        for input in ["", "-1", "+1", "50abc", "50 €", "1,234", "1.234,56", "1e2", "NaN", "50,", ".50", "10000000", "1\n2"] {
            try check(WeeklyBudgetService.limitCents(from: input) == nil, "Invalid or partial amounts cannot become limits")
        }
    }

    static func schema(includingPlans: Bool) -> Schema {
        var models: [any PersistentModel.Type] = [
            FinanceCategory.self, Movement.self, CategorizationRule.self, RecurringRule.self,
            RecurringOverride.self, BalanceSnapshot.self, MovementBudgetAssignment.self, BudgetNotificationRecord.self
        ]
        if includingPlans { models.append(WeeklyBudgetPlan.self) }
        return Schema(models)
    }

    static func container(at url: URL, includingPlans: Bool) throws -> ModelContainer {
        let modelSchema = schema(includingPlans: includingPlans)
        return try ModelContainer(for: modelSchema, configurations: [
            ModelConfiguration(schema: modelSchema, url: url, cloudKitDatabase: .none)
        ])
    }

    static func persistenceAndAdditiveSchema() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("weekly-budget-checks-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = directory.appendingPathComponent("budget.store")
        let movementID = UUID()
        try autoreleasepool { try seedPreviousSchema(at: store, movementID: movementID) }
        try autoreleasepool { try migrateAndSavePlans(at: store, movementID: movementID) }
        try autoreleasepool { try reopenAndEditPlan(at: store) }
        try autoreleasepool {
            let database = try container(at: store, includingPlans: true)
            let context = ModelContext(database)
            let plans = try context.fetch(FetchDescriptor<WeeklyBudgetPlan>())
            let current = plans.first { $0.weekKey == "2026-09-07" }
            let next = plans.first { $0.weekKey == "2026-09-14" }
            try check(plans.count == 2, "One independent plan is stored for each confirmed week")
            try check(current?.totalLimitInCents == 8_000 && current?.transportLimitInCents == 7_000,
                      "Editing total and category limits survives a second reopening")
            try check(next?.totalLimitInCents == 6_000 && next?.transportLimitInCents == 5_000,
                      "Editing one saved week leaves the other unchanged")
        }
    }

    static func seedPreviousSchema(at url: URL, movementID: UUID) throws {
        let database = try container(at: url, includingPlans: false)
        let context = ModelContext(database)
        let category = FinanceCategory(name: "Transportes")
        let purchase = Movement(id: movementID, date: date(9), details: "Movimento anterior à atualização",
                                amountInCents: 4_000, type: .expense, category: category)
        let recurring = RecurringRule(details: "Recorrência preservada", amountInCents: 1_000, type: .expense,
                                      frequency: .weekly, nextDueDate: date(14), category: category)
        context.insert(category)
        context.insert(purchase)
        context.insert(recurring)
        context.insert(CategorizationRule(keyword: "posto", category: category))
        context.insert(RecurringOverride(recurringRuleID: recurring.id, occurrenceDate: date(14), amountInCents: 1_200))
        context.insert(BalanceSnapshot(amountInCents: 10_000, referenceDate: date(7)))
        context.insert(MovementBudgetAssignment(movementID: movementID, selection: .automatic))
        context.insert(BudgetNotificationRecord(bucket: .groceries, threshold: .approaching, weekStart: date(7, hour: 0)))
        try context.save()
    }

    static func migrateAndSavePlans(at url: URL, movementID: UUID) throws {
        let database = try container(at: url, includingPlans: true)
        let context = ModelContext(database)
        let movements = try context.fetch(FetchDescriptor<Movement>())
        let assignments = try context.fetch(FetchDescriptor<MovementBudgetAssignment>())
        try check(movements.count == 1 && movements[0].id == movementID && movements[0].amountInCents == 4_000,
                  "Adding the weekly plan model preserves existing movements")
        try check(movements[0].category?.name == "Transportes", "Migration preserves category relationships")
        try check(try context.fetchCount(FetchDescriptor<FinanceCategory>()) == 1, "The original category survives migration")
        try check(try context.fetchCount(FetchDescriptor<CategorizationRule>()) == 1, "Categorization rules survive migration")
        try check(try context.fetchCount(FetchDescriptor<RecurringRule>()) == 1, "Recurring rules survive migration")
        try check(try context.fetchCount(FetchDescriptor<RecurringOverride>()) == 1, "Recurring overrides survive migration")
        try check(try context.fetchCount(FetchDescriptor<BalanceSnapshot>()) == 1, "The balance snapshot survives migration")
        try check(try context.fetchCount(FetchDescriptor<BudgetNotificationRecord>()) == 1, "Sent notification history survives migration")
        try check(assignments.count == 1 && WeeklyBudgetService.bucket(for: movements[0], assignments: assignments) == .transport,
                  "Persisted automatic assignments still resolve correctly")
        try check(try context.fetchCount(FetchDescriptor<WeeklyBudgetPlan>()) == 0,
                  "Migration does not automatically confirm or invent a weekly limit")
        context.insert(plan(for: date(7)))
        context.insert(plan(for: date(14)))
        try context.save()
    }

    static func reopenAndEditPlan(at url: URL) throws {
        let database = try container(at: url, includingPlans: true)
        let context = ModelContext(database)
        let plans = try context.fetch(FetchDescriptor<WeeklyBudgetPlan>())
        guard let confirmed = plans.first(where: { $0.weekKey == "2026-09-07" }) else {
            throw CheckFailure(message: "The confirmed weekly plan was not persisted")
        }
        let movements = try context.fetch(FetchDescriptor<Movement>())
        let assignments = try context.fetch(FetchDescriptor<MovementBudgetAssignment>())
        let values = progress(on: 9, movements: movements, plan: confirmed, assignments: assignments)
        try check(confirmed.totalLimitInCents == 6_000 && confirmed.transportLimitInCents == 5_000,
                  "Independent total and category limits persist on disk")
        try check(values[1].spentInCents == 4_000 && values[1].remainingInCents == 1_000,
                  "The real service calculates progress from reopened SwiftData models")
        confirmed.totalLimitInCents = 8_000
        confirmed.transportLimitInCents = 7_000
        try context.save()
    }

    struct CheckFailure: Error, CustomStringConvertible {
        let message: String
        var description: String { message }
    }
}
