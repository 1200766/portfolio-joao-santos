import Foundation
import Testing
@testable import FinanceCore

@Test func categoryMatchingIgnoresCaseAndAccents() {
    let matches = [
        CategorizationMatch(keyword: "padaria", categoryName: "Alimentação"),
        CategorizationMatch(keyword: "cinema", categoryName: "Lazer")
    ]

    #expect(CategorizationMatcher.categoryName(for: "Compra na PADARIA", matches: matches) == "Alimentação")
    #expect(CategorizationMatcher.categoryName(for: "bilhete de cinema", matches: matches) == "Lazer")
    #expect(CategorizationMatcher.categoryName(for: "farmácia", matches: matches) == nil)
}

@Test func recurrenceProducesEveryDueDateWithoutRewritingPastDates() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 1)))
    let end = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 16)))

    let dates = RecurrenceCalculator.dueDates(
        startingAt: start,
        through: end,
        frequency: .weekly,
        calendar: calendar
    )

    #expect(dates.count == 3)
    #expect(calendar.component(.day, from: dates[0]) == 1)
    #expect(calendar.component(.day, from: dates[1]) == 8)
    #expect(calendar.component(.day, from: dates[2]) == 15)
}

@Test func monthlyRecurrenceKeepsCalendarSemantics() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 15)))
    let next = try #require(RecurrenceCalculator.nextDate(after: start, frequency: .monthly, calendar: calendar))

    #expect(calendar.component(.month, from: next) == 2)
    #expect(calendar.component(.day, from: next) == 15)
}

@Test func everyTwoWeeksPreservesFourteenDayCadenceAcrossMonths() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Lisbon")!
    let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 9)))
    let dates = RecurrenceCalculator.upcomingDates(
        startingAt: start, count: 5, frequency: .everyTwoWeeks, calendar: calendar
    )
    let expectedDays = [7, 21, 5, 19, 2]
    let expectedMonths = [9, 9, 10, 10, 11]
    #expect(dates.map { calendar.component(.day, from: $0) } == expectedDays)
    #expect(dates.map { calendar.component(.month, from: $0) } == expectedMonths)
    #expect(dates.allSatisfy { calendar.component(.weekday, from: $0) == 2 })
    #expect(dates.allSatisfy { calendar.component(.hour, from: $0) == 9 })
}

@Test func everyThreeWeeksProducesDueDatesOnlyUntilRequestedDay() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 9)))
    let end = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 13)))
    let dates = RecurrenceCalculator.dueDates(
        startingAt: start, through: end, frequency: .everyThreeWeeks, calendar: calendar
    )
    #expect(dates.count == 3)
    #expect(dates.map { calendar.component(.day, from: $0) } == [1, 22, 13])
    #expect(dates.map { calendar.component(.month, from: $0) } == [9, 9, 10])
    #expect(dates.allSatisfy { calendar.component(.weekday, from: $0) == 3 })
}

@Test func multweekConversionStartsAfterOriginalWithoutDuplicate() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let original = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 7)))
    for (frequency, expectedDay) in [(CoreRecurrenceFrequency.everyTwoWeeks, 21), (.everyThreeWeeks, 28)] {
        let next = try #require(RecurrenceCalculator.nextDate(after: original, frequency: frequency, calendar: calendar))
        #expect(calendar.component(.day, from: next) == expectedDay)
        let future = RecurrenceCalculator.upcomingDates(startingAt: next, count: 8, frequency: frequency, calendar: calendar)
        #expect(!future.contains(original))
        #expect(Set(future).count == 8)
    }
}

@Test func multiweekRecurrenceUsesCalendarWeeksAcrossDaylightSaving() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Lisbon")!
    for (frequency, weeks) in [(CoreRecurrenceFrequency.everyTwoWeeks, 2), (.everyThreeWeeks, 3)] {
        for (month, day, expectedHourDelta) in [(3, 16, -1), (10, 12, 1)] {
            let start = try #require(calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 9)))
            let next = try #require(RecurrenceCalculator.nextDate(after: start, frequency: frequency, calendar: calendar))
            #expect(calendar.dateComponents([.day], from: start, to: next).day == weeks * 7)
            #expect(calendar.component(.hour, from: next) == 9)
            #expect(next.timeIntervalSince(start) == Double(weeks * 7 * 24 + expectedHourDelta) * 3_600)
        }
    }
}

@Test func multiweekRecurrenceCrossesYearBoundaryWithoutResettingCadence() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 12, day: 21)))
    let twoWeeks = try #require(RecurrenceCalculator.nextDate(after: start, frequency: .everyTwoWeeks, calendar: calendar))
    let threeWeeks = try #require(RecurrenceCalculator.nextDate(after: start, frequency: .everyThreeWeeks, calendar: calendar))
    #expect(calendar.component(.year, from: twoWeeks) == 2027)
    #expect(calendar.component(.day, from: twoWeeks) == 4)
    #expect(calendar.component(.year, from: threeWeeks) == 2027)
    #expect(calendar.component(.day, from: threeWeeks) == 11)
}

