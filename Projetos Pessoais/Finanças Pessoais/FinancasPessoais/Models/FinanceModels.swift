import Foundation
import SwiftData

enum MovementType: String, Codable, CaseIterable, Identifiable {
    case income
    case expense

    var id: String { rawValue }

    var title: String {
        switch self {
        case .income: "Ganho"
        case .expense: "Despesa"
        }
    }
}

enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly
    case everyTwoWeeks
    case everyThreeWeeks
    case monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly: "Semanal"
        case .everyTwoWeeks: "De 2 em 2 semanas"
        case .everyThreeWeeks: "De 3 em 3 semanas"
        case .monthly: "Mensal"
        }
    }

    var weekInterval: Int? {
        switch self {
        case .weekly: 1
        case .everyTwoWeeks: 2
        case .everyThreeWeeks: 3
        case .monthly: nil
        }
    }
}

enum BudgetBucket: String, Codable, CaseIterable, Identifiable {
    case groceries
    case transport
    case leisure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .groceries: "Alimentação"
        case .transport: "Transportes"
        case .leisure: "Lazer"
        }
    }

    var sendsNotifications: Bool {
        self != .transport
    }
}

enum BudgetAssociationSelection: String, CaseIterable, Identifiable {
    case automatic
    case excluded
    case groceries
    case transport
    case leisure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Automático pela categoria"
        case .excluded: "Não contabilizar"
        case .groceries: "Alimentação"
        case .transport: "Transportes"
        case .leisure: "Lazer"
        }
    }

    var bucket: BudgetBucket? {
        BudgetBucket(rawValue: rawValue)
    }
}

enum BudgetNotificationThreshold: String, Codable, CaseIterable {
    case approaching
    case reached
    case exceeded
}

@Model
final class FinanceCategory {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

@Model
final class Movement {
    @Attribute(.unique) var id: UUID
    var date: Date
    var details: String
    var amountInCents: Int
    var typeRawValue: String
    var isConfirmed: Bool
    var createdAt: Date
    var sourceRecurringRuleID: UUID?
    var occurrenceDate: Date?
    @Relationship(deleteRule: .nullify) var category: FinanceCategory?

    var type: MovementType {
        get { MovementType(rawValue: typeRawValue) ?? .expense }
        set { typeRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        date: Date,
        details: String,
        amountInCents: Int,
        type: MovementType,
        category: FinanceCategory?,
        isConfirmed: Bool = true,
        sourceRecurringRuleID: UUID? = nil,
        occurrenceDate: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.details = details
        self.amountInCents = amountInCents
        self.typeRawValue = type.rawValue
        self.category = category
        self.isConfirmed = isConfirmed
        self.sourceRecurringRuleID = sourceRecurringRuleID
        self.occurrenceDate = occurrenceDate
        self.createdAt = createdAt
    }
}

@Model
final class CategorizationRule {
    @Attribute(.unique) var id: UUID
    var keyword: String
    var createdAt: Date
    @Relationship(deleteRule: .nullify) var category: FinanceCategory?

    init(id: UUID = UUID(), keyword: String, category: FinanceCategory?, createdAt: Date = .now) {
        self.id = id
        self.keyword = keyword
        self.category = category
        self.createdAt = createdAt
    }
}

@Model
final class RecurringRule {
    @Attribute(.unique) var id: UUID
    var details: String
    var amountInCents: Int
    var typeRawValue: String
    var frequencyRawValue: String
    var nextDueDate: Date
    var isActive: Bool
    var createdAt: Date
    @Relationship(deleteRule: .nullify) var category: FinanceCategory?

    var type: MovementType {
        get { MovementType(rawValue: typeRawValue) ?? .expense }
        set { typeRawValue = newValue.rawValue }
    }

    var frequency: RecurrenceFrequency {
        get { RecurrenceFrequency(rawValue: frequencyRawValue) ?? .monthly }
        set { frequencyRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        details: String,
        amountInCents: Int,
        type: MovementType,
        frequency: RecurrenceFrequency,
        nextDueDate: Date,
        category: FinanceCategory?,
        isActive: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.details = details
        self.amountInCents = amountInCents
        self.typeRawValue = type.rawValue
        self.frequencyRawValue = frequency.rawValue
        self.nextDueDate = nextDueDate
        self.category = category
        self.isActive = isActive
        self.createdAt = createdAt
    }
}

@Model
final class RecurringOverride {
    @Attribute(.unique) var id: UUID
    var recurringRuleID: UUID
    var occurrenceDate: Date
    var amountInCents: Int

    init(id: UUID = UUID(), recurringRuleID: UUID, occurrenceDate: Date, amountInCents: Int) {
        self.id = id
        self.recurringRuleID = recurringRuleID
        self.occurrenceDate = occurrenceDate
        self.amountInCents = amountInCents
    }
}

@Model
final class BalanceSnapshot {
    @Attribute(.unique) var id: UUID
    var amountInCents: Int
    var referenceDate: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        amountInCents: Int,
        referenceDate: Date = .now,
        createdAt: Date = .now
    ) {
        self.id = id
        self.amountInCents = amountInCents
        self.referenceDate = referenceDate
        self.createdAt = createdAt
    }
}

@Model
final class MovementBudgetAssignment {
    @Attribute(.unique) var movementID: UUID
    var selectionRawValue: String
    var updatedAt: Date

    init(
        movementID: UUID,
        selection: BudgetAssociationSelection,
        updatedAt: Date = .now
    ) {
        self.movementID = movementID
        self.selectionRawValue = selection.rawValue
        self.updatedAt = updatedAt
    }

    var selection: BudgetAssociationSelection {
        get { BudgetAssociationSelection(rawValue: selectionRawValue) ?? .excluded }
        set {
            selectionRawValue = newValue.rawValue
            updatedAt = .now
        }
    }
}

@Model
final class WeeklyBudgetPlan {
    @Attribute(.unique) var weekKey: String
    var weekStart: Date
    var totalLimitInCents: Int
    var groceriesLimitInCents: Int
    var transportLimitInCents: Int
    var leisureLimitInCents: Int
    var confirmedAt: Date

    init(
        weekKey: String,
        weekStart: Date,
        totalLimitInCents: Int,
        groceriesLimitInCents: Int,
        transportLimitInCents: Int,
        leisureLimitInCents: Int,
        confirmedAt: Date = .now
    ) {
        self.weekKey = weekKey
        self.weekStart = weekStart
        self.totalLimitInCents = totalLimitInCents
        self.groceriesLimitInCents = groceriesLimitInCents
        self.transportLimitInCents = transportLimitInCents
        self.leisureLimitInCents = leisureLimitInCents
        self.confirmedAt = confirmedAt
    }

    func limit(for bucket: BudgetBucket) -> Int {
        switch bucket {
        case .groceries: groceriesLimitInCents
        case .transport: transportLimitInCents
        case .leisure: leisureLimitInCents
        }
    }
}

@Model
final class BudgetNotificationRecord {
    @Attribute(.unique) var id: UUID
    var bucketRawValue: String
    var thresholdRawValue: String
    var weekStart: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        bucket: BudgetBucket,
        threshold: BudgetNotificationThreshold,
        weekStart: Date,
        createdAt: Date = .now
    ) {
        self.id = id
        self.bucketRawValue = bucket.rawValue
        self.thresholdRawValue = threshold.rawValue
        self.weekStart = weekStart
        self.createdAt = createdAt
    }
}
