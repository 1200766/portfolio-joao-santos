import SwiftData
import SwiftUI

struct RecurringEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FinanceCategory.name) private var categories: [FinanceCategory]
    @Query private var overrides: [RecurringOverride]

    let rule: RecurringRule?
    let sourceMovement: Movement?
    @State private var details: String
    @State private var amount: String
    @State private var type: MovementType
    @State private var frequency: RecurrenceFrequency
    @State private var nextDueDate: Date
    @State private var category: FinanceCategory?
    @State private var isActive: Bool
    @State private var nextIncomeAmount = ""
    @State private var validationMessage: String?

    init(rule: RecurringRule? = nil, sourceMovement: Movement? = nil) {
        self.rule = rule
        self.sourceMovement = sourceMovement
        let startingDate = sourceMovement?.date ?? .now
        let firstMonthlyDate = Calendar.current.date(byAdding: .month, value: 1, to: startingDate) ?? startingDate
        _details = State(initialValue: rule?.details ?? sourceMovement?.details ?? "")
        _amount = State(initialValue: (rule?.amountInCents ?? sourceMovement?.amountInCents).map {
            Money.inputValue(cents: $0)
        } ?? "")
        _type = State(initialValue: rule?.type ?? sourceMovement?.type ?? .expense)
        _frequency = State(initialValue: rule?.frequency ?? .monthly)
        _nextDueDate = State(initialValue: rule?.nextDueDate ?? (sourceMovement == nil ? .now : firstMonthlyDate))
        _category = State(initialValue: rule?.category ?? sourceMovement?.category)
        _isActive = State(initialValue: rule?.isActive ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let sourceMovement {
                    Section {
                        Text("O movimento de \(sourceMovement.date.formatted(date: .long, time: .omitted)) permanece inalterado. A primeira nova ocorrência será criada na data abaixo.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Regra") {
                    TextField("Descrição", text: $details)
                    TextField("Valor habitual", text: $amount)
                        .keyboardType(.decimalPad)
                    Picker("Tipo", selection: $type) {
                        ForEach(MovementType.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    Picker("Frequência", selection: $frequency) {
                        ForEach(RecurrenceFrequency.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    DatePicker("Próxima data", selection: $nextDueDate, displayedComponents: .date)
                    Picker("Categoria", selection: $category) {
                        Text("Sem categoria").tag(nil as FinanceCategory?)
                        ForEach(categories) { item in
                            Text(item.name).tag(item as FinanceCategory?)
                        }
                    }
                    Toggle("Ativo", isOn: $isActive)
                }

                if type == .income, frequency.weekInterval != nil {
                    Section("Valor real da próxima ocorrência") {
                        TextField("Deixar vazio para usar o habitual", text: $nextIncomeAmount)
                            .keyboardType(.decimalPad)
                        Text("Aplica-se apenas a \(nextDueDate.formatted(date: .long, time: .omitted)). Os movimentos anteriores não são alterados.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let validationMessage {
                    Section { Text(validationMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save).fontWeight(.semibold)
                }
            }
            .onAppear(perform: loadOverride)
            .onChange(of: frequency) { _, newFrequency in
                guard let sourceMovement else { return }
                nextDueDate = RecurrenceService.nextDate(
                    after: sourceMovement.date,
                    frequency: newFrequency
                ) ?? sourceMovement.date
            }
        }
    }

    private var navigationTitle: String {
        if sourceMovement != nil { return "Tornar recorrente" }
        return rule == nil ? "Novo recorrente" : "Editar recorrente"
    }

    private func loadOverride() {
        guard let rule else { return }
        let calendar = Calendar.current
        if let existing = overrides.first(where: {
            $0.recurringRuleID == rule.id && calendar.isDate($0.occurrenceDate, inSameDayAs: rule.nextDueDate)
        }) {
            nextIncomeAmount = Money.inputValue(cents: existing.amountInCents)
        }
    }

    private func save() {
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDetails.isEmpty else {
            validationMessage = "Indique uma descrição."
            return
        }
        guard let amountInCents = Money.cents(from: amount), amountInCents > 0 else {
            validationMessage = "Indique um valor habitual superior a zero."
            return
        }
        let trimmedNextAmount = nextIncomeAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        if type == .income, frequency.weekInterval != nil, !trimmedNextAmount.isEmpty {
            guard let nextAmount = Money.cents(from: trimmedNextAmount), nextAmount > 0 else {
                validationMessage = "Indique um valor superior a zero para a próxima ocorrência ou deixe o campo vazio."
                return
            }
        }
        if let sourceMovement,
           Calendar.current.startOfDay(for: nextDueDate) <= Calendar.current.startOfDay(for: sourceMovement.date) {
            validationMessage = "A primeira nova ocorrência deve ser posterior ao movimento original."
            return
        }

        let savedRule: RecurringRule
        if let rule {
            rule.details = trimmedDetails
            rule.amountInCents = amountInCents
            rule.type = type
            rule.frequency = frequency
            rule.nextDueDate = nextDueDate
            rule.category = category
            rule.isActive = isActive
            savedRule = rule
        } else {
            let newRule = RecurringRule(
                details: trimmedDetails,
                amountInCents: amountInCents,
                type: type,
                frequency: frequency,
                nextDueDate: nextDueDate,
                category: category,
                isActive: isActive
            )
            modelContext.insert(newRule)
            savedRule = newRule
        }

        replaceOverride(for: savedRule)

        do {
            if let sourceMovement {
                sourceMovement.sourceRecurringRuleID = savedRule.id
                sourceMovement.occurrenceDate = sourceMovement.date
            }
            try modelContext.save()
            try RecurrenceService.generateDueMovements(in: modelContext)
            dismiss()
        } catch {
            validationMessage = "Não foi possível guardar: \(error.localizedDescription)"
        }
    }

    private func replaceOverride(for rule: RecurringRule) {
        overrides
            .filter { $0.recurringRuleID == rule.id }
            .forEach(modelContext.delete)

        let trimmed = nextIncomeAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard type == .income,
              frequency.weekInterval != nil,
              !trimmed.isEmpty,
              let cents = Money.cents(from: trimmed),
              cents > 0 else { return }

        modelContext.insert(RecurringOverride(
            recurringRuleID: rule.id,
            occurrenceDate: nextDueDate,
            amountInCents: cents
        ))
    }
}
