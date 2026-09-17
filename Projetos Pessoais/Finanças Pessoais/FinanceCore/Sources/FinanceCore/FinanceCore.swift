import Foundation

public enum CoreMovementType: String, Sendable {
    case income
    case expense
}

public struct BalanceMovement: Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let createdAt: Date
    public let amountInCents: Int
    public let type: CoreMovementType
    public let isConfirmed: Bool

    public init(
        id: UUID = UUID(),
        date: Date,
        createdAt: Date,
        amountInCents: Int,
        type: CoreMovementType,
        isConfirmed: Bool = true
    ) {
        self.id = id
        self.date = date
        self.createdAt = createdAt
        self.amountInCents = amountInCents
        self.type = type
        self.isConfirmed = isConfirmed
    }
}

public struct BalanceSnapshotValue: Equatable, Sendable {
    public let amountInCents: Int
    public let referenceDate: Date

    public init(amountInCents: Int, referenceDate: Date) {
        self.amountInCents = amountInCents
        self.referenceDate = referenceDate
    }
}

public struct BalanceProjectedMovement: Equatable, Sendable {
    public let date: Date
    public let amountInCents: Int
    public let type: CoreMovementType

    public init(
        date: Date,
        amountInCents: Int,
        type: CoreMovementType
    ) {
        self.date = date
        self.amountInCents = amountInCents
        self.type = type
    }
}

public enum BalanceCalculator {
    public static func currentBalance(
        snapshot: BalanceSnapshotValue?,
        movements: [BalanceMovement],
        asOf date: Date,
        calendar: Calendar = .current
    ) -> Int? {
        guard let snapshot else { return nil }
        let currentDay = calendar.startOfDay(for: date)
        let referenceDay = calendar.startOfDay(for: snapshot.referenceDate)

        return movements.reduce(snapshot.amountInCents) { balance, movement in
            let movementDay = calendar.startOfDay(for: movement.date)
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

    public static func monthEndForecast(
        snapshot: BalanceSnapshotValue?,
        movements: [BalanceMovement],
        projectedMovements: [BalanceProjectedMovement],
        asOf date: Date,
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
        let projectedEffect = projectedMovements.reduce(0) { result, movement in
            let movementDay = calendar.startOfDay(for: movement.date)
            guard movementDay > currentDay,
                  movement.date < monthInterval.end else {
                return result
            }
            return result + signedEffect(
                amountInCents: movement.amountInCents,
                type: movement.type
            )
        }

        return currentBalance + futureMovementEffect + projectedEffect
    }

    private static func signedEffect(
        amountInCents: Int,
        type: CoreMovementType
    ) -> Int {
        type == .income ? amountInCents : -amountInCents
    }
}

public enum CoreBudgetBucket: String, CaseIterable, Sendable {
    case groceries
    case transport
    case leisure

    public var sendsNotifications: Bool { self != .transport }
}

public struct WeeklyBudgetConfigurationValue: Equatable, Sendable {
    public let weekStart: Date
    public let totalLimitInCents: Int
    public let groceriesLimitInCents: Int
    public let transportLimitInCents: Int
    public let leisureLimitInCents: Int
    public let isConfirmed: Bool

    public init(
        weekStart: Date,
        totalLimitInCents: Int,
        groceriesLimitInCents: Int,
        transportLimitInCents: Int,
        leisureLimitInCents: Int,
        isConfirmed: Bool = true
    ) {
        self.weekStart = weekStart
        self.totalLimitInCents = totalLimitInCents
        self.groceriesLimitInCents = groceriesLimitInCents
        self.transportLimitInCents = transportLimitInCents
        self.leisureLimitInCents = leisureLimitInCents
        self.isConfirmed = isConfirmed
    }

    public var hasValidLimits: Bool {
        totalLimitInCents >= 0 && groceriesLimitInCents >= 0 &&
        transportLimitInCents >= 0 && leisureLimitInCents >= 0
    }

    public func limitInCents(for bucket: CoreBudgetBucket) -> Int {
        switch bucket {
        case .groceries: groceriesLimitInCents
        case .transport: transportLimitInCents
        case .leisure: leisureLimitInCents
        }
    }
}

public enum CoreBudgetAssociation: Equatable, Sendable {
    case automatic
    case excluded
    case bucket(CoreBudgetBucket)
}

public enum CoreBudgetNotificationThreshold: String, CaseIterable, Sendable {
    case approaching
    case reached
    case exceeded
}

public struct WeeklyBudgetMovement: Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let amountInCents: Int
    public let type: CoreMovementType
    public let isConfirmed: Bool
    public let categoryName: String?
    public let association: CoreBudgetAssociation

    public init(
        id: UUID = UUID(),
        date: Date,
        amountInCents: Int,
        type: CoreMovementType = .expense,
        isConfirmed: Bool = true,
        categoryName: String?,
        association: CoreBudgetAssociation = .automatic
    ) {
        self.id = id
        self.date = date
        self.amountInCents = amountInCents
        self.type = type
        self.isConfirmed = isConfirmed
        self.categoryName = categoryName
        self.association = association
    }
}

public struct WeeklyBudgetProgressValue: Equatable, Sendable {
    public let bucket: CoreBudgetBucket
    public let spentInCents: Int
    public let limitInCents: Int?