@Test func originalRecurrenceRawValuesStayCompatible() {
    #expect(CoreRecurrenceFrequency(rawValue: "weekly") == .weekly)
    #expect(CoreRecurrenceFrequency(rawValue: "monthly") == .monthly)
    #expect(CoreRecurrenceFrequency(rawValue: "everyTwoWeeks") == .everyTwoWeeks)
    #expect(CoreRecurrenceFrequency(rawValue: "everyThreeWeeks") == .everyThreeWeeks)
}

@Test func moneyParserConvertsDecimalInputToCents() {
    let locale = Locale(identifier: "pt_PT")
    #expect(MoneyParser.cents(from: "12,34", locale: locale) == 1_234)
    #expect(MoneyParser.cents(from: "-1", locale: locale) == nil)
}

@Test func convertedMonthlyMovementStartsNextMonthWithoutDuplicatingOriginal() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let original = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 1)))
    let firstFuture = try #require(
        RecurrenceCalculator.nextDate(after: original, frequency: .monthly, calendar: calendar)
    )
    let futureDates = RecurrenceCalculator.upcomingDates(
        startingAt: firstFuture,
        count: 2,
        frequency: .monthly,
        calendar: calendar
    )

    #expect(futureDates.count == 2)
    #expect(calendar.component(.month, from: futureDates[0]) == 10)
    #expect(calendar.component(.day, from: futureDates[0]) == 1)
    #expect(calendar.component(.month, from: futureDates[1]) == 11)
    #expect(calendar.component(.day, from: futureDates[1]) == 1)
    #expect(!futureDates.contains(original))

    let allOccurrences = [original] + futureDates
    #expect(allOccurrences.count == 3)
    #expect(allOccurrences.filter { calendar.component(.month, from: $0) == 9 }.count == 1)
    #expect(allOccurrences.filter { calendar.component(.month, from: $0) == 10 }.count == 1)
    #expect(allOccurrences.filter { calendar.component(.month, from: $0) == 11 }.count == 1)
}

@Test func convertedWeeklyMovementStartsOneWeekLater() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let original = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 1)))
    let firstFuture = try #require(
        RecurrenceCalculator.nextDate(after: original, frequency: .weekly, calendar: calendar)
    )

    #expect(calendar.component(.day, from: firstFuture) == 8)
}

@Test func monthlyProjectionContinuesBeyondTwoOccurrences() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let october = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 1)))
    let december = try #require(calendar.date(from: DateComponents(year: 2026, month: 12, day: 31)))

    let dates = RecurrenceCalculator.dueDates(
        startingAt: october,
        through: december,
        frequency: .monthly,
        calendar: calendar
    )

    #expect(dates.count == 3)
    #expect(calendar.component(.month, from: dates[0]) == 10)
    #expect(calendar.component(.month, from: dates[1]) == 11)
    #expect(calendar.component(.month, from: dates[2]) == 12)
    #expect(dates.allSatisfy { calendar.component(.day, from: $0) == 1 })
}

@Test func balanceSnapshotDoesNotCountExistingHistoryAgain() {
    let snapshot = BalanceSnapshotValue(
        amountInCents: 10_000,
        referenceDate: Date(timeIntervalSince1970: 1_000)
    )
    let historicalExpense = BalanceMovement(
        date: Date(timeIntervalSince1970: 800),
        createdAt: Date(timeIntervalSince1970: 900),
        amountInCents: 2_000,
        type: .expense
    )

    let balance = BalanceCalculator.currentBalance(
        snapshot: snapshot,
        movements: [historicalExpense],
        asOf: Date(timeIntervalSince1970: 1_500)
    )

    #expect(balance == 10_000)
}

@Test func incomeCreatedAfterSnapshotIncreasesBalance() {
    let snapshot = BalanceSnapshotValue(
        amountInCents: 10_000,
        referenceDate: Date(timeIntervalSince1970: 1_000)
    )
    let income = BalanceMovement(
        date: Date(timeIntervalSince1970: 1_100),
        createdAt: Date(timeIntervalSince1970: 1_100),
        amountInCents: 2_500,
        type: .income
    )

    let balance = BalanceCalculator.currentBalance(
        snapshot: snapshot,
        movements: [income],
        asOf: Date(timeIntervalSince1970: 1_500)
    )

    #expect(balance == 12_500)
}

@Test func expenseCreatedAfterSnapshotDecreasesBalance() {
    let snapshot = BalanceSnapshotValue(
        amountInCents: 10_000,
        referenceDate: Date(timeIntervalSince1970: 1_000)
    )
    let expense = BalanceMovement(
        date: Date(timeIntervalSince1970: 1_100),
        createdAt: Date(timeIntervalSince1970: 1_100),
        amountInCents: 2_500,
        type: .expense
    )

    let balance = BalanceCalculator.currentBalance(
        snapshot: snapshot,
        movements: [expense],
        asOf: Date(timeIntervalSince1970: 1_500)
    )

    #expect(balance == 7_500)
}

