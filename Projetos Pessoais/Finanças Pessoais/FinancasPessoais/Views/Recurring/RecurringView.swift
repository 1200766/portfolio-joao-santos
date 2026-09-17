import SwiftData
import SwiftUI

struct RecurringView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecurringRule.nextDueDate) private var rules: [RecurringRule]
    @State private var isAdding = false
    @State private var ruleToEdit: RecurringRule?
    @State private var generationError: String?

    var body: some View {
        NavigationStack {
            Group {
                if rules.isEmpty {
                    ContentUnavailableView(
                        "Sem recorrentes",
                        systemImage: "repeat",
                        description: Text("Crie ganhos ou despesas semanais, de 2 em 2 semanas, de 3 em 3 semanas ou mensais.")
                    )
                } else {
                    List {
                        ForEach(rules) { rule in
                            Button { ruleToEdit = rule } label: {
                                recurringRow(rule)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Recorrentes")
            .toolbar {
                Button { isAdding = true } label: {
                    Label("Adicionar", systemImage: "plus")
                }
            }
            .task {
                do {
                    try RecurrenceService.generateDueMovements(in: modelContext)
                } catch {
                    generationError = error.localizedDescription
                }
            }
            .sheet(isPresented: $isAdding) {
                RecurringEditorView()
            }
            .sheet(item: $ruleToEdit) { rule in
                RecurringEditorView(rule: rule)
            }
            .alert("Erro ao processar recorrentes", isPresented: Binding(
                get: { generationError != nil },
                set: { if !$0 { generationError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(generationError ?? "Erro desconhecido")
            }
        }
    }

    private func recurringRow(_ rule: RecurringRule) -> some View {
        HStack(spacing: 12) {
            Image(systemName: rule.type == .income ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .font(.title3)
                .foregroundStyle(rule.type == .income ? .green : .red)
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.details).fontWeight(.medium)
                Text("\(rule.frequency.title) · próximo a \(rule.nextDueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !rule.isActive {
                    Text("Pausado").font(.caption).foregroundStyle(.orange)
                }
            }
            Spacer()
            Text(Money.formatted(cents: rule.amountInCents, type: rule.type))
                .font(.callout.monospacedDigit().weight(.semibold))
        }
    }

    private func delete(at offsets: IndexSet) {
        offsets.map { rules[$0] }.forEach(modelContext.delete)
        try? modelContext.save()
    }
}
