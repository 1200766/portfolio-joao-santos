import SwiftData
import SwiftUI

struct CategorizationRulesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CategorizationRule.keyword) private var rules: [CategorizationRule]
    @State private var isAdding = false
    @State private var ruleToEdit: CategorizationRule?

    var body: some View {
        List {
            ForEach(rules) { rule in
                Button { ruleToEdit = rule } label: {
                    HStack {
                        Text(rule.keyword)
                        Spacer()
                        Text(rule.category?.name ?? "Sem categoria")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: delete)
        }
        .overlay {
            if rules.isEmpty {
                ContentUnavailableView("Sem regras", systemImage: "wand.and.stars")
            }
        }
        .navigationTitle("Regras automáticas")
        .toolbar {
            Button { isAdding = true } label: {
                Label("Adicionar", systemImage: "plus")
            }
        }
        .sheet(isPresented: $isAdding) {
            CategorizationRuleEditorView()
        }
        .sheet(item: $ruleToEdit) { rule in
            CategorizationRuleEditorView(rule: rule)
        }
    }

    private func delete(at offsets: IndexSet) {
        offsets.map { rules[$0] }.forEach(modelContext.delete)
        try? modelContext.save()
    }
}

private struct CategorizationRuleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FinanceCategory.name) private var categories: [FinanceCategory]
    let rule: CategorizationRule?
    @State private var keyword: String
    @State private var category: FinanceCategory?
    @State private var errorMessage: String?

    init(rule: CategorizationRule? = nil) {
        self.rule = rule
        _keyword = State(initialValue: rule?.keyword ?? "")
        _category = State(initialValue: rule?.category)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Palavra ou descrição", text: $keyword)
                    .textInputAutocapitalization(.never)
                Picker("Categoria", selection: $category) {
                    Text("Escolher").tag(nil as FinanceCategory?)
                    ForEach(categories) { item in
                        Text(item.name).tag(item as FinanceCategory?)
                    }
                }
                Text("A comparação ignora maiúsculas e acentos e procura esta palavra dentro da descrição.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle(rule == nil ? "Nova regra" : "Editar regra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save).fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let category else {
            errorMessage = "Indique uma palavra e escolha uma categoria."
            return
        }

        if let rule {
            rule.keyword = trimmed
            rule.category = category
        } else {
            modelContext.insert(CategorizationRule(keyword: trimmed, category: category))
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