@Test func editingAndDeletingMovementRecalculatesBalance() {
    let snapshot = BalanceSnapshotValue(
        amountInCents: 10_000,
        referenceDate: Date(timeIntervalSince1970: 1_000)
    )
    let movementID = UUID()
    let original = BalanceMovement(
        id: movementID,
        date: Date(timeIntervalSince1970: 1_100),
        createdAt: Date(timeIntervalSince1970: 1_100),
        amountInCents: 2_000,
        type: .expense
    )
    let edited = BalanceMovement(
        id: movementID,
        date: original.date,
        createdAt: original.createdAt,
        amountInCents: 3_000,
        type: .income
    )
    let asOf = Date(timeIntervalSince1970: 1_500)

    #expect(BalanceCalculator.currentBalance(
        snapshot: snapshot,
        movements: [original],
        asOf: asOf
    ) == 8_000)
    #expect(BalanceCalculator.currentBalance(
        snapshot: snapshot,
        movements: [edited],
        asOf: asOf
    ) == 13_000)
    #expect(BalanceCalculator.currentBalance(
        snapshot: snapshot,
        movements: [],
        asOf: asOf
    ) == 10_000)
}

@Test func futureMovementDoesNotAffectCurrentBalance() {
    let snapshot = BalanceSnapshotValue(
        amountInCents: 10_000,
        referenceDate: Date(timeIntervalSince1970: 1_000)
    )
    let futureExpense = BalanceMovement(
        date: Date(timeIntervalSince1970: 100_000),
        createdAt: Date(timeIntervalSince1970: 1_100),
        amountInCents: 2_500,
        type: .expense
    )

    let balanceBeforeOccurrence = BalanceCalculator.currentBalance(
        snapshot: snapshot,
        movements: [futureExpense],
        asOf: Date(timeIntervalSince1970: 1_500)
    )
    let balanceAfterOccurrence = BalanceCalculator.currentBalance(
        snapshot: snapshot,
        movements: [futureExpense],
        asOf: Date(timeIntervalSince1970: 110_000)
    )

    #expect(balanceBeforeOccurrence == 10_000)
    #expect(balanceAfterOccurrence == 7_500)
}

@Test func precreatedFutureMovementsMoveFromForecastToBalanceWithoutDiscontinuity() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Lisbon")!
    let created = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 6, hour: 12)))
    let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 12)))
    let tomorrow = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 8, hour: 12)))
    let snapshot = BalanceSnapshotValue(amountInCents: 100_000, referenceDate: today)
    for (type, expectedBalance) in [(CoreMovementType.income, 120_000), (.expense, 80_000)] {
        let movement = BalanceMovement(date: tomorrow, createdAt: created, amountInCents: 20_000, type: type)
        #expect(BalanceCalculator.currentBalance(snapshot: snapshot, movements: [movement], asOf: today, calendar: calendar) == 100_000)
        let forecastBefore = BalanceCalculator.monthEndForecast(snapshot: snapshot, movements: [movement], projectedMovements: [],
                                                                asOf: today, calendar: calendar)
        #expect(forecastBefore == expectedBalance)
        #expect(BalanceCalculator.currentBalance(snapshot: snapshot, movements: [movement], asOf: tomorrow, calendar: calendar) == expectedBalance)
        let forecastAfter = BalanceCalculator.monthEndForecast(snapshot: snapshot, movements: [movement], projectedMovements: [],
                                                               asOf: tomorrow, calendar: calendar)
        #expect(forecastAfter == forecastBefore)
        let unconfirmed = BalanceMovement(date: tomorrow, createdAt: created, amountInCents: 20_000, type: type, isConfirmed: false)
        #expect(BalanceCalculator.currentBalance(snapshot: snapshot, movements: [unconfirmed], asOf: tomorrow, calendar: calendar) == 100_000)
    }
}

@Test func preSnapshotMovementsOnReferenceDayAreNeverCountedAgain() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Lisbon")!
    let morning = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 9)))
    let afternoon = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 15)))
    let tomorrow = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 8, hour: 12)))
    let snapshot = BalanceSnapshotValue(amountInCents: 100_000, referenceDate: afternoon)
    let movements = [
        BalanceMovement(date: morning, createdAt: morning, amountInCents: 20_000, type: .income),
        BalanceMovement(date: afternoon, createdAt: morning, amountInCents: 10_000, type: .expense)
    ]
    #expect(BalanceCalculator.currentBalance(snapshot: snapshot, movements: movements, asOf: afternoon, calendar: calendar) == 100_000)
    #expect(BalanceCalculator.currentBalance(snapshot: snapshot, movements: movements, asOf: tomorrow, calendar: calendar) == 100_000)
}

