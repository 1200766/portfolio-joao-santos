import Foundation

enum SimulationOrigin: String {
    case history = "Real"
    case scheduled = "Registado para o futuro"
    case recurring = "Recorrente previsto"
    case hypothesis = "Hipótese"
    case adjusted = "Alterado só na simulação"
}

struct SimulationEntry: Identifiable {
    let id: String
    let date: Date
    let details: String
    let amountInCents: Int
    let type: MovementType
    let origin: SimulationOrigin
    let isExcluded: Bool
    let adjustmentID: UUID?

    var signedAmount: Int { type == .income ? amountInCents : -amountInCents }
}

struct SimulationResult {
    let today: Date
    let through: Date
    let currentBalance: Int?
    let baselineEntries: [SimulationEntry]
    let entries: [SimulationEntry]
    let inactiveAdjustmentCount: Int

    /// Past entries are displayed as history, never replayed against today's bank balance.
    func balance(on date: Date, simulated: Bool = true, calendar: Calendar = .current) -> Int? {
        let day = calendar.startOfDay(for: date)
        guard day >= today, day <= through, let currentBalance else { return nil }
        return (simulated ? entries : baselineEntries).reduce(currentBalance) { balance, entry in
            let entryDay = calendar.startOfDay(for: entry.date)
            guard entryDay > today, entryDay <= day, !entry.isExcluded else { return balance }
            return balance + entry.signedAmount
        }
    }
}

@MainActor
enum SimulationService {
    /// Read-only live projection. No context, inserts, recurring materialization or notification side effects.
    static func result(
        snapshot: BalanceSnapshot?, movements: [Movement],
        recurringRules: [RecurringRule], recurringOverrides: [RecurringOverride],
        budgetAssignments: [MovementBudgetAssignment] = [],
        adjustments: [SimulationAdjustment], through date: Date,
        asOf now: Date = .now, calendar: Calendar = .current
    ) -> SimulationResult {
        let today = calendar.startOfDay(for: now)
        let through = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: through) ?? through
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let currentBalance = BalanceService.currentBalance(
            snapshot: snapshot, movements: movements, asOf: now, calendar: calendar
        )

        // Keep every real movement in today's bank balance above. Only the simulator's
        // visible history and future entries omit expenses associated with weekly goals.
        // Use the same resolver as Semana, including explicit opt-outs and manual mappings.
        var baseline = movements.filter {
            $0.isConfirmed && $0.date < end &&
            !($0.type == .expense && WeeklyBudgetService.bucket(for: $0, assignments: budgetAssignments) != nil)
        }.map { movement in
            SimulationEntry(
                id: sourceKey(for: movement, calendar: calendar), date: movement.date,
                details: movement.details, amountInCents: movement.amountInCents,
                type: movement.type,
                origin: calendar.startOfDay(for: movement.date) <= today ? .history : .scheduled,
                isExcluded: false, adjustmentID: nil
            )
        }
        if end > tomorrow {
            let includedRules = recurringRules.filter {
                !($0.type == .expense && WeeklyBudgetService.automaticBucket(forCategoryNamed: $0.category?.name) != nil)
            }
            let occurrences = RecurrenceService.projectedOccurrences(
                for: includedRules, in: DateInterval(start: tomorrow, end: end),
                // Exclude ALL materialized occurrences, not just visible ones, so a
                // manually associated expense cannot reappear from its recurring rule.
                excluding: movements, calendar: calendar
            )
            baseline += occurrences.map { occurrence in
                let amount = recurringOverrides.first {
                    $0.recurringRuleID == occurrence.rule.id &&
                    calendar.isDate($0.occurrenceDate, inSameDayAs: occurrence.date)
                }?.amountInCents ?? occurrence.rule.amountInCents
                return SimulationEntry(
                    id: sourceKey(ruleID: occurrence.rule.id, date: occurrence.date, calendar: calendar),
                    date: occurrence.date, details: occurrence.rule.details,
                    amountInCents: amount, type: occurrence.rule.type,
                    origin: .recurring, isExcluded: false, adjustmentID: nil
                )
            }
        }
        baseline.sort(by: entryOrder)

        // If an older store contains duplicate edits, the latest is authoritative, deterministically.
        var edits: [String: SimulationAdjustment] = [:]
        for adjustment in adjustments.sorted(by: {
            $0.updatedAt == $1.updatedAt ? $0.id.uuidString < $1.id.uuidString : $0.updatedAt < $1.updatedAt
        }) {
            if let key = adjustment.sourceKey { edits[key] = adjustment }
        }
        var entries = baseline.map { entry in
            guard calendar.startOfDay(for: entry.date) > today,
                  let edit = edits[entry.id], edit.amountInCents > 0 else { return entry }
            // An imported occurrence keeps its actual date. A hypothetical edit never moves history.
            return SimulationEntry(
                id: entry.id, date: entry.date, details: edit.details,
                amountInCents: edit.amountInCents, type: edit.type, origin: .adjusted,
                isExcluded: edit.isExcluded, adjustmentID: edit.id
            )
        }
        entries += adjustments.filter {
            $0.sourceKey == nil && $0.amountInCents > 0 &&
            calendar.startOfDay(for: $0.date) > today && $0.date < end
        }.map {
            SimulationEntry(
                id: "hypothesis:\($0.id.uuidString)", date: $0.date, details: $0.details,
                amountInCents: $0.amountInCents, type: $0.type, origin: .hypothesis,
                isExcluded: $0.isExcluded, adjustmentID: $0.id
            )
        }
        entries.sort(by: entryOrder)
        let currentSourceDates = Dictionary(
            movements.filter(\.isConfirmed).map { (sourceKey(for: $0, calendar: calendar), $0.date) },
            uniquingKeysWith: { first, _ in first }
        )
        let inactiveAdjustmentCount = adjustments.filter { adjustment in
            // A rescheduled real movement keeps its source key; use its live date for this message too.
            let effectiveDate = adjustment.sourceKey.flatMap { currentSourceDates[$0] } ?? adjustment.date
            return calendar.startOfDay(for: effectiveDate) <= today
        }.count
        return SimulationResult(
            today: today, through: through, currentBalance: currentBalance,
            baselineEntries: baseline, entries: entries,
            inactiveAdjustmentCount: inactiveAdjustmentCount
        )
    }

    static func sourceKey(for movement: Movement, calendar: Calendar = .current) -> String {
        if let ruleID = movement.sourceRecurringRuleID, let occurrenceDate = movement.occurrenceDate {
            return sourceKey(ruleID: ruleID, date: occurrenceDate, calendar: calendar)
        }
        return "movement:\(movement.id.uuidString)"
    }

    static func sourceKey(ruleID: UUID, date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.era, .year, .month, .day], from: date)
        return "recurring:\(ruleID.uuidString):\(parts.era ?? 1)-\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    private static func entryOrder(_ lhs: SimulationEntry, _ rhs: SimulationEntry) -> Bool {
        lhs.date == rhs.date ? lhs.id < rhs.id : lhs.date < rhs.date
    }
}
