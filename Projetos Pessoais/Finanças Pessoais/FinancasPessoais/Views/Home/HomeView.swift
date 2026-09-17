import SwiftData
import SwiftUI

struct HomeView: View {
    @Query(sort: \BalanceSnapshot.referenceDate, order: .reverse)
    private var snapshots: [BalanceSnapshot]
    @Query(sort: \Movement.createdAt)
    private var movements: [Movement]
    @Query(sort: \RecurringRule.nextDueDate)
    private var recurringRules: [RecurringRule]
    @Query(sort: \RecurringOverride.occurrenceDate)
    private var recurringOverrides: [RecurringOverride]
    @State private var isEditingBalance = false

    private var currentSnapshot: BalanceSnapshot? {
        snapshots.first
    }

    private var currentBalance: Int? {
        BalanceService.currentBalance(
            snapshot: currentSnapshot,
            movements: movements
        )
    }

    private var monthEndForecast: Int? {
        BalanceService.monthEndForecast(
            snapshot: currentSnapshot,
            movements: movements,
            recurringRules: recurringRules,
            recurringOverrides: recurringOverrides
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 24) {
                    balanceValue(
                        title: "Saldo bancário atual",
                        value: currentBalance,
                        accessibilityLabel: "Saldo bancário atual"
                    )

                    Divider()

                    balanceValue(
                        title: "Previsão no fim do mês",
                        value: monthEndForecast,
                        accessibilityLabel: "Previsão no fim do mês"
                    )

                    if currentSnapshot == nil {
                        Text("Defina o saldo que tem atualmente no banco.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))

                Button {
                    isEditingBalance = true
                } label: {
                    Text(currentSnapshot == nil ? "Definir saldo atual" : "Redefinir saldo atual")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if currentSnapshot != nil {
                    Text("A previsão parte do saldo atual e inclui movimentos futuros e recorrências previstas até ao último dia deste mês.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Início")
            .sheet(isPresented: $isEditingBalance) {
                BalanceSnapshotEditorView(currentBalance: currentBalance)
            }
        }
    }

    @ViewBuilder
    private func balanceValue(
        title: String,
        value: Int?,
        accessibilityLabel: String
    ) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(value.map { Money.formatted(cents: $0) } ?? "—")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityValue(value.map { Money.formatted(cents: $0) } ?? "Por definir")
        }
    }
}

private struct BalanceSnapshotEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let currentBalance: Int?
    @State private var amount: String
    @State private var validationMessage: String?

    init(currentBalance: Int?) {
        self.currentBalance = currentBalance
        _amount = State(initialValue: currentBalance.map {
            Money.inputValue(cents: $0)
        } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Saldo atual") {
                    TextField("Valor em euros", text: $amount)
                        .keyboardType(.numbersAndPunctuation)
                    Text("Este valor cria um novo ponto de referência. Os movimentos anteriores não voltam a ser contados e o histórico não é apagado.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let validationMessage {
                    Section {
                        Text(validationMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(currentBalance == nil ? "Definir saldo" : "Redefinir saldo")
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
        }
    }

    private func save() {
        guard let amountInCents = Money.signedCents(from: amount) else {
            validationMessage = "Indique um saldo válido."
            return
        }

        let referenceDate = Date.now
        modelContext.insert(BalanceSnapshot(
            amountInCents: amountInCents,
            referenceDate: referenceDate,
            createdAt: referenceDate
        ))

        do {
            try modelContext.save()
            dismiss()
        } catch {
            validationMessage = "Não foi possível guardar: \(error.localizedDescription)"
        }
    }
}