@Test func resettingSnapshotAfterPrecreatedMovementAbsorbsItsEffect() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Lisbon")!
    let created = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 6, hour: 12)))
    let originalReference = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 12)))
    let occurrence = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 8, hour: 12)))
    let newReference = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 12)))
    let after = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 12)))
    let movements = [
        BalanceMovement(date: occurrence, createdAt: created, amountInCents: 20_000, type: .income),
        BalanceMovement(date: occurrence, createdAt: created, amountInCents: 5_000, type: .expense)
    ]
    let original = BalanceSnapshotValue(amountInCents: 100_000, referenceDate: originalReference)
    #expect(BalanceCalculator.currentBalance(snapshot: original, movements: movements, asOf: occurrence, calendar: calendar) == 115_000)
    let reset = BalanceSnapshotValue(amountInCents: 115_000, referenceDate: newReference)
    #expect(BalanceCalculator.currentBalance(snapshot: reset, movements: movements, asOf: newReference, calendar: calendar) == 115_000)
    #expect(BalanceCalculator.currentBalance(snapshot: reset, movements: movements, asOf: after, calendar: calendar) == 115_000)
    #expect(BalanceCalculator.monthEndForecast(snapshot: reset, movements: movements, projectedMovements: [], asOf: after, calendar: calendar) == 115_000)
}

@Test func monthEndForecastStartsFromCurrentBalanceAndAddsFutureNetEffect() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let date: (Int, Int, Int) throws -> Date = { year, month, day in
        try #require(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: 12
        )))
    }
    let snapshot = BalanceSnapshotValue(
        amountInCents: 10_000,
        referenceDate: try date(2026, 9, 5)
    )
    let movements = [
        BalanceMovement(
            date: try date(2026, 9, 3),
            createdAt: try date(2026, 9, 4),
            amountInCents: 9_000,
            type: .expense
        ),
        BalanceMovement(
            date: try date(2026, 9, 7),
            createdAt: try date(2026, 9, 6),
            amountInCents: 1_000,
            type: .income
        ),
        BalanceMovement(
            date: try date(2026, 9, 20),
            createdAt: try date(2026, 9, 8),
            amountInCents: 2_000,
            type: .expense
        ),
        BalanceMovement(
            date: try date(2026, 9, 25),
            createdAt: try date(2026, 9, 8),
            amountInCents: 500,
            type: .income
        ),
        BalanceMovement(
            date: try date(2026, 10, 1),
            createdAt: try date(2026, 9, 8),
            amountInCents: 5_000,
            type: .expense
        )
    ]
    let projections = [
        BalanceProjectedMovement(
            date: try date(2026, 9, 15),
            amountInCents: 299,
            type: .expense
        ),
        BalanceProjectedMovement(
            date: try date(2026, 9, 30),
            amountInCents: 1_000,
            type: .income
        ),
        BalanceProjectedMovement(
            date: try date(2026, 10, 1),
            amountInCents: 8_000,
            type: .expense
        )
    ]

    let forecast = BalanceCalculator.monthEndForecast(
        snapshot: snapshot,
        movements: movements,
        projectedMovements: projections,
        asOf: try date(2026, 9, 10),
        calendar: calendar
    )

    #expect(forecast == 10_201)
}

@Test func monthEndForecastIncludesFutureMovementCreatedBeforeSnapshot() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let createdAt = try #require(calendar.date(from: DateComponents(
        year: 2026,
        month: 9,
        day: 1
    )))
    let snapshotDate = try #require(calendar.date(from: DateComponents(
        year: 2026,
        month: 9,
        day: 10
    )))
    let futureDate = try #require(calendar.date(from: DateComponents(
        year: 2026,
        month: 9,
        day: 20
    )))
    let snapshot = BalanceSnapshotValue(
        amountInCents: 10_000,
        referenceDate: snapshotDate
    )
    let futureExpense = BalanceMovement(
        date: futureDate,
        createdAt: createdAt,
        amountInCents: 2_000,
        type: .expense
    )

    #expect(BalanceCalculator.currentBalance(
        snapshot: snapshot,
        movements: [futureExpense],
        asOf: snapshotDate,
        calendar: calendar
    ) == 10_000)
    #expect(BalanceCalculator.monthEndForecast(
        snapshot: snapshot,
        movements: [futureExpense],
        projectedMovements: [],
        asOf: snapshotDate,
        calendar: calendar
    ) == 8_000)
}