    public init(bucket: CoreBudgetBucket, spentInCents: Int, limitInCents: Int? = nil) {
        self.bucket = bucket
        self.spentInCents = spentInCents
        self.limitInCents = limitInCents.flatMap { $0 >= 0 ? $0 : nil }
    }

    public var remainingInCents: Int? { limitInCents.map { max($0 - spentInCents, 0) } }
    public var excessInCents: Int? { limitInCents.map { max(spentInCents - $0, 0) } }
}

public struct WeeklyBudgetTotalProgressValue: Equatable, Sendable {
    public let spentInCents: Int
    public let limitInCents: Int?

    public var remainingInCents: Int? { limitInCents.map { max($0 - spentInCents, 0) } }
    public var excessInCents: Int? { limitInCents.map { max(spentInCents - $0, 0) } }
}

public enum WeeklyBudgetCalculator {
    public static func calendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timeZone
        return calendar
    }

    public static func weekInterval(
        containing date: Date,
        calendar: Calendar
    ) -> DateInterval {
        let weekCalendar = self.calendar(timeZone: calendar.timeZone)
        return weekCalendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(
            start: weekCalendar.startOfDay(for: date),
            end: weekCalendar.date(byAdding: .day, value: 7, to: weekCalendar.startOfDay(for: date))!
        )
    }

    public static func configuration(
        for week: Date,
        configurations: [WeeklyBudgetConfigurationValue],
        calendar: Calendar
    ) -> WeeklyBudgetConfigurationValue? {
        let start = weekInterval(containing: week, calendar: calendar).start
        return configurations.last {
            $0.isConfirmed && $0.hasValidLimits &&
            weekInterval(containing: $0.weekStart, calendar: calendar).start == start
        }
    }

    public static func bucket(for movement: WeeklyBudgetMovement) -> CoreBudgetBucket? {
        switch movement.association {
        case .excluded:
            return nil
        case .bucket(let bucket):
            return bucket
        case .automatic:
            guard let categoryName = movement.categoryName else { return nil }
            switch normalize(categoryName) {
            case "alimentacao": return .groceries
            case "transportes": return .transport
            case "lazer": return .leisure
            default: return nil
            }
        }
    }

    public static func progress(
        for week: Date,
        movements: [WeeklyBudgetMovement],
        asOf date: Date,
        calendar: Calendar,
        configuration: WeeklyBudgetConfigurationValue? = nil
    ) -> [WeeklyBudgetProgressValue] {
        let interval = weekInterval(containing: week, calendar: calendar)
        let activeConfiguration = self.configuration(
            for: week,
            configurations: configuration.map { [$0] } ?? [],
            calendar: calendar
        )
        let currentDay = calendar.startOfDay(for: date)
        let eligible = movements.filter {
            $0.isConfirmed &&
            $0.type == .expense &&
            $0.date >= interval.start &&
            $0.date < interval.end &&
            calendar.startOfDay(for: $0.date) <= currentDay
        }

        return CoreBudgetBucket.allCases.map { bucket in
            let spent = eligible
                .filter { self.bucket(for: $0) == bucket }
                .reduce(0) { $0 + $1.amountInCents }
            return WeeklyBudgetProgressValue(
                bucket: bucket,
                spentInCents: spent,
                limitInCents: activeConfiguration?.limitInCents(for: bucket)
            )
        }
    }

