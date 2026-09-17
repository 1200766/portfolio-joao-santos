import SwiftData
import SwiftUI

struct DayDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var movements: [Movement]
    @Query(sort: \RecurringRule.nextDueDate) private var recurringRules: [RecurringRule]
    @Query private var budgetAssignments: [MovementBudgetAssignment]
    let date: Date
    @State private var isAdding = false
    @State private var movementToEdit: Movement?
    @State private var recurringRuleToEdit: RecurringRule?

    init(date: Date) {
        self.date = date
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        _movements = Query(
            filter: #Predicate<Movement> { $0.date >= start && $0.date < end },
            sort: [SortDescriptor(\Movement.createdAt)]
        )
    }

    var body: some View {
        Group {
            if movements.isEmpty, projectedOccurrences.isEmpty {
                ContentUnavailableView(
                    "Sem movimentos",
                    systemImage: "calendar.badge.plus",
                    description: Text("Não existem movimentos neste dia.")
                )
            } else {
                List {
                    if !movements.isEmpty {
                        Section("Confirmados") {
                            ForEach(movements) { movement in
                                Button { movementToEdit = movement } label: {
                                    MovementRow(movement: movement)
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete(perform: delete)
                        }
                    }

                    if !projectedOccurrences.isEmpty {
                        Section("Recorrentes previstos") {
                            ForEach(projectedOccurrences) { occurrence in
                                Button { recurringRuleToEdit = occurrence.rule } label: {
                                    ProjectedMovementRow(occurrence: occurrence)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Section("Resumo") {
                        LabeledContent("Saldo", value: Money.formatted(cents: dailyBalance))
                    }
                }
            }
        }
        .navigationTitle(date.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "pt_PT"))))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button { isAdding = true } label: {
                Label("Adicionar", systemImage: "plus")
            }
        }
        .sheet(isPresented: $isAdding) {
            MovementEditorView(initialDate: date)
        }
        .sheet(item: $movementToEdit) { movement in
            MovementEditorView(movement: movement)
        }
        .sheet(item: $recurringRuleToEdit) { rule in
            RecurringEditorView(rule: rule)
        }
    }

    private var projectedOccurrences: [ProjectedOccurrence] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return RecurrenceService.projectedOccurrences(
            for: recurringRules,
            in: DateInterval(start: start, end: end),
            excluding: movements,
            calendar: calendar
        )
    }

    private var dailyBalance: Int {
        let confirmed = movements.reduce(0) { result, movement in
            result + (movement.type == .income ? movement.amountInCents : -movement.amountInCents)
        }
        return projectedOccurrences.reduce(confirmed) { result, occurrence in
            result + (occurrence.rule.type == .income ? occurrence.rule.amountInCents : -occurrence.rule.amountInCents)
        }
    }

    private func delete(at offsets: IndexSet) {
        let deletedMovements = offsets.map { movements[$0] }
        let deletedIDs = Set(deletedMovements.map(\.id))
        budgetAssignments
            .filter { deletedIDs.contains($0.movementID) }
            .forEach(modelContext.delete)
        deletedMovements.forEach(modelContext.delete)
        try? modelContext.save()
    }
}