@Test func monthEndForecastRecalculatesAfterMovementEditsAndDeletion() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let snapshotDate = try #require(calendar.date(from: DateComponents(
        year: 2026,
        month: 9,
        day: 1
    )))
    let asOf = try #require(calendar.date(from: DateComponents(
        year: 2026,
        month: 9,
        day: 10
    )))
    let futureDate = try #require(calendar.date(from: DateComponents(
        year: 2026,
        month: 9,
        day: 20
    )))
    let snapshot = BalanceSnapshotValue(
        amountInCents: 10_000,
        referenceDate: snapshotDate
    )
    let movementID = UUID()
    let expense = BalanceMovement(
        id: movementID,
        date: futureDate,
        createdAt: asOf,
        amountInCents: 2_000,
        type: .expense
    )
    let editedIncome = BalanceMovement(
        id: movementID,
        date: futureDate,
        createdAt: asOf,
        amountInCents: 3_000,
        type: .income
    )

    #expect(BalanceCalculator.monthEndForecast(
        snapshot: snapshot,
        movements: [expense],
        projectedMovements: [],
        asOf: asOf,
        calendar: calendar
    ) == 8_000)
    #expect(BalanceCalculator.monthEndForecast(
        snapshot: snapshot,
        movements: [editedIncome],
        projectedMovements: [],
        asOf: asOf,
        calendar: calendar
    ) == 13_000)
    #expect(BalanceCalculator.monthEndForecast(
        snapshot: snapshot,
        movements: [],
        projectedMovements: [],
        asOf: asOf,
        calendar: calendar
    ) == 10_000)
}

@Test func monthEndForecastRecalculatesWhenRecurrenceChanges() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let snapshotDate = try #require(calendar.date(from: DateComponents(
        year: 2026,
        month: 9,
        day: 1
    )))
    let asOf = try #require(calendar.date(from: DateComponents(
        year: 2026,
        month: 9,
        day: 10
    )))
    let occurrenceDate = try #require(calendar.date(from: DateComponents(
        year: 2026,
        month: 9,
        day: 15
    )))
    let snapshot = BalanceSnapshotValue(
        amountInCents: 10_000,
        referenceDate: snapshotDate
    )
    let originalProjection = BalanceProjectedMovement(
        date: occurrenceDate,
        amountInCents: 299,
        type: .expense
    )
    let editedProjection = BalanceProjectedMovement(
        date: occurrenceDate,
        amountInCents: 1_000,
        type: .income
    )

    #expect(BalanceCalculator.monthEndForecast(
        snapshot: snapshot,
        movements: [],
        projectedMovements: [originalProjection],
        asOf: asOf,
        calendar: calendar
    ) == 9_701)
    #expect(BalanceCalculator.monthEndForecast(
        snapshot: snapshot,
        movements: [],
        projectedMovements: [editedProjection],
        asOf: asOf,
        calendar: calendar
    ) == 11_000)
    #expect(BalanceCalculator.monthEndForecast(
        snapshot: snapshot,
        movements: [],
        projectedMovements: [],
        asOf: asOf,
        calendar: calendar
    ) == 10_000)
}

@Test func weeklyBudgetStartsOnMondayAndDoesNotCarrySundaySpending() throws {
    let timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let calendar = WeeklyBudgetCalculator.calendar(timeZone: timeZone)
    let sunday = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 6, hour: 12)))
    let monday = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 12)))
    let previousWeekMovement = WeeklyBudgetMovement(
        date: sunday,
        amountInCents: 2_000,
        categoryName: "Alimentação"
    )

    let interval = WeeklyBudgetCalculator.weekInterval(containing: monday, calendar: calendar)
    let progress = WeeklyBudgetCalculator.progress(
        for: monday,
        movements: [previousWeekMovement],
        asOf: monday,
        calendar: calendar
    )

    #expect(calendar.component(.weekday, from: interval.start) == 2)
    #expect(progress.allSatisfy { $0.spentInCents == 0 })
    #expect(progress.allSatisfy { $0.remainingInCents == nil })
}

@Test func oneMovementIsCountedOnceWithoutDuplication() throws {
    let timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let calendar = WeeklyBudgetCalculator.calendar(timeZone: timeZone)
    let monday = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 12)))
    let movement = WeeklyBudgetMovement(
        date: monday,
        amountInCents: 1_000,
        categoryName: "Alimentação"
    )

    let progress = WeeklyBudgetCalculator.progress(
        for: monday,
        movements: [movement],
        asOf: monday,
        calendar: calendar
    )

    #expect(progress.reduce(0) { $0 + $1.spentInCents } == 1_000)
    #expect(progress.first { $0.bucket == .groceries }?.spentInCents == 1_000)
    #expect(progress.first { $0.bucket == .transport }?.spentInCents == 0)
    #expect(progress.first { $0.bucket == .leisure }?.spentInCents == 0)
}

