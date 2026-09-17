import Foundation
import SwiftData

// Compile alongside the real app models/services. All stores and values are synthetic.
@MainActor @main
struct SimulationServiceChecks {
    static var assertions = 0
    static let calendar: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Lisbon")!; return c }()
    static func main() throws {
        try liveBaseline(); try hypotheses(); try liveChanges(); try precreatedMovementsAndNewIntervals()
        try datesAndMissingSnapshot(); try weeklyGoalExpenseFilter(); try liveWeeklyGoalReassignment()
        try recurringWeeklyGoalFilter(); try persistence()
        print("SimulationService: \(assertions) assertions passed, including live projection, isolation, additive migration and disk roundtrip.")
    }
    static func check(_ condition: @autoclosure () throws -> Bool, _ message: String, line: UInt = #line) throws {
        guard try condition() else { throw Failure(message: "Line \(line): \(message)") }; assertions += 1
    }
    static func date(_ day: Int, month: Int = 9, hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }
    static func movement(_ amount: Int, _ day: Int, _ type: MovementType = .expense, created: Date? = nil,
                         confirmed: Bool = true, rule: RecurringRule? = nil, occurrence: Date? = nil) -> Movement {
        Movement(date: date(day), details: "Sintético \(day)", amountInCents: amount, type: type, category: nil,
                 isConfirmed: confirmed, sourceRecurringRuleID: rule?.id, occurrenceDate: occurrence, createdAt: created ?? date(6))
    }
    @MainActor struct Fixture {
        let snapshot = BalanceSnapshot(amountInCents: 100_000, referenceDate: date(7), createdAt: date(7))
        let weekly = RecurringRule(details: "Semanal", amountInCents: 1_000, type: .expense, frequency: .weekly, nextDueDate: date(8, hour: 0), category: nil)
        let monthly = RecurringRule(details: "Mensal", amountInCents: 10_000, type: .income, frequency: .monthly, nextDueDate: date(20), category: nil)
        let paused = RecurringRule(details: "Pausada", amountInCents: 99_900, type: .expense, frequency: .weekly, nextDueDate: date(8), category: nil, isActive: false)
        var rules: [RecurringRule] { [weekly, monthly, paused] }
        var movements: [Movement]
        let override: RecurringOverride
        init() {
            movements = [movement(50_000, 3, .income, created: date(3)), movement(10_000, 4, created: date(4)),
                         movement(5_000, 7, .income, created: date(7, hour: 13)), movement(2_000, 7, created: date(7, hour: 14)),
                         movement(20_000, 10, .income), movement(4_000, 11),
                         movement(90_000, 7, .income, created: date(7, hour: 13), confirmed: false), movement(90_000, 12, confirmed: false)]
            override = RecurringOverride(recurringRuleID: weekly.id, occurrenceDate: date(15, hour: 18), amountInCents: 1_500)
            movements.append(movement(1_200, 22, rule: weekly, occurrence: date(22, hour: 8)))
        }
        func result(_ edits: [SimulationAdjustment] = []) -> SimulationResult {
            SimulationService.result(snapshot: snapshot, movements: movements, recurringRules: rules, recurringOverrides: [override],
                                     adjustments: edits, through: date(30), asOf: date(7, hour: 16), calendar: calendar)
        }
    }
    static func finalBalance(_ result: SimulationResult, simulated: Bool = true) -> Int? {
        result.balance(on: date(30), simulated: simulated, calendar: calendar)
    }
    static func key(_ movement: Movement) -> String { SimulationService.sourceKey(for: movement, calendar: calendar) }
    static func liveBaseline() throws {
        let f = Fixture(), result = f.result()
        let movementsBefore = f.movements.map(signature), rulesBefore = f.rules.map(signature)
        try check(result.currentBalance == 103_000, "1000-euro snapshot includes only new 50 income and 20 expense, not old history")
        try check(result.balance(on: date(7), calendar: calendar) == 103_000, "History is not counted twice in today's balance")
        try check(result.baselineEntries.filter { $0.origin == .history }.count == 4, "All confirmed historical movements are visible")
        try check(result.baselineEntries.filter { $0.origin == .history && $0.type == .income }.count == 2, "Historical one-off income is included")
        try check(result.entries.first { $0.id == key(f.movements[4]) }?.origin == .scheduled, "Future one-off income is imported")
        try check(result.entries.first { $0.id == key(f.movements[5]) }?.origin == .scheduled, "Future one-off expenses are imported")
        try check(!result.entries.contains { $0.amountInCents == 90_000 }, "Unconfirmed historical or future entries do not count")
        try check(result.balance(on: date(6), calendar: calendar) == nil, "No invented historical bank balance")
        try check(result.balance(on: date(1, month: 10), calendar: calendar) == nil, "No balance outside the projection horizon")
        try check(finalBalance(result) == 124_300, "Baseline includes 47 euros weekly expenses and 100 euros monthly income")
        let forecast = BalanceService.monthEndForecast(snapshot: f.snapshot, movements: f.movements, recurringRules: f.rules,
            recurringOverrides: [f.override], asOf: date(7, hour: 16), calendar: calendar)
        try check(finalBalance(result) == forecast, "Baseline equals the existing month-end forecast without hypotheses")
        try check(result.entries.filter { $0.origin == .recurring }.count == 4, "Only active unmaterialized occurrences are projected")
        let overrideKey = SimulationService.sourceKey(ruleID: f.weekly.id, date: date(15), calendar: calendar)
        try check(result.entries.first { $0.id == overrideKey }?.amountInCents == 1_500, "Same-day real override is applied regardless of time")
        let materializedKey = SimulationService.sourceKey(ruleID: f.weekly.id, date: date(22), calendar: calendar)
        try check(result.entries.filter { $0.id == materializedKey }.count == 1, "Materialized occurrence is not projected twice")
        try check(result.entries.first { $0.id == materializedKey }?.amountInCents == 1_200, "Recorded occurrence retains its real amount")
        try check(!result.entries.contains { $0.details == "Pausada" }, "Paused recurring rule is excluded")
        _ = f.result()
        try check(f.movements.map(signature) == movementsBefore, "Projection never rewrites real movements")
        try check(f.rules.map(signature) == rulesBefore, "Projection never advances or rewrites real rules")
        try check(f.snapshot.amountInCents == 100_000 && f.snapshot.referenceDate == date(7), "Projection leaves the bank snapshot intact")
        try check(result.entries.map(\.id) == result.baselineEntries.map(\.id), "No hypotheses means the same entry identities in both projections")
    }
    static func hypotheses() throws {
        let f = Fixture()
        let edit = SimulationAdjustment(sourceKey: key(f.movements[4]), date: date(10), details: "Ganho alterado", amountInCents: 30_000, type: .income, updatedAt: date(7))
        let excluded = SimulationAdjustment(sourceKey: key(f.movements[5]), date: date(11), details: "Despesa excluída", amountInCents: 4_000, type: .expense, isExcluded: true)
        let expense = SimulationAdjustment(date: date(13), details: "Compra hipotética", amountInCents: 2_500, type: .expense)
        let income = SimulationAdjustment(date: date(14), details: "Ganho hipotético", amountInCents: 1_000, type: .income)
        let old = SimulationAdjustment(sourceKey: key(f.movements[0]), date: date(3), details: "Histórico", amountInCents: 999_999, type: .expense)
        let zero = SimulationAdjustment(date: date(16), details: "Inválido", amountInCents: 0, type: .expense)
        let before = f.movements.map(signature)
        let result = f.result([edit, excluded, expense, income, old, zero])
        try check(finalBalance(result) == 136_800, "Hypothetical gains, expenses, edits and exclusions combine correctly")
        try check(finalBalance(result, simulated: false) == 124_300, "Baseline retains original real amounts")
        try check(result.currentBalance == 103_000, "Hypotheses never change today's bank balance")
        try check(result.entries.first { $0.id == edit.sourceKey }?.origin == .adjusted, "Edited entry is marked as a simulation-only adjustment")
        try check(result.entries.first { $0.id == excluded.sourceKey }?.isExcluded == true, "Excluded entry stays explainable without affecting balance")
        try check(result.entries.filter { $0.origin == .hypothesis }.count == 2, "Only positive valid hypotheses are included")
        try check(result.entries.first { $0.id == old.sourceKey }?.amountInCents == 50_000, "History cannot be hypothetically rewritten")
        try check(result.inactiveAdjustmentCount == 1, "Obsolete historical edit is counted as inactive")
        try check(f.movements.map(signature) == before, "Editing and excluding base entries do not mutate movements")
        try check(finalBalance(f.result()) == 124_300, "Removing all hypotheses restores the live baseline")
        let previous = SimulationAdjustment(sourceKey: edit.sourceKey, date: date(10), details: "Anterior", amountInCents: 99_000, type: .income, updatedAt: date(5))
        let duplicate = f.result([edit, previous])
        try check(duplicate.entries.first { $0.id == edit.sourceKey }?.amountInCents == 30_000, "Latest source edit wins regardless of array order")
        try check(duplicate.entries.filter { $0.id == edit.sourceKey }.count == 1, "Duplicate stored edits do not duplicate an occurrence")
    }
    static func liveChanges() throws {
        var f = Fixture()
        let source = SimulationService.sourceKey(ruleID: f.weekly.id, date: date(8), calendar: calendar)
        let edit = SimulationAdjustment(sourceKey: source, date: date(8), details: "Hipótese recorrente", amountInCents: 2_000, type: .expense)
        try check(finalBalance(f.result([edit])) == 123_300, "Recurring entries support simulation-only edits")
        f.movements.append(movement(500, 7, created: date(7, hour: 15)))
        let refreshed = f.result([edit])
        try check(refreshed.currentBalance == 102_500, "New actual expense refreshes current balance")
        try check(finalBalance(refreshed) == 122_800, "Refreshing actual data preserves the hypothesis")
        f.movements.append(movement(700, 8, rule: f.weekly, occurrence: date(8, hour: 18)))
        let materialized = f.result([edit])
        try check(materialized.entries.filter { $0.id == source }.count == 1, "Materialization does not duplicate an edited source")
        try check(materialized.entries.first { $0.id == source }?.amountInCents == 2_000, "Stable source key survives materialization")
        try check(materialized.baselineEntries.first { $0.id == source }?.amountInCents == 700, "Baseline picks up the new actual occurrence amount")
        f.weekly.nextDueDate = date(15, hour: 0)
        try check(finalBalance(f.result([edit])) == finalBalance(materialized), "Advancing the real nextDueDate does not lose the hypothetical edit")
        f.weekly.isActive = false
        let paused = f.result([edit])
        try check(!paused.entries.contains { $0.origin == .recurring && $0.type == .expense }, "Pausing live rule removes its projected expenses")
        try check(paused.entries.contains { $0.id == source }, "Pausing does not erase a recorded real occurrence")
        try check(edit.amountInCents == 2_000 && edit.sourceKey == source, "Live refresh never rewrites stored hypothetical data")
        let oneOff = f.movements[4]
        let rescheduledEdit = SimulationAdjustment(sourceKey: key(oneOff), date: date(6),
            details: "Reagendado", amountInCents: 30_000, type: .income)
        let rescheduled = f.result([rescheduledEdit])
        try check(rescheduled.inactiveAdjustmentCount == 0, "A rescheduled future movement's live date keeps its edit active")
        try check(rescheduled.entries.first { $0.id == key(oneOff) }?.amountInCents == 30_000,
            "A rescheduled movement retains its hypothetical amount")
        oneOff.date = date(5)
        let pastAgain = f.result([rescheduledEdit])
        try check(pastAgain.inactiveAdjustmentCount == 1 && pastAgain.entries.first { $0.id == key(oneOff) }?.origin == .history,
            "Moving the source to the past makes the edit inactive and preserves real history")
    }
    static func precreatedMovementsAndNewIntervals() throws {
        let original = BalanceSnapshot(amountInCents: 100_000, referenceDate: date(7))
        let income = movement(20_000, 10, .income, created: date(6))
        let expense = movement(4_000, 11, created: date(6))
        func projection(_ day: Int, snapshot: BalanceSnapshot) -> SimulationResult {
            SimulationService.result(snapshot: snapshot, movements: [income, expense], recurringRules: [], recurringOverrides: [],
                adjustments: [], through: date(30), asOf: date(day), calendar: calendar)
        }
        let before = projection(9, snapshot: original)
        let incomeDay = projection(10, snapshot: original)
        let expenseDay = projection(11, snapshot: original)
        try check(before.currentBalance == 100_000 && finalBalance(before) == 116_000, "Precreated future movements affect the projection, not today's bank balance")
        try check(incomeDay.currentBalance == 120_000 && finalBalance(incomeDay) == 116_000, "Precreated income moves from projection to real balance without a discontinuity")
        try check(expenseDay.currentBalance == 116_000 && finalBalance(expenseDay) == 116_000, "Precreated expense moves to real balance exactly once when its date arrives")
        try check(expenseDay.entries.allSatisfy { $0.origin == .history }, "Reached movements become actual history rather than future forecasts")
        let reset = BalanceSnapshot(amountInCents: 200_000, referenceDate: date(12))
        try check(projection(12, snapshot: reset).currentBalance == 200_000, "A newer bank snapshot absorbs past movements instead of replaying them")
        try check(finalBalance(projection(12, snapshot: reset)) == 200_000, "Resetting the snapshot keeps the end projection free of historical duplication")
        let biweekly = RecurringRule(details: "Quinzenal", amountInCents: 1_000, type: .expense,
            frequency: .everyTwoWeeks, nextDueDate: date(8), category: nil)
        let triweekly = RecurringRule(details: "Três semanas", amountInCents: 5_000, type: .income,
            frequency: .everyThreeWeeks, nextDueDate: date(8), category: nil)
        let result = SimulationService.result(snapshot: original, movements: [], recurringRules: [biweekly, triweekly],
            recurringOverrides: [], adjustments: [], through: date(30), asOf: date(7), calendar: calendar)
        let twoDates = result.entries.filter { $0.details == biweekly.details }.map { calendar.component(.day, from: $0.date) }
        let threeDates = result.entries.filter { $0.details == triweekly.details }.map { calendar.component(.day, from: $0.date) }
        try check(twoDates == [8, 22], "Simulator automatically imports recurrence every two weeks")
        try check(threeDates == [8, 29], "Simulator automatically imports recurrence every three weeks")
        try check(finalBalance(result) == 108_000, "New recurrence intervals preserve exact financial sums")
        let existing = BalanceService.monthEndForecast(snapshot: original, movements: [], recurringRules: [biweekly, triweekly],
            recurringOverrides: [], asOf: date(7), calendar: calendar)
        try check(finalBalance(result) == existing, "Simulator and real month-end forecast agree for new recurrence intervals")
    }
    static func datesAndMissingSnapshot() throws {
        let snapshot = BalanceSnapshot(amountInCents: 100_000, referenceDate: date(7))
        let tomorrow = SimulationAdjustment(date: date(8, hour: 23), details: "Amanhã", amountInCents: 1_000, type: .expense)
        let later = SimulationAdjustment(date: date(9), details: "Depois", amountInCents: 2_000, type: .income)
        func result(_ day: Int, snapshot: BalanceSnapshot?) -> SimulationResult {
            SimulationService.result(snapshot: snapshot, movements: [], recurringRules: [], recurringOverrides: [],
                adjustments: [tomorrow, later], through: date(30), asOf: date(day, hour: 0), calendar: calendar)
        }
        try check(finalBalance(result(7, snapshot: snapshot)) == 101_000, "Tomorrow's hypothesis is applied to the future")
        let nextDay = result(8, snapshot: snapshot)
        try check(finalBalance(nextDay) == 102_000, "A hypothetical expense never becomes actual when its date arrives")
        try check(nextDay.inactiveAdjustmentCount == 1 && nextDay.entries.count == 1, "Past/current-day hypothesis becomes inactive even if its time is later")
        try check(tomorrow.date == date(8, hour: 23), "Rollover does not silently delete or reschedule a hypothesis")
        let missing = result(7, snapshot: nil)
        try check(missing.currentBalance == nil && finalBalance(missing) == nil, "Missing snapshot does not invent a bank balance")
        try check(missing.entries.count == 2, "Hypotheses remain inspectable without a starting balance")
        let lastMinute = movement(1_000, 30, .income); lastMinute.date = date(30, hour: 23, minute: 59)
        let nextMonth = movement(9_000, 1); nextMonth.date = date(1, month: 10, hour: 0)
        let september = SimulationService.result(snapshot: snapshot, movements: [lastMinute, nextMonth], recurringRules: [], recurringOverrides: [],
            adjustments: [], through: date(30, hour: 0), asOf: date(7), calendar: calendar)
        try check(september.entries.count == 1 && finalBalance(september) == 101_000, "Final-day last minute is included; next-month midnight is excluded")
        try check(september.through == date(30, hour: 0), "Horizon is normalized to local day")
        let autumnRule = RecurringRule(details: "Mudança de hora", amountInCents: 1_000, type: .expense, frequency: .weekly,
            nextDueDate: date(24, month: 10, hour: 9), category: nil)
        let october = SimulationService.result(snapshot: snapshot, movements: [], recurringRules: [autumnRule], recurringOverrides: [],
            adjustments: [], through: date(31, month: 10), asOf: date(23, month: 10), calendar: calendar)
        try check(october.entries.count == 2 && october.balance(on: date(31, month: 10), calendar: calendar) == 98_000, "Weekly dates survive autumn DST through month-end")
        try check(october.entries.allSatisfy { calendar.component(.hour, from: $0.date) == 9 }, "Recurring times retain local hour across DST")
        try check(october.entries[1].date.timeIntervalSince(october.entries[0].date) == 169 * 3_600, "Weekly projection uses calendar days, not fixed 168-hour seconds")
        try check(calendar.dateInterval(of: .day, for: date(25, month: 10))!.duration == 25 * 3_600, "Autumn fixture covers the 25-hour day")
        try check(calendar.dateInterval(of: .day, for: date(29, month: 3))!.duration == 23 * 3_600, "Spring fixture covers the 23-hour day")
        let springIncome = movement(2_000, 29, .income, created: date(1, month: 3)); springIncome.date = date(29, month: 3, hour: 23, minute: 59)
        let spring = SimulationService.result(snapshot: snapshot, movements: [springIncome], recurringRules: [], recurringOverrides: [],
            adjustments: [], through: date(29, month: 3), asOf: date(28, month: 3), calendar: calendar)
        try check(spring.balance(on: date(29, month: 3), calendar: calendar) == 102_000, "Short DST day's last minute is included")
        try check(SimulationService.sourceKey(ruleID: autumnRule.id, date: date(25, month: 10, hour: 0), calendar: calendar)
            == SimulationService.sourceKey(ruleID: autumnRule.id, date: date(25, month: 10, hour: 23), calendar: calendar), "Recurring identity uses local date across DST")
    }
    static func weeklyGoalExpenseFilter() throws {
        let snapshot = BalanceSnapshot(amountInCents: 100_000, referenceDate: date(7))
        func categorized(_ cents: Int, _ day: Int, _ name: String?, _ type: MovementType = .expense, created: Date? = nil) -> Movement {
            let value = movement(cents, day, type, created: created)
            value.category = name.map { FinanceCategory(name: $0) }
            return value
        }
        let groceriesPast = categorized(100, 6, "Alimentação")
        let transportToday = categorized(200, 7, "tRANsPOrtes", created: date(7, hour: 13))
        let leisureFuture = categorized(300, 9, "Lazer")
        let unrelatedPast = categorized(50, 6, "Habitação")
        let unrelatedFuture = categorized(400, 9, "Habitação")
        let incomeToday = categorized(500, 7, "Lazer", .income, created: date(7, hour: 14))
        let incomeFuture = categorized(600, 9, "Alimentação", .income)
        let manualDifferent = categorized(700, 10, "Saúde")
        let manualUncategorized = categorized(800, 11, nil)
        let explicitlyOutsideGoals = categorized(900, 12, "Alimentação")
        let explicitAutomatic = categorized(1_000, 13, "Transportes")
        let unrelatedAutomatic = categorized(1_100, 14, "Habitação")
        let manualPast = categorized(50, 5, nil)
        let movements = [groceriesPast, transportToday, leisureFuture, unrelatedPast, unrelatedFuture, incomeToday,
            incomeFuture, manualDifferent, manualUncategorized, explicitlyOutsideGoals, explicitAutomatic, unrelatedAutomatic, manualPast]
        let assignments = [MovementBudgetAssignment(movementID: manualDifferent.id, selection: .transport),
            MovementBudgetAssignment(movementID: manualUncategorized.id, selection: .groceries),
            MovementBudgetAssignment(movementID: explicitlyOutsideGoals.id, selection: .excluded),
            MovementBudgetAssignment(movementID: explicitAutomatic.id, selection: .automatic),
            MovementBudgetAssignment(movementID: unrelatedAutomatic.id, selection: .automatic),
            MovementBudgetAssignment(movementID: manualPast.id, selection: .leisure),
            MovementBudgetAssignment(movementID: incomeFuture.id, selection: .leisure)]
        let movementBefore = movements.map(signature), categoryBefore = movements.map { $0.category?.name }
        let assignmentsBefore = assignments.map { "\($0.movementID)|\($0.selectionRawValue)|\($0.updatedAt)" }
        let homeBefore = BalanceService.monthEndForecast(snapshot: snapshot, movements: movements, recurringRules: [],
            recurringOverrides: [], asOf: date(7, hour: 16), calendar: calendar)
        let weekCalendar = WeeklyBudgetService.calendar(timeZone: calendar.timeZone)
        let progressBefore = WeeklyBudgetService.progress(for: date(7), movements: movements, assignments: assignments,
            asOf: date(7, hour: 16), calendar: weekCalendar)
        let result = SimulationService.result(snapshot: snapshot, movements: movements, recurringRules: [], recurringOverrides: [],
            budgetAssignments: assignments, adjustments: [], through: date(30), asOf: date(7, hour: 16), calendar: calendar)
        try check(!result.entries.contains { $0.id == key(groceriesPast) }, "Automatic Alimentação expense is absent from simulated history")
        try check(!result.entries.contains { $0.id == key(transportToday) }, "Automatic Transportes expense is absent even on today's date")
        try check(!result.entries.contains { $0.id == key(leisureFuture) }, "Automatic Lazer expense is absent from future projection")
        try check(!result.entries.contains { $0.id == key(manualDifferent) }, "Manual weekly mapping excludes an expense in another category")
        try check(!result.entries.contains { $0.id == key(manualUncategorized) }, "Manual weekly mapping excludes an uncategorized expense")
        try check(!result.entries.contains { $0.id == key(manualPast) }, "Manual weekly mapping excludes historical expenses too")
        try check(result.entries.contains { $0.id == key(explicitlyOutsideGoals) }, "Explicitly excluded from weekly goals overrides automatic category and remains in simulator")
        try check(!result.entries.contains { $0.id == key(explicitAutomatic) }, "An explicit automatic selection still follows the weekly category")
        try check(result.entries.contains { $0.id == key(unrelatedAutomatic) }, "Automatic selection without a recognized weekly category stays in simulation")
        try check(result.entries.contains { $0.id == key(unrelatedPast) } && result.entries.contains { $0.id == key(unrelatedFuture) }, "Unrelated expenses remain in history and projection")
        try check(result.entries.contains { $0.id == key(incomeToday) } && result.entries.contains { $0.id == key(incomeFuture) }, "Income is retained even with weekly category or manual goal assignment")
        try check(result.entries.count == 6 && result.baselineEntries.count == 6, "Both simulation and baseline omit exactly the goal-associated expenses")
        try check(result.currentBalance == 100_300, "Hidden goal expense still subtracts from the REAL bank balance alongside actual income")
        try check(result.currentBalance == BalanceService.currentBalance(snapshot: snapshot, movements: movements, asOf: date(7, hour: 16), calendar: calendar), "Filtering cannot rewrite today's real starting balance")
        try check(finalBalance(result) == 98_500 && finalBalance(result, simulated: false) == 98_500, "Associated future expenses have no simulator effect")
        try check(homeBefore == 95_700 && BalanceService.monthEndForecast(snapshot: snapshot, movements: movements,
            recurringRules: [], recurringOverrides: [], asOf: date(7, hour: 16), calendar: calendar) == homeBefore,
            "Home forecast remains unchanged and still includes actual future weekly-goal expenses")
        let progressAfter = WeeklyBudgetService.progress(for: date(7), movements: movements, assignments: assignments,
            asOf: date(7, hour: 16), calendar: weekCalendar)
        try check(progressBefore.map(\.spentInCents) == progressAfter.map(\.spentInCents) && progressAfter.reduce(0) { $0 + $1.spentInCents } == 200,
            "Weekly progress retains today's real goal spending")
        try check(progressAfter.allSatisfy { $0.limitInCents == nil }, "Simulator filtering works even without a confirmed weekly plan")
        try check(movements.map(signature) == movementBefore && movements.map { $0.category?.name } == categoryBefore,
            "Filtering never changes movements, category relationships or amounts")
        try check(assignments.map { "\($0.movementID)|\($0.selectionRawValue)|\($0.updatedAt)" } == assignmentsBefore,
            "Filtering never rewrites manual goal mappings")
        try check(snapshot.amountInCents == 100_000 && snapshot.referenceDate == date(7), "Filtering leaves the real snapshot unchanged")
    }
    static func liveWeeklyGoalReassignment() throws {
        let snapshot = BalanceSnapshot(amountInCents: 100_000, referenceDate: date(7))
        let purchase = movement(500, 9)
        let assignment = MovementBudgetAssignment(movementID: purchase.id, selection: .automatic)
        let linked = SimulationAdjustment(sourceKey: key(purchase), date: date(9), details: "Alteração ligada", amountInCents: 2_000, type: .expense)
        let standalone = SimulationAdjustment(date: date(10), details: "Hipótese livre", amountInCents: 1_000, type: .expense)
        func result() -> SimulationResult {
            SimulationService.result(snapshot: snapshot, movements: [purchase], recurringRules: [], recurringOverrides: [],
                budgetAssignments: [assignment], adjustments: [linked, standalone], through: date(30), asOf: date(7), calendar: calendar)
        }
        try check(finalBalance(result()) == 97_000 && result().entries.count == 2, "Unassociated source retains its linked hypothetical edit and standalone expense")
        assignment.selection = .leisure
        let associated = result()
        try check(!associated.entries.contains { $0.id == key(purchase) } && associated.baselineEntries.isEmpty, "Live manual reassignment removes the source and its linked edit")
        try check(finalBalance(associated) == 99_000 && associated.entries.count == 1 && associated.entries[0].origin == .hypothesis,
            "Standalone hypotheses remain after filtering associated real sources")
        assignment.selection = .excluded
        try check(finalBalance(result()) == 97_000 && result().entries.first { $0.id == key(purchase) }?.amountInCents == 2_000,
            "Removing weekly association restores the source together with its saved hypothetical edit")
        assignment.selection = .automatic
        purchase.category = FinanceCategory(name: "Lazer")
        try check(!result().entries.contains { $0.id == key(purchase) }, "Live category change into a weekly goal removes the source")
        purchase.category?.name = "Habitação"
        try check(result().entries.contains { $0.id == key(purchase) }, "Renaming out of a goal category restores the source")
        purchase.category?.name = "Alimentação"
        assignment.selection = .excluded
        try check(result().entries.contains { $0.id == key(purchase) }, "Explicit outside-goals association wins over a later goal category rename")
        assignment.selection = .automatic
        purchase.type = .income
        try check(result().entries.contains { $0.id == key(purchase) }, "Changing a mapped real movement to income bypasses the expense-only filter")
        try check(linked.sourceKey == key(purchase) && linked.amountInCents == 2_000 && standalone.amountInCents == 1_000,
            "Filtering and restoring sources do not destroy or rewrite hypothetical records")
    }
    static func recurringWeeklyGoalFilter() throws {
        let snapshot = BalanceSnapshot(amountInCents: 100_000, referenceDate: date(7))
        var rules: [RecurringRule] = ["Alimentação", "Transportes", "Lazer"].map { name in
            RecurringRule(details: "Recorrência \(name)", amountInCents: 1_000, type: .expense, frequency: .monthly,
                nextDueDate: date(9), category: FinanceCategory(name: name))
        }
        let income = RecurringRule(details: "Rendimento na categoria", amountInCents: 5_000, type: .income, frequency: .monthly,
            nextDueDate: date(10), category: FinanceCategory(name: "Alimentação"))
        let unrelated = RecurringRule(details: "Recorrência fora dos objetivos", amountInCents: 700, type: .expense, frequency: .monthly,
            nextDueDate: date(11), category: FinanceCategory(name: "Habitação"))
        rules += [income, unrelated]
        let before = rules.map(signature), categoriesBefore = rules.map { $0.category?.name }
        let recurringEdit = SimulationAdjustment(sourceKey: SimulationService.sourceKey(ruleID: rules[0].id, date: date(9), calendar: calendar),
            date: date(9), details: "Hipótese ligada ao objetivo", amountInCents: 9_000, type: .expense)
        func result(_ movements: [Movement] = [], _ assignments: [MovementBudgetAssignment] = []) -> SimulationResult {
            SimulationService.result(snapshot: snapshot, movements: movements, recurringRules: rules, recurringOverrides: [],
                budgetAssignments: assignments, adjustments: [recurringEdit], through: date(30), asOf: date(7), calendar: calendar)
        }
        let projected = result()
        try check(projected.entries.count == 2 && projected.entries.allSatisfy { $0.details == income.details || $0.details == unrelated.details },
            "All three goal-category recurring expenses disappear while income and unrelated expense remain")
        try check(finalBalance(projected) == 104_300, "Filtered recurring expense and its hypothetical override never affect future balance")
        try check(projected.entries.allSatisfy { $0.origin == .recurring }, "A linked edit cannot reintroduce its filtered recurring source")
        let actualGoal = movement(600, 9, rule: rules[0], occurrence: date(9, hour: 18)); actualGoal.category = rules[0].category
        let outside = MovementBudgetAssignment(movementID: actualGoal.id, selection: .excluded)
        let materializedKept = result([actualGoal], [outside])
        try check(materializedKept.baselineEntries.first { $0.id == key(actualGoal) }?.amountInCents == 600,
            "Explicit outside-goals assignment on an actual occurrence wins over the goal category of its source rule")
        try check(materializedKept.entries.filter { $0.id == key(actualGoal) }.count == 1,
            "Retained actual occurrence is not duplicated by its filtered recurring source")
        outside.selection = .automatic
        try check(!result([actualGoal], [outside]).entries.contains { $0.id == key(actualGoal) },
            "Restoring automatic association removes the materialized goal occurrence")
        let actualUnrelated = movement(400, 11, rule: unrelated, occurrence: date(11, hour: 18)); actualUnrelated.category = unrelated.category
        let mapped = MovementBudgetAssignment(movementID: actualUnrelated.id, selection: .transport)
        let filteredMaterialized = result([actualUnrelated], [mapped])
        try check(!filteredMaterialized.entries.contains { $0.id == key(actualUnrelated) },
            "A manually assigned actual occurrence cannot reappear as an unmaterialized unrelated recurring expense")
        try check(filteredMaterialized.entries.count == 1 && finalBalance(filteredMaterialized) == 105_000,
            "Recurrence deduplication uses all real movements before filtering")
        mapped.selection = .excluded
        try check(result([actualUnrelated], [mapped]).baselineEntries.first { $0.id == key(actualUnrelated) }?.amountInCents == 400,
            "Removing a materialized occurrence's goal assignment restores its actual amount, not the rule amount")
        try check(rules.map(signature) == before && rules.map { $0.category?.name } == categoriesBefore,
            "Filtering recurring projections never mutates their rules or categories")
        try check(actualUnrelated.amountInCents == 400 && actualGoal.amountInCents == 600,
            "Changing only simulator filtering never edits materialized amounts")
    }
    static func schema(_ includingSimulation: Bool) -> Schema {
        var types: [any PersistentModel.Type] = [FinanceCategory.self, Movement.self, CategorizationRule.self, RecurringRule.self,
            RecurringOverride.self, BalanceSnapshot.self, MovementBudgetAssignment.self, BudgetNotificationRecord.self, WeeklyBudgetPlan.self]
        if includingSimulation { types.append(SimulationAdjustment.self) }; return Schema(types)
    }
    static func container(_ url: URL, _ includingSimulation: Bool) throws -> ModelContainer {
        let value = schema(includingSimulation)
        return try ModelContainer(for: value, configurations: [ModelConfiguration(schema: value, url: url, cloudKitDatabase: .none)])
    }
    static func persistence() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("simulation-checks-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = directory.appendingPathComponent("simulation.store"), movementID = UUID(), hypothesisID = UUID()
        try autoreleasepool { try seed(store, movementID) }
        try autoreleasepool { try migrate(store, movementID, hypothesisID) }
        try autoreleasepool { try reopen(store, hypothesisID) }
        try autoreleasepool {
            let database = try container(store, true), context = ModelContext(database)
            let edits = try context.fetch(FetchDescriptor<SimulationAdjustment>())
            try check(edits.count == 1 && edits[0].amountInCents == 4_000 && edits[0].isExcluded, "Amount edits and exclusions survive a second reopening")
            context.delete(edits[0]); try context.save()
        }
        try autoreleasepool {
            let database = try container(store, true), context = ModelContext(database)
            try check(try context.fetchCount(FetchDescriptor<SimulationAdjustment>()) == 0, "Restoring all hypotheses persists their deletion")
            let movements = try context.fetch(FetchDescriptor<Movement>())
            try check(movements.count == 1 && movements[0].id == movementID && movements[0].amountInCents == 700, "Deleting hypotheses never deletes or alters actual movements")
            try check(try context.fetch(FetchDescriptor<BalanceSnapshot>())[0].amountInCents == 100_000, "Bank snapshot survives all migrations and hypothetical writes")
        }
    }
    static func seed(_ url: URL, _ movementID: UUID) throws {
        let database = try container(url, false), context = ModelContext(database)
        let category = FinanceCategory(name: "Lazer")
        let purchase = Movement(id: movementID, date: date(9), details: "Original", amountInCents: 700, type: .expense, category: category, createdAt: date(6))
        let rule = RecurringRule(details: "Regra original", amountInCents: 900, type: .expense, frequency: .weekly, nextDueDate: date(14), category: category)
        context.insert(category); context.insert(purchase); context.insert(rule)
        context.insert(CategorizationRule(keyword: "original", category: category))
        context.insert(RecurringOverride(recurringRuleID: rule.id, occurrenceDate: date(14), amountInCents: 800))
        context.insert(BalanceSnapshot(amountInCents: 100_000, referenceDate: date(7)))
        context.insert(MovementBudgetAssignment(movementID: purchase.id, selection: .leisure))
        context.insert(BudgetNotificationRecord(bucket: .leisure, threshold: .approaching, weekStart: date(7)))
        context.insert(WeeklyBudgetPlan(weekKey: "2026-09-07", weekStart: date(7, hour: 0), totalLimitInCents: 9_000,
            groceriesLimitInCents: 3_000, transportLimitInCents: 3_000, leisureLimitInCents: 3_000))
        try context.save()
    }
    static func migrate(_ url: URL, _ movementID: UUID, _ hypothesisID: UUID) throws {
        let database = try container(url, true), context = ModelContext(database)
        let movements = try context.fetch(FetchDescriptor<Movement>())
        try check(movements.count == 1 && movements[0].id == movementID, "Tenth additive model preserves existing movement identity")
        try check(movements[0].category?.name == "Lazer", "Migration retains category relationships")
        try check(try context.fetchCount(FetchDescriptor<FinanceCategory>()) == 1, "Categories survive migration")
        try check(try context.fetchCount(FetchDescriptor<CategorizationRule>()) == 1, "Categorization rules survive migration")
        try check(try context.fetchCount(FetchDescriptor<RecurringRule>()) == 1, "Recurring rules survive migration")
        try check(try context.fetchCount(FetchDescriptor<RecurringOverride>()) == 1, "Recurring overrides survive migration")
        try check(try context.fetchCount(FetchDescriptor<BalanceSnapshot>()) == 1, "Bank snapshots survive migration")
        try check(try context.fetchCount(FetchDescriptor<MovementBudgetAssignment>()) == 1, "Weekly associations survive migration")
        try check(try context.fetchCount(FetchDescriptor<BudgetNotificationRecord>()) == 1, "Alert history survives migration")
        try check(try context.fetchCount(FetchDescriptor<WeeklyBudgetPlan>()) == 1, "Weekly plans survive migration")
        try check(try context.fetchCount(FetchDescriptor<SimulationAdjustment>()) == 0, "Migration invents no hypotheses")
        let rules = try context.fetch(FetchDescriptor<RecurringRule>()), rulesBefore = rules.map(signature), before = movements.map(signature)
        let result = SimulationService.result(snapshot: try context.fetch(FetchDescriptor<BalanceSnapshot>()).first, movements: movements,
            recurringRules: rules, recurringOverrides: try context.fetch(FetchDescriptor<RecurringOverride>()),
            budgetAssignments: try context.fetch(FetchDescriptor<MovementBudgetAssignment>()), adjustments: [],
            through: date(30), asOf: date(7), calendar: calendar)
        try check(finalBalance(result) == 100_000 && result.entries.isEmpty, "Migrated goal expenses and recurring rules remain stored but are excluded from simulation")
        try check(BalanceService.monthEndForecast(snapshot: try context.fetch(FetchDescriptor<BalanceSnapshot>()).first,
            movements: movements, recurringRules: rules, recurringOverrides: try context.fetch(FetchDescriptor<RecurringOverride>()),
            asOf: date(7), calendar: calendar) == 96_700, "Migrated goal expenses still affect the real Home forecast")
        try check(!context.hasChanges && movements.map(signature) == before && rules.map(signature) == rulesBefore, "Real persisted data remains completely read-only during projection")
        context.insert(SimulationAdjustment(id: hypothesisID, sourceKey: key(movements[0]), date: date(9), details: "Só simulação",
                                           amountInCents: 2_000, type: .expense, updatedAt: date(7))); try context.save()
    }
    static func reopen(_ url: URL, _ hypothesisID: UUID) throws {
        let database = try container(url, true), context = ModelContext(database)
        let edits = try context.fetch(FetchDescriptor<SimulationAdjustment>()), movements = try context.fetch(FetchDescriptor<Movement>())
        guard let edit = edits.first else { throw Failure(message: "Hypothesis missing after reopening") }
        try check(edits.count == 1 && edit.id == hypothesisID && edit.amountInCents == 2_000, "Hypothesis survives reopening with stable identity")
        try check(edit.sourceKey == key(movements[0]), "Saved source keys reconnect to the actual entry")
        let result = SimulationService.result(snapshot: try context.fetch(FetchDescriptor<BalanceSnapshot>()).first, movements: movements,
            recurringRules: try context.fetch(FetchDescriptor<RecurringRule>()), recurringOverrides: try context.fetch(FetchDescriptor<RecurringOverride>()),
            budgetAssignments: try context.fetch(FetchDescriptor<MovementBudgetAssignment>()), adjustments: edits,
            through: date(30), asOf: date(7), calendar: calendar)
        try check(finalBalance(result) == 100_000 && result.entries.isEmpty, "Reopened edit linked to a weekly-goal source stays saved but has no projected effect")
        try check(finalBalance(result, simulated: false) == 100_000, "Reopened baseline also filters the weekly-goal source")
        try check(!context.hasChanges, "Reopened projection does not create writes")
        let outside = MovementBudgetAssignment(movementID: movements[0].id, selection: .excluded)
        let restored = SimulationService.result(snapshot: try context.fetch(FetchDescriptor<BalanceSnapshot>()).first, movements: movements,
            recurringRules: try context.fetch(FetchDescriptor<RecurringRule>()), recurringOverrides: try context.fetch(FetchDescriptor<RecurringOverride>()),
            budgetAssignments: [outside], adjustments: edits, through: date(30), asOf: date(7), calendar: calendar)
        try check(finalBalance(restored) == 98_000 && finalBalance(restored, simulated: false) == 99_300,
            "A persisted hypothetical edit becomes active again when its source no longer belongs to a weekly goal")
        try check(!context.hasChanges && (try context.fetch(FetchDescriptor<MovementBudgetAssignment>()))[0].selection == .leisure,
            "Inspecting a restored projection never changes the persisted weekly association")
        edit.amountInCents = 4_000; edit.isExcluded = true; try context.save()
    }
    static func signature(_ value: Movement) -> String {
        "\(value.id)|\(value.date)|\(value.details)|\(value.amountInCents)|\(value.typeRawValue)|\(value.isConfirmed)|\(value.createdAt)|\(String(describing: value.sourceRecurringRuleID))|\(String(describing: value.occurrenceDate))"
    }
    static func signature(_ value: RecurringRule) -> String {
        "\(value.id)|\(value.details)|\(value.amountInCents)|\(value.frequencyRawValue)|\(value.nextDueDate)|\(value.isActive)|\(value.typeRawValue)"
    }
    struct Failure: Error, CustomStringConvertible { let message: String; var description: String { message } }
}
