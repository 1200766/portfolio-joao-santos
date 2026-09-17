import SwiftUI

struct MovementRow: View {
    let movement: Movement
    var showsDate = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: movement.type == .income ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .font(.title3)
                .foregroundStyle(movement.type == .income ? .green : .red)

            VStack(alignment: .leading, spacing: 3) {
                Text(movement.details)
                    .font(.body.weight(.medium))
                HStack(spacing: 6) {
                    Text(movement.category?.name ?? "Sem categoria")
                    if showsDate {
                        Text("·")
                        Text(movement.date, format: .dateTime.day().month(.abbreviated))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
            Text(Money.formatted(cents: movement.amountInCents, type: movement.type))
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(movement.type == .income ? .green : .primary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ProjectedMovementRow: View {
    let occurrence: ProjectedOccurrence

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: occurrence.rule.type == .income ? "arrow.down.circle" : "arrow.up.circle")
                .font(.title3)
                .foregroundStyle(occurrence.rule.type == .income ? .green : .red)

            VStack(alignment: .leading, spacing: 3) {
                Text(occurrence.rule.details)
                    .font(.body.weight(.medium))
                Text("\(occurrence.rule.category?.name ?? "Sem categoria") · Recorrente")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Text(Money.formatted(
                cents: occurrence.rule.amountInCents,
                type: occurrence.rule.type
            ))
            .font(.body.monospacedDigit().weight(.semibold))
            .foregroundStyle(occurrence.rule.type == .income ? .green : .primary)
        }
        .accessibilityElement(children: .combine)
    }
}