@Test func categoryMappingCanBeCorrectedOrExcludedManually() {
    let date = Date(timeIntervalSince1970: 1_000)
    let automatic = WeeklyBudgetMovement(
        date: date,
        amountInCents: 1_000,
        categoryName: "Transportes"
    )
    let corrected = WeeklyBudgetMovement(
        date: date,
        amountInCents: 1_000,
        categoryName: "Transportes",
        association: .bucket(.leisure)
    )
    let excluded = WeeklyBudgetMovement(
        date: date,
        amountInCents: 1_000,
        categoryName: "Alimentação",
        association: .excluded
    )
    let unrelatedCategory = WeeklyBudgetMovement(
        date: date,
        amountInCents: 1_000,
        categoryName: "Habitação"
    )

    #expect(WeeklyBudgetCalculator.bucket(for: automatic) == .transport)
    #expect(WeeklyBudgetCalculator.bucket(for: corrected) == .leisure)
    #expect(WeeklyBudgetCalculator.bucket(for: excluded) == nil)
    #expect(WeeklyBudgetCalculator.bucket(for: unrelatedCategory) == nil)
}

@Test func weeklyBudgetIgnoresFutureAndIncomeMovements() throws {
    let timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let calendar = WeeklyBudgetCalculator.calendar(timeZone: timeZone)
    let monday = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 12)))
    let tuesday = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 8, hour: 12)))
    let futureExpense = WeeklyBudgetMovement(
        date: tuesday,
        amountInCents: 2_000,
        categoryName: "Lazer"
    )
    let income = WeeklyBudgetMovement(
        date: monday,
        amountInCents: 2_000,
        type: .income,
        categoryName: "Lazer"
    )

    let progress = WeeklyBudgetCalculator.progress(
        for: monday,
        movements: [futureExpense, income],
        asOf: monday,
        calendar: calendar
    )

    #expect(progress.allSatisfy { $0.spentInCents == 0 })
}

@Test func notificationPolicyExcludesTransportAndDeduplicatesThresholds() {
    let transport = WeeklyBudgetProgressValue(bucket: .transport, spentInCents: 4_000, limitInCents: 3_000)
    let groceries = WeeklyBudgetProgressValue(bucket: .groceries, spentInCents: 3_500, limitInCents: 3_000)

    #expect(WeeklyBudgetCalculator.crossedThresholds(for: transport).isEmpty)
    #expect(WeeklyBudgetCalculator.crossedThresholds(for: groceries) == [
        .approaching,
        .reached,
        .exceeded
    ])
    #expect(WeeklyBudgetCalculator.pendingThresholds(
        for: groceries,
        alreadySent: [.approaching, .reached]
    ) == [.exceeded])
    #expect(WeeklyBudgetCalculator.pendingThresholds(
        for: groceries,
        alreadySent: [.approaching, .reached, .exceeded]
    ).isEmpty)
}

