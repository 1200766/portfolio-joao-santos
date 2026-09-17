import Foundation
import SwiftData

/// Only hypothetical data lives here. There are deliberately no relationships to real movements.
@Model
final class SimulationAdjustment {
    @Attribute(.unique) var id: UUID
    var sourceKey: String?
    var date: Date
    var details: String
    var amountInCents: Int
    var typeRawValue: String
    var isExcluded: Bool
    var updatedAt: Date

    var type: MovementType {
        get { MovementType(rawValue: typeRawValue) ?? .expense }
        set { typeRawValue = newValue.rawValue }
    }

    init(id: UUID = UUID(), sourceKey: String? = nil, date: Date,
         details: String, amountInCents: Int, type: MovementType,
         isExcluded: Bool = false, updatedAt: Date = .now) {
        self.id = id
        self.sourceKey = sourceKey
        self.date = date
        self.details = details
        self.amountInCents = amountInCents
        self.typeRawValue = type.rawValue
        self.isExcluded = isExcluded
        self.updatedAt = updatedAt
    }
}
