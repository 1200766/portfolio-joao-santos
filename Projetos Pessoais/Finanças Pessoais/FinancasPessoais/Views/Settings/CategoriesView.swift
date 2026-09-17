import SwiftData
import SwiftUI

struct CategoriesView: View {
    @Query(sort: \FinanceCategory.name) private var categories: [FinanceCategory]
    @State private var isAdding = false
    @State private var categoryToEdit: FinanceCategory?
    @State private var categoryToDelete: FinanceCategory?

    var body: some View {
        List {
            ForEach(categories) { category in
                Button { categoryToEdit = category } label: {
                    Label(category.name, systemImage: "tag")
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Eliminar", role: .destructive) {
                        categoryToDelete = category
                    }
                }
            }
        }
        .overlay {
            if categories.isEmpty {
                ContentUnavailableView("Sem categorias", systemImage: "tag.slash")
            }
        }
        .navigationTitle("Categorias")
        .toolbar {
            Button { isAdding = true } label: {
                Label("Adicionar", systemImage: "plus")
            }
        }
        .sheet(isPresented: $isAdding) {
            CategoryEditorView()
        }
        .sheet(item: $categoryToEdit) { category in
            CategoryEditorView(category: category)
        }
        .sheet(item: $categoryToDelete) { category in
            CategoryDeletionView(category: category)
        }
    }
}

private struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allCategories: [FinanceCategory]
    let category: FinanceCategory?
    @State private var name: String
    @State private var errorMessage: String?

    init(category: FinanceCategory? = nil) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nome", text: $name)
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle(category == nil ? "Nova categoria" : "Editar categoria")
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
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Indique um nome."
            return
        }
        let normalized = CategorizationService.normalize(trimmed)
        guard !allCategories.contains(where: {
            $0.id != category?.id && CategorizationService.normalize($0.name) == normalized
        }) else {
            errorMessage = "Já existe uma categoria com este nome."
            return
        }

        if let category {
            category.name = trimmed
        } else {
            modelContext.insert(FinanceCategory(name: trimmed))
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CategoryDeletionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var movements: [Movement]
    @Query private var recurringRules: [RecurringRule]
    @Query private var categorizationRules: [CategorizationRule]
    @Query(sort: \FinanceCategory.name) private var categories: [FinanceCategory]

    let category: FinanceCategory
    @State private var replacementID: UUID?
    @State private var errorMessage: String?

    private var affectedMovements: [Movement] {
        movements.filter { $0.category?.id == category.id }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(affectedDescription)
                }

                Section("Destino") {
                    Picker("Transferir para", selection: $replacementID) {
                        Text("Deixar sem categoria").tag(nil as UUID?)
                        ForEach(categories.filter { $0.id != category.id }) { option in
                            Text(option.name).tag(option.id as UUID?)
                        }
                    }
                }

                Section {
                    Button("Eliminar categoria", role: .destructive, action: deleteCategory)
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Eliminar \(category.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    private var affectedDescription: String {
        if affectedMovements.isEmpty {
            return "A categoria não está associada a movimentos. As regras associadas serão transferidas ou removidas em segurança."
        }
        return "Esta categoria é usada por \(affectedMovements.count) movimento(s). Escolha outra categoria ou mantenha esses movimentos sem categoria. Nenhum movimento será apagado."
    }

    private func deleteCategory() {
        let replacement = categories.first { $0.id == replacementID }
        movements.filter { $0.category?.id == category.id }.forEach { $0.category = replacement }
        recurringRules.filter { $0.category?.id == category.id }.forEach { $0.category = replacement }

        let affectedRules = categorizationRules.filter { $0.category?.id == category.id }
        if let replacement {
            affectedRules.forEach { $0.category = replacement }
        } else {
            affectedRules.forEach(modelContext.delete)
        }

        modelContext.delete(category)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Não foi possível eliminar: \(error.localizedDescription)"
        }
    }
}