@Test func weeklyConfigurationCustomizesEveryLimitAndKeepsTotalIndependent() throws {
    let calendar = WeeklyBudgetCalculator.calendar(timeZone: try #require(TimeZone(identifier: "Europe/Lisbon")))
    let monday = try budgetDate(day: 7, calendar: calendar)
    let plan = budgetConfiguration(weekStart: monday)
    let movements = [
        WeeklyBudgetMovement(date: monday, amountInCents: 800, categoryName: "Alimentação"),
        WeeklyBudgetMovement(date: monday, amountInCents: 4_000, categoryName: "Transportes"),
        WeeklyBudgetMovement(date: monday, amountInCents: 2_500, categoryName: "Lazer"),
        WeeklyBudgetMovement(date: monday, amountInCents: 9_000, categoryName: "Habitação")
    ]
    let progress = WeeklyBudgetCalculator.progress(
        for: monday, movements: movements, asOf: monday, calendar: calendar, configuration: plan
    )
    let groceries = try #require(progress.first { $0.bucket == .groceries })
    let transport = try #require(progress.first { $0.bucket == .transport })
    let leisure = try #require(progress.first { $0.bucket == .leisure })
    let total = WeeklyBudgetCalculator.totalProgress(
        for: monday, movements: movements, asOf: monday, calendar: calendar, configuration: plan
    )

    #expect(groceries.limitInCents == 500)
    #expect(groceries.excessInCents == 300)
    #expect(transport.limitInCents == 5_000)
    #expect(transport.remainingInCents == 1_000)
    #expect(leisure.limitInCents == 2_000)
    #expect(leisure.excessInCents == 500)
    #expect(total.spentInCents == 7_300)
    #expect(total.limitInCents == 6_000)
    #expect(total.remainingInCents == 0)
    #expect(total.excessInCents == 1_300)
    #expect(WeeklyBudgetCalculator.crossedThresholds(for: groceries) == [.approaching, .reached, .exceeded])
    #expect(WeeklyBudgetCalculator.crossedThresholds(for: transport).isEmpty)
}

@Test func noConfirmedConfigurationKeepsSpendingWithoutLimitsOrAlerts() throws {
    let calendar = WeeklyBudgetCalculator.calendar(timeZone: try #require(TimeZone(secondsFromGMT: 0)))
    let monday = try budgetDate(day: 7, calendar: calendar)
    let movement = WeeklyBudgetMovement(date: monday, amountInCents: 4_000, categoryName: "Alimentação")
    let unconfirmed = budgetConfiguration(weekStart: monday, isConfirmed: false)
    let configurations: [WeeklyBudgetConfigurationValue?] = [nil, unconfirmed]

    for configuration in configurations {
        let progress = WeeklyBudgetCalculator.progress(
            for: monday, movements: [movement], asOf: monday, calendar: calendar, configuration: configuration
        )
        let total = WeeklyBudgetCalculator.totalProgress(
            for: monday, movements: [movement], asOf: monday, calendar: calendar, configuration: configuration
        )
        #expect(progress.first { $0.bucket == .groceries }?.spentInCents == 4_000)
        #expect(progress.allSatisfy { $0.limitInCents == nil && $0.remainingInCents == nil && $0.excessInCents == nil })
        #expect(progress.allSatisfy { WeeklyBudgetCalculator.crossedThresholds(for: $0).isEmpty })
        #expect(total.spentInCents == 4_000)
        #expect(total.limitInCents == nil && total.remainingInCents == nil && total.excessInCents == nil)
    }
}

@Test func confirmedLimitsApplyThroughSundayButNeverCarryIntoNextWeek() throws {
    let calendar = WeeklyBudgetCalculator.calendar(timeZone: try #require(TimeZone(secondsFromGMT: 0)))
    let monday = try budgetDate(day: 7, calendar: calendar)
    let sunday = try budgetDate(day: 13, calendar: calendar)
    let nextMonday = try budgetDate(day: 14, calendar: calendar)
    let plan = budgetConfiguration(weekStart: monday)
    let movements = [
        WeeklyBudgetMovement(date: sunday, amountInCents: 200, categoryName: "Alimentação"),
        WeeklyBudgetMovement(date: nextMonday, amountInCents: 700, categoryName: "Alimentação")
    ]
    let sundayProgress = WeeklyBudgetCalculator.progress(
        for: sunday, movements: movements, asOf: sunday, calendar: calendar, configuration: plan
    )
    let nextProgress = WeeklyBudgetCalculator.progress(
        for: nextMonday, movements: movements, asOf: nextMonday, calendar: calendar, configuration: plan
    )

    #expect(sundayProgress.first { $0.bucket == .groceries }?.remainingInCents == 300)
    #expect(nextProgress.first { $0.bucket == .groceries }?.spentInCents == 700)
    #expect(nextProgress.allSatisfy { $0.limitInCents == nil })
    #expect(nextProgress.allSatisfy { WeeklyBudgetCalculator.crossedThresholds(for: $0).isEmpty })
    #expect(WeeklyBudgetCalculator.configuration(for: nextMonday, configurations: [plan], calendar: calendar) == nil)
}

@Test func midweekConfirmationIncludesEarlierSpendingAndUpdatesImmediately() throws {
    let calendar = WeeklyBudgetCalculator.calendar(timeZone: try #require(TimeZone(secondsFromGMT: 0)))
    let monday = try budgetDate(day: 7, calendar: calendar)
    let wednesday = try budgetDate(day: 9, calendar: calendar)
    let thursday = try budgetDate(day: 10, calendar: calendar)
    let plan = budgetConfiguration(weekStart: monday)
    let movements = [
        WeeklyBudgetMovement(date: monday, amountInCents: 300, categoryName: "Alimentação"),
        WeeklyBudgetMovement(date: wednesday, amountInCents: 150, categoryName: "Alimentação"),
        WeeklyBudgetMovement(date: thursday, amountInCents: 100, categoryName: "Alimentação"),
        WeeklyBudgetMovement(date: wednesday, amountInCents: 9_000, isConfirmed: false, categoryName: "Alimentação")
    ]
    let progress = WeeklyBudgetCalculator.progress(
        for: wednesday, movements: movements, asOf: wednesday, calendar: calendar, configuration: plan
    )
    let groceries = try #require(progress.first { $0.bucket == .groceries })
    let nextDay = WeeklyBudgetCalculator.progress(
        for: wednesday, movements: movements, asOf: thursday, calendar: calendar, configuration: plan
    )

    #expect(groceries.spentInCents == 450)
    #expect(groceries.remainingInCents == 50)
    #expect(WeeklyBudgetCalculator.crossedThresholds(for: groceries) == [.approaching])
    #expect(nextDay.first { $0.bucket == .groceries }?.spentInCents == 550)
    #expect(nextDay.first { $0.bucket == .groceries }?.excessInCents == 50)
}

@Test func editingOneWeekDoesNotAlterAnotherWeeksConfiguration() throws {
    let calendar = WeeklyBudgetCalculator.calendar(timeZone: try #require(TimeZone(secondsFromGMT: 0)))
    let monday = try budgetDate(day: 7, calendar: calendar)
    let nextMonday = try budgetDate(day: 14, calendar: calendar)
    let original = budgetConfiguration(weekStart: monday)
    let otherWeek = budgetConfiguration(weekStart: nextMonday)
    var plans = [original, otherWeek]
    plans[0] = WeeklyBudgetConfigurationValue(
        weekStart: monday,
        totalLimitInCents: 12_000,
        groceriesLimitInCents: 1_000,
        transportLimitInCents: 7_000,
        leisureLimitInCents: 3_000
    )
    let selected = try #require(WeeklyBudgetCalculator.configuration(for: monday, configurations: plans, calendar: calendar))
    let unchanged = WeeklyBudgetCalculator.configuration(for: nextMonday, configurations: plans, calendar: calendar)

    #expect(selected.totalLimitInCents == 12_000)
    #expect(selected.transportLimitInCents == 7_000)
    #expect(unchanged == otherWeek)
    #expect(original.totalLimitInCents == 6_000)
}

@Test func zeroLimitsOnlyAlertAfterSpendingAndNeverAlertForTransport() throws {
    let calendar = WeeklyBudgetCalculator.calendar(timeZone: try #require(TimeZone(secondsFromGMT: 0)))
    let monday = try budgetDate(day: 7, calendar: calendar)
    let plan = WeeklyBudgetConfigurationValue(
        weekStart: monday, totalLimitInCents: 0, groceriesLimitInCents: 0,
        transportLimitInCents: 0, leisureLimitInCents: 0
    )
    let empty = WeeklyBudgetCalculator.progress(
        for: monday, movements: [], asOf: monday, calendar: calendar, configuration: plan
    )
    #expect(empty.allSatisfy { $0.limitInCents == 0 && $0.remainingInCents == 0 && $0.excessInCents == 0 })
    #expect(empty.allSatisfy { WeeklyBudgetCalculator.crossedThresholds(for: $0).isEmpty })

    for bucket in CoreBudgetBucket.allCases {
        let movement = WeeklyBudgetMovement(
            date: monday, amountInCents: 1, categoryName: nil, association: .bucket(bucket)
        )
        let progress = WeeklyBudgetCalculator.progress(
            for: monday, movements: [movement], asOf: monday, calendar: calendar, configuration: plan
        )
        let value = try #require(progress.first { $0.bucket == bucket })
        let total = WeeklyBudgetCalculator.totalProgress(
            for: monday, movements: [movement], asOf: monday, calendar: calendar, configuration: plan
        )
        #expect(value.remainingInCents == 0)
        #expect(value.excessInCents == 1)
        #expect(total.excessInCents == 1)
        #expect(WeeklyBudgetCalculator.crossedThresholds(for: value) == (bucket == .transport ? [] : [.exceeded]))
        #expect(WeeklyBudgetCalculator.pendingThresholds(for: value, alreadySent: [.exceeded]).isEmpty)
    }
}

@Test func weeklyCalendarUsesMondayEvenIfSystemCalendarStartsSunday() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "Europe/Lisbon"))
    calendar.firstWeekday = 1
    let sunday = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 12)))
    let interval = WeeklyBudgetCalculator.weekInterval(containing: sunday, calendar: calendar)

    #expect(calendar.component(.weekday, from: interval.start) == 2)
    #expect(calendar.component(.day, from: interval.start) == 19)
    #expect(calendar.component(.weekday, from: interval.end) == 2)
    #expect(calendar.component(.day, from: interval.end) == 26)
    #expect(calendar.component(.hour, from: interval.end) == 0)
    #expect(interval.duration == 7 * 24 * 60 * 60 + 60 * 60)
}

@Test func invalidNegativeLimitsDoNotActivateWeeklyConfiguration() throws {
    let calendar = WeeklyBudgetCalculator.calendar(timeZone: try #require(TimeZone(secondsFromGMT: 0)))
    let monday = try budgetDate(day: 7, calendar: calendar)
    let plan = WeeklyBudgetConfigurationValue(
        weekStart: monday, totalLimitInCents: 6_000, groceriesLimitInCents: -1,
        transportLimitInCents: 5_000, leisureLimitInCents: 2_000
    )

    #expect(!plan.hasValidLimits)
    #expect(WeeklyBudgetCalculator.configuration(for: monday, configurations: [plan], calendar: calendar) == nil)
}

private func budgetDate(day: Int, calendar: Calendar) throws -> Date {
    try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: 12)))
}

private func budgetConfiguration(weekStart: Date, isConfirmed: Bool = true) -> WeeklyBudgetConfigurationValue {
    WeeklyBudgetConfigurationValue(
        weekStart: weekStart,
        totalLimitInCents: 6_000,
        groceriesLimitInCents: 500,
        transportLimitInCents: 5_000,
        leisureLimitInCents: 2_000,
        isConfirmed: isConfirmed
    )
}
