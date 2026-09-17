import Foundation

enum BalanceService {
    static func currentBalance(
        snapshot: BalanceSnapshot?,
        movements: [Movement],
        asOf date: Date = .now,
        calendar: Calendar = .current
    ) -> Int? {
        guard let snapshot else { return nil }
        let currentDay = calendar.startOfDay(for: date)
        let referenceDay = calendar.startOfDay(for: snapshot.referenceDate)

        return movements.reduce(snapshot.amountInCents) { balance, movement in
            let movementDay = calendar.startOfDay(for: movement.date)
            // A movement dated after the snapshot cannot already be part of that day's bank balance,
            // even when it was entered in advance. Same-day/history entries retain the existing rule.
            guard movement.isConfirmed,
                  movementDay <= currentDay,
                  movement.createdAt > snapshot.referenceDate || movementDay > referenceDay else {
                return balance
            }

            switch movement.type {
            case .income:
                return balance + movement.amountInCents
            case .expense:
                return balance - movement.amountInCents
            }
        }
    }

    @MainActor
    static func monthEndForecast(
        snapshot: BalanceSnapshot?,
        movements: [Movement],
        recurringRules: [RecurringRule],
        recurringOverrides: [RecurringOverride],
        asOf date: Date = .now,
        calendar: Calendar = .current
    ) -> Int? {
        guard let snapshot,
              let currentBalance = currentBalance(
                snapshot: snapshot,
                movements: movements,
                asOf: date,
                calendar: calendar
              ),
              let monthInterval = calendar.dateInterval(of: .month, for: date) else {
            return nil
        }

        let currentDay = calendar.startOfDay(for: date)
        let futureMovementEffect = movements.reduce(0) { result, movement in
            let movementDay = calendar.startOfDay(for: movement.date)
            guard movement.isConfirmed,
                  movementDay > currentDay,
                  movement.date < monthInterval.end else {
                return result
            }
            return result + signedEffect(
                amountInCents: movement.amountInCents,
                type: movement.type
            )
        }

        let projectedOccurrences = RecurrenceService.projectedOccurrences(
            for: recurringRules,
            in: monthInterval,
            excluding: movements,
            calendar: calendar
        )
        let projectedEffect = projectedOccurrences.reduce(0) { result, occurrence in
            guard calendar.startOfDay(for: occurrence.date) > currentDay else {
                return result
            }
            let override = recurringOverrides.first {
                $0.recurringRuleID == occurrence.rule.id &&
                calendar.isDate($0.occurrenceDate, inSameDayAs: occurrence.date)
            }
            return result + signedEffect(
                amountInCents: override?.amountInCents ?? occurrence.rule.amountInCents,
                type: occurrence.rule.type
            )
        }

        return currentBalance + futureMovementEffect + projectedEffect
    }

    private static func signedEffect(
        amountInCents: Int,
        type: MovementType
    ) -> Int {
        type == .income ? amountInCents : -amountInCents
    }
}