    public static func totalProgress(
        for week: Date,
        movements: [WeeklyBudgetMovement],
        asOf date: Date,
        calendar: Calendar,
        configuration: WeeklyBudgetConfigurationValue? = nil
    ) -> WeeklyBudgetTotalProgressValue {
        let activeConfiguration = self.configuration(
            for: week,
            configurations: configuration.map { [$0] } ?? [],
            calendar: calendar
        )
        let categories = progress(
            for: week,
            movements: movements,
            asOf: date,
            calendar: calendar,
            configuration: activeConfiguration
        )
        return WeeklyBudgetTotalProgressValue(
            spentInCents: categories.reduce(0) { $0 + $1.spentInCents },
            limitInCents: activeConfiguration?.totalLimitInCents
        )
    }

    public static func crossedThresholds(
        for progress: WeeklyBudgetProgressValue
    ) -> [CoreBudgetNotificationThreshold] {
        guard progress.bucket.sendsNotifications,
              let limit = progress.limitInCents else { return [] }
        guard limit > 0 else {
            return progress.spentInCents > 0 ? [.exceeded] : []
        }

        var thresholds: [CoreBudgetNotificationThreshold] = []
        if Decimal(progress.spentInCents) * 100 >= Decimal(limit) * 80 {
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

    public static func pendingThresholds(
        for progress: WeeklyBudgetProgressValue,
        alreadySent: Set<CoreBudgetNotificationThreshold>
    ) -> [CoreBudgetNotificationThreshold] {
        crossedThresholds(for: progress).filter { !alreadySent.contains($0) }
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

public enum CoreRecurrenceFrequency: String, Sendable {
    case weekly
    case everyTwoWeeks
    case everyThreeWeeks
    case monthly
}

public struct CategorizationMatch: Equatable, Sendable {
    public let keyword: String
    public let categoryName: String

    public init(keyword: String, categoryName: String) {
        self.keyword = keyword
        self.categoryName = categoryName
    }
}

public enum CategorizationMatcher {
    public static func categoryName(
        for description: String,
        matches: [CategorizationMatch]
    ) -> String? {
        let normalizedDescription = normalize(description)
        return matches.first { match in
            normalizedDescription.contains(normalize(match.keyword))
        }?.categoryName
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

public enum MoneyParser {
    public static func cents(from input: String, locale: Locale = .current) -> Int? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        guard let number = formatter.number(from: input), number.decimalValue >= 0 else {
            return nil
        }
        let decimal = number.decimalValue * 100
        return NSDecimalNumber(decimal: decimal).rounding(
            accordingToBehavior: NSDecimalNumberHandler(
                roundingMode: .plain,
                scale: 0,
                raiseOnExactness: false,
                raiseOnOverflow: false,
                raiseOnUnderflow: false,
                raiseOnDivideByZero: false
            )
        ).intValue
    }
}

public enum RecurrenceCalculator {
    public static func nextDate(
        after date: Date,
        frequency: CoreRecurrenceFrequency,
        calendar: Calendar = .current
    ) -> Date? {
        switch frequency {
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .everyTwoWeeks:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: date)
        case .everyThreeWeeks:
            return calendar.date(byAdding: .weekOfYear, value: 3, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        }
    }

    public static func dueDates(
        startingAt firstDate: Date,
        through date: Date,
        frequency: CoreRecurrenceFrequency,
        calendar: Calendar = .current
    ) -> [Date] {
        var dates: [Date] = []
        var cursor = firstDate

        while calendar.startOfDay(for: cursor) <= calendar.startOfDay(for: date) {
            dates.append(cursor)
            guard let next = nextDate(after: cursor, frequency: frequency, calendar: calendar),
                  next > cursor else {
                break
            }
            cursor = next
        }

        return dates
    }

    public static func upcomingDates(
        startingAt firstDate: Date,
        count: Int,
        frequency: CoreRecurrenceFrequency,
        calendar: Calendar = .current
    ) -> [Date] {
        guard count > 0 else { return [] }

        var dates: [Date] = []
        var cursor = firstDate
        for _ in 0..<count {
            dates.append(cursor)
            guard let next = nextDate(after: cursor, frequency: frequency, calendar: calendar),
                  next > cursor else {
                break
            }
            cursor = next
        }
        return dates
    }
}
