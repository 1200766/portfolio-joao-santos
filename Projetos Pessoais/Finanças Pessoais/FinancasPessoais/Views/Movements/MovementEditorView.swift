import SwiftData
import SwiftUI

struct MovementEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FinanceCategory.name) private var categories: [FinanceCategory]
    @Query(sort: \CategorizationRule.createdAt) private var categorizationRules: [CategorizationRule]
    @Query(sort: \RecurringRule.createdAt) private var recurringRules: [RecurringRule]
    @Query private var budgetAssignments: [MovementBudgetAssignment]

    let movement: Movement?
    let initialDate: Date

    @State private var date: Date
    @State private var details: String
    @State private var amount: String
    @State private var type: MovementType
    @State private var category: FinanceCategory?
    @State private var categoryWasChosen = false
    @State private var saveAssociation = false
    @State private var associationKeyword = ""
    @State private var validationMessage: String?
    @State private var isCreatingRecurrence = false
    @State private var recurringRuleToEdit: RecurringRule?
    @State private var budgetAssociation: BudgetAssociationSelection = .automatic

    init(movement: Movement? = nil, initialDate: Date = .now) {
        self.movement = movement
        self.initialDate = initialDate
        _date = State(initialValue: movement?.date ?? initialDate)
        _details = State(initialValue: movement?.details ?? "")
        _amount = State(initialValue: movement.map { Money.inputValue(cents: $0.amountInCents) } ?? "")
        _type = State(initialValue: movement?.type ?? .expense)
        _category = State(initialValue: movement?.category)
        _categoryWasChosen = State(initialValue: movement != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Movimento") {
                    TextField("Descrição", text: $details)
                        .onChange(of: details) { _, newValue in
                            guard !categoryWasChosen else { return }
                            category = CategorizationService.category(for: newValue, rules: categorizationRules)
                        }
                    TextField("Valor", text: $amount)
                        .keyboardType(.decimalPad)
                    DatePicker("Data", selection: $date, displayedComponents: .date)
                    Picker("Tipo", selection: $type) {
                        ForEach(MovementType.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }

                Section("Categoria") {
                    Picker("Categoria", selection: $category) {
                        Text("Sem categoria").tag(nil as FinanceCategory?)
                        ForEach(categories) { item in
                            Text(item.name).tag(item as FinanceCategory?)
                        }
                    }
                    .onChange(of: category) { _, _ in categoryWasChosen = true }

                    Toggle("Reutilizar esta associação", isOn: $saveAssociation)
                    if saveAssociation {
                        TextField("Palavra ou descrição", text: $associationKeyword)
                            .textInputAutocapitalization(.never)
                        Text("Exemplo: usar “padaria” para escolher esta categoria no futuro.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if type == .expense {
                    Section("Orçamento semanal") {
                        Picker("Objetivo", selection: $budgetAssociation) {
                            ForEach(BudgetAssociationSelection.allCases) { selection in
                                Text(selection.title).tag(selection)
                            }
                        }

                        if budgetAssociation == .automatic {
                            Text(automaticBudgetDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Esta escolha corrige a associação apenas para este movimento.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if movement != nil {
                    Section("Recorrência") {
                        if let associatedRecurringRule {
                            Button {
                                recurringRuleToEdit = associatedRecurringRule
                            } label: {
                                Label("Editar recorrência", systemImage: "repeat")
                            }
                            Text("Este movimento está associado a uma regra \(associatedRecurringRule.frequency.title.lowercased()).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Button(action: makeRecurring) {
                                Label("Tornar recorrente", systemImage: "repeat")
                            }
                            Text("Cria uma regra semanal, de duas ou três semanas, ou mensal, sem duplicar o lançamento atual.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let validationMessage {
                    Section {
                        Text(validationMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(movement == nil ? "Novo movimento" : "Editar movimento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $isCreatingRecurrence) {
                if let movement {
                    RecurringEditorView(sourceMovement: movement)
                }
            }
            .sheet(item: $recurringRuleToEdit) { rule in
                RecurringEditorView(rule: rule)
            }
            .onAppear(perform: loadBudgetAssociation)
        }
    }

    private var associatedRecurringRule: RecurringRule? {
        guard let recurringRuleID = movement?.sourceRecurringRuleID else { return nil }
        return recurringRules.first { $0.id == recurringRuleID }
    }

    private var automaticBudgetDescription: String {
        if let bucket = WeeklyBudgetService.automaticBucket(forCategoryNamed: category?.name) {
            return "Será contabilizado automaticamente em \(bucket.title)."
        }
        return "A categoria atual não corresponde automaticamente a um objetivo semanal."
    }

    private func loadBudgetAssociation() {
        guard let movement,
              let assignment = budgetAssignments.first(where: { $0.movementID == movement.id }) else {
            return
        }
        budgetAssociation = assignment.selection
    }

    private func save() {
        _ = persistMovement(dismissAfterSaving: true)
    }

    private func makeRecurring() {
        if persistMovement(dismissAfterSaving: false) {
            isCreatingRecurrence = true
        }
    }

    @discardableResult
    private func persistMovement(dismissAfterSaving: Bool) -> Bool {
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDetails.isEmpty else {
            validationMessage = "Indique uma descrição."
            return false
        }
        guard let amountInCents = Money.cents(from: amount), amountInCents > 0 else {
            validationMessage = "Indique um valor superior a zero."
            return false
        }

        let savedMovement: Movement
        if let movement {
            movement.date = date
            movement.details = trimmedDetails
            movement.amountInCents = amountInCents
            movement.type = type
            movement.category = category
            savedMovement = movement
        } else {
            let newMovement = Movement(
                date: date,
                details: trimmedDetails,
                amountInCents: amountInCents,
                type: type,
                category: category
            )
            modelContext.insert(newMovement)
            savedMovement = newMovement
        }

        saveBudgetAssociation(for: savedMovement)

        let keyword = associationKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if saveAssociation, !keyword.isEmpty, let category {
            modelContext.insert(CategorizationRule(keyword: keyword, category: category))
            saveAssociation = false
            associationKeyword = ""
        }

        do {
            try modelContext.save()
            validationMessage = nil
            if dismissAfterSaving {
                dismiss()
            }
            return true
        } catch {
            validationMessage = "Não foi possível guardar: \(error.localizedDescription)"
            return false
        }
    }

    private func saveBudgetAssociation(for movement: Movement) {
        let existingAssignment = budgetAssignments.first { $0.movementID == movement.id }
        if budgetAssociation == .automatic {
            if let existingAssignment {
                modelContext.delete(existingAssignment)
            }
        } else if let existingAssignment {
            existingAssignment.selection = budgetAssociation
        } else {
            modelContext.insert(MovementBudgetAssignment(
                movementID: movement.id,
                selection: budgetAssociation
            ))
        }
    }
}
