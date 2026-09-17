import SwiftData
import SwiftUI

struct MovementsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Movement.date, order: .reverse) private var movements: [Movement]
    @Query private var budgetAssignments: [MovementBudgetAssignment]
    @State private var presentedMovement: Movement?
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            Group {
                if movements.isEmpty {
                    ContentUnavailableView(
                        "Sem movimentos",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Adicione o primeiro ganho ou despesa.")
                    )
                } else {
                    List {
                        ForEach(movements) { movement in
                            Button { presentedMovement = movement } label: {
                                MovementRow(movement: movement, showsDate: true)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Movimentos")
            .toolbar {
                Button { isAdding = true } label: {
                    Label("Adicionar", systemImage: "plus")
                }
            }
            .sheet(isPresented: $isAdding) {
                MovementEditorView()
            }
            .sheet(item: $presentedMovement) { movement in
                MovementEditorView(movement: movement)
            }
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
