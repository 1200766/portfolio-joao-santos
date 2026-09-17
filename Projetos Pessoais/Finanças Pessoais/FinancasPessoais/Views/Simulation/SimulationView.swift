import SwiftData
import SwiftUI

/// A live, read-only baseline with a separate layer of hypothetical adjustments.
struct SimulationView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \BalanceSnapshot.referenceDate, order: .reverse) private var snapshots: [BalanceSnapshot]
    @Query(sort: \Movement.date) private var movements: [Movement]
    @Query(sort: \RecurringRule.nextDueDate) private var recurringRules: [RecurringRule]
    @Query private var recurringOverrides: [RecurringOverride]
    @Query private var budgetAssignments: [MovementBudgetAssignment]
    @Query(sort: \SimulationAdjustment.updatedAt) private var adjustments: [SimulationAdjustment]
    @State private var displayedMonth = Date.now
    @State private var selectedDay = Date.now
    @State private var referenceDate = Date.now
    @State private var editor: SimulationEditorRequest?
    @State private var confirmsReset = false
    @State private var errorMessage: String?

    private var calendar: Calendar { .current }
    private var today: Date { calendar.startOfDay(for: referenceDate) }
    private var monthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: displayedMonth)
            ?? DateInterval(start: displayedMonth, duration: 0)
    }
    private var monthEnd: Date {
        calendar.date(byAdding: .day, value: -1, to: monthInterval.end) ?? displayedMonth
    }
    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "pt_PT")))
    }
    private var result: SimulationResult {
        SimulationService.result(
            snapshot: snapshots.first, movements: movements,
            recurringRules: recurringRules, recurringOverrides: recurringOverrides,
            budgetAssignments: budgetAssignments,
            adjustments: adjustments, through: monthEnd, asOf: referenceDate, calendar: calendar
        )
    }

    var body: some View {
        let projection = result
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    introduction
                    balanceSummary(projection)
                    monthHeader
                    calendarGrid(projection)
                    dayDetails(projection)
                    if projection.inactiveAdjustmentCount > 0 {
                        Label {
                            Text("\(projection.inactiveAdjustmentCount) hipóteses ou alterações chegaram à data de hoje ou já passaram. Deixaram de afetar a previsão e não foram transformadas em movimentos reais.")
                        } icon: { Image(systemName: "clock") }
                        .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Simulador")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Adicionar hipótese", systemImage: "plus") { addHypothesis() }
                        Button("Voltar a hoje", systemImage: "calendar") {
                            refreshDate()
                            displayedMonth = referenceDate
                            selectedDay = referenceDate
                        }
                        Button("Repor simulação", systemImage: "arrow.counterclockwise", role: .destructive) {
                            confirmsReset = true
                        }
                        .disabled(adjustments.isEmpty)
                    } label: { Image(systemName: "ellipsis.circle") }
                    .accessibilityLabel("Opções do simulador")
                }
            }
            .sheet(item: $editor) { request in
                SimulationAdjustmentEditor(request: request) { savedDate in
                    selectedDay = savedDate
                    displayedMonth = savedDate
                }
            }
            .confirmationDialog("Repor a simulação?", isPresented: $confirmsReset, titleVisibility: .visible) {
                Button("Eliminar todas as hipóteses e alterações", role: .destructive) {
                    saveChange { adjustments.forEach { context.delete($0) } }
                }
                Button("Cancelar", role: .cancel) { }
            } message: {
                Text("Só serão eliminadas as experiências do simulador. O saldo, os movimentos, as recorrências e os objetivos reais não serão alterados.")
            }
            .alert("Não foi possível guardar", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "Tenta novamente.") }
            .onAppear { refreshDate() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { refreshDate() } }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refreshDate() }
        }
    }

    private var introduction: some View {
        Label {
            Text("Experimenta sem alterar o dinheiro real. As despesas associadas aos objetivos semanais não aparecem neste calendário nem entram nas projeções futuras. O saldo de partida continua a ser o saldo real de hoje, incluindo o que já gastaste.")
        } icon: { Image(systemName: "wand.and.stars") }
        .font(.subheadline).foregroundStyle(.secondary)
    }

    private func balanceSummary(_ projection: SimulationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            amountRow("Saldo real hoje", cents: projection.currentBalance)
            Divider()
            Text("No fim de \(monthTitle)").font(.headline)
            if monthEnd < today {
                Text("Este mês já terminou. O histórico está disponível abaixo; o saldo de hoje não permite reconstruir o saldo de um mês passado.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else if projection.currentBalance == nil {
                Text("Define primeiro o saldo no separador Início para veres as projeções. Podes consultar o calendário e preparar hipóteses entretanto.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                let baseline = projection.balance(on: monthEnd, simulated: false, calendar: calendar)
                let simulated = projection.balance(on: monthEnd, calendar: calendar)
                amountRow("Sem hipóteses", cents: baseline)
                amountRow("Com hipóteses", cents: simulated, emphasized: true)
                if let baseline, let simulated { amountRow("Diferença", cents: simulated - baseline) }
                Text("Inclui os movimentos futuros desde amanhã até ao último dia deste mês, exceto as despesas associadas aos objetivos semanais. Por isso, esta previsão pode diferir da apresentada no Início.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func amountRow(_ title: String, cents: Int?, emphasized: Bool = false) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                Spacer(minLength: 12)
                Text(cents.map { Money.formatted(cents: $0) } ?? "Por definir")
                    .monospacedDigit().fontWeight(emphasized ? .bold : .semibold)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(cents.map { Money.formatted(cents: $0) } ?? "Por definir")
                    .monospacedDigit().fontWeight(emphasized ? .bold : .semibold)
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Mês anterior")
            Spacer(minLength: 4)
            Text(monthTitle.capitalized).font(.headline).multilineTextAlignment(.center)
            Spacer(minLength: 4)
            Button { changeMonth(by: 1) } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Mês seguinte")
        }
    }

    private func calendarGrid(_ projection: SimulationResult) -> some View {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = max(calendar.firstWeekday - 1, 0)
        let orderedSymbols = Array(symbols[offset...]) + Array(symbols[..<offset])
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
            ForEach(Array(orderedSymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            }
            ForEach(Array(monthCells.enumerated()), id: \.offset) { _, date in
                if let date {
                    let entries = projection.entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDay)
                    let isToday = calendar.isDate(date, inSameDayAs: today)
                    Button { selectedDay = date } label: {
                        VStack(spacing: 5) {
                            Text(date, format: .dateTime.day()).font(.subheadline.weight(isToday ? .bold : .regular))
                            Circle().fill(entries.isEmpty ? Color.clear : Color.accentColor).frame(width: 5, height: 5)
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            if isToday { RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor, lineWidth: 1) }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                    .accessibilityValue("\(entries.count) movimentos\(isSelected ? ", selecionado" : "")")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                } else { Color.clear.frame(height: 48) }
            }
        }
    }

    private func dayDetails(_ projection: SimulationResult) -> some View {
        let entries = projection.entries.filter { calendar.isDate($0.date, inSameDayAs: selectedDay) }
        let selectedIsFuture = calendar.startOfDay(for: selectedDay) > today
        return VStack(alignment: .leading, spacing: 14) {
            Text(selectedDay.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "pt_PT"))))
                .font(.title3.weight(.semibold))
            if let balance = projection.balance(on: selectedDay, calendar: calendar) {
                amountRow(selectedIsFuture ? "Saldo simulado neste dia" : "Saldo real hoje", cents: balance)
            }
            if !selectedIsFuture {
                Text("Histórico real, só de leitura. Estes valores já estão refletidos no saldo atual e não são contabilizados outra vez na previsão.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if entries.isEmpty { Text("Sem movimentos neste dia.").foregroundStyle(.secondary) }
            ForEach(entries) { entry in
                entryRow(entry, editable: selectedIsFuture)
                Divider()
            }
            Button { addHypothesis() } label: {
                Label(selectedIsFuture ? "Adicionar hipótese neste dia" : "Adicionar hipótese futura", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
        }
    }

    private func entryRow(_ entry: SimulationEntry, editable: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.details).font(.body.weight(.medium)).strikethrough(entry.isExcluded)
                Text(entry.isExcluded ? "Excluído só da simulação" : entry.origin.rawValue)
                    .font(.caption).foregroundStyle(.secondary)
                Text(Money.formatted(cents: entry.amountInCents, type: entry.type))
                    .monospacedDigit().foregroundStyle(entry.isExcluded ? Color.secondary : (entry.type == .income ? .green : .primary))
            }
            Spacer(minLength: 4)
            if editable {
                Menu {
                    Button("Editar só na simulação", systemImage: "pencil") {
                        editor = SimulationEditorRequest(entry: entry, date: entry.date)
                    }
                    if entry.origin == .hypothesis {
                        Button("Eliminar hipótese", systemImage: "trash", role: .destructive) { restore(entry) }
                    } else {
                        if entry.adjustmentID != nil {
                            Button("Restaurar original", systemImage: "arrow.uturn.backward") { restore(entry) }
                        }
                        if !entry.isExcluded {
                            Button("Excluir só da simulação", systemImage: "minus.circle", role: .destructive) { exclude(entry) }
                        }
                    }
                } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                .accessibilityLabel("Opções para \(entry.details)")
            } else {
                Image(systemName: "lock").foregroundStyle(.secondary).accessibilityLabel("Só de leitura")
            }
        }
    }

    private var monthCells: [Date?] {
        guard let days = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let leading = (calendar.component(.weekday, from: monthInterval.start) - calendar.firstWeekday + 7) % 7
        let dates: [Date?] = days.map { calendar.date(byAdding: .day, value: $0 - 1, to: monthInterval.start) }
        return Array(repeating: nil, count: leading) + dates
    }

    private func changeMonth(by amount: Int) {
        guard let month = calendar.date(byAdding: .month, value: amount, to: monthInterval.start) else { return }
        displayedMonth = month
        selectedDay = calendar.isDate(month, equalTo: today, toGranularity: .month) ? today : month
    }

    private func refreshDate() {
        let previousToday = today
        let now = Date.now
        referenceDate = now
        if calendar.isDate(selectedDay, inSameDayAs: previousToday) {
            selectedDay = now
            displayedMonth = now
        }
    }

    private func addHypothesis() {
        let now = calendar.startOfDay(for: .now)
        let date = calendar.startOfDay(for: selectedDay) > now ? selectedDay
            : (calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        editor = SimulationEditorRequest(entry: nil, date: date)
    }

    private func restore(_ entry: SimulationEntry) {
        saveChange {
            // Remove duplicates too, so an older edit cannot reappear for the same occurrence.
            adjustments.filter { $0.id == entry.adjustmentID || $0.sourceKey == entry.id }
                .forEach { context.delete($0) }
        }
    }

    private func exclude(_ entry: SimulationEntry) {
        guard calendar.startOfDay(for: entry.date) > calendar.startOfDay(for: .now) else { return }
        saveChange {
            let matches = adjustments.filter { $0.sourceKey == entry.id }
            let existing = matches.first { $0.id == entry.adjustmentID } ?? matches.last
            if let existing {
                existing.isExcluded = true
                existing.updatedAt = .now
                matches.filter { $0.id != existing.id }.forEach { context.delete($0) }
            } else {
                context.insert(SimulationAdjustment(
                    sourceKey: entry.id, date: entry.date, details: entry.details,
                    amountInCents: entry.amountInCents, type: entry.type, isExcluded: true
                ))
            }
        }
    }

    private func saveChange(_ change: () -> Void) {
        change()
        do { try context.save() }
        catch {
            context.rollback()
            errorMessage = "A simulação não foi alterada. Tenta novamente."
        }
    }
}

private struct SimulationEditorRequest: Identifiable {
    let id = UUID()
    let entry: SimulationEntry?
    let date: Date
}

private struct SimulationAdjustmentEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SimulationAdjustment.updatedAt) private var adjustments: [SimulationAdjustment]
    let request: SimulationEditorRequest
    let onSave: (Date) -> Void
    @State private var details: String
    @State private var amount: String
    @State private var type: MovementType
    @State private var date: Date
    @State private var errorMessage: String?

    init(request: SimulationEditorRequest, onSave: @escaping (Date) -> Void) {
        self.request = request
        self.onSave = onSave
        _details = State(initialValue: request.entry?.details ?? "")
        let cents = request.entry?.amountInCents
        _amount = State(initialValue: cents.map { "\($0 / 100),\(String(format: "%02d", $0 % 100))" } ?? "")
        _type = State(initialValue: request.entry?.type ?? .expense)
        _date = State(initialValue: request.date)
    }

    private var imported: Bool { request.entry.map { $0.origin != .hypothesis } ?? false }
    private var tomorrow: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
    }
    private var valid: Bool {
        guard let cents = WeeklyBudgetService.limitCents(from: amount), cents > 0 else { return false }
        return !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && date >= tomorrow
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Só no simulador") {
                    TextField("Descrição", text: $details)
                    TextField("Valor em euros", text: $amount).keyboardType(.decimalPad)
                    Picker("Tipo", selection: $type) {
                        ForEach(MovementType.allCases) { value in Text(value.title).tag(value) }
                    }
                    if imported {
                        LabeledContent("Data do movimento") { Text(date, format: .dateTime.day().month().year()) }
                    } else {
                        DatePicker("Data futura", selection: $date, in: tomorrow..., displayedComponents: .date)
                    }
                }
                Section {
                    Text(imported
                         ? "Esta alteração afeta apenas esta ocorrência no simulador. A data original mantém-se e a recorrência real não muda."
                         : "Esta hipótese não cria uma despesa nem um ganho real. Quando chegar a data, deixa de afetar a previsão; regista o movimento real na aplicação se acontecer.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("O nome é obrigatório e o valor deve ser superior a zero, com no máximo duas casas decimais.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(imported ? "Ajustar ocorrência" : "Hipótese")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { save() }.disabled(!valid) }
            }
            .alert("Não foi possível guardar", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "Tenta novamente.") }
        }
    }

    private func save() {
        guard valid, let cents = WeeklyBudgetService.limitCents(from: amount) else {
            errorMessage = "Confirma o nome, um valor positivo e uma data posterior a hoje."
            return
        }
        let sourceKey = imported ? request.entry?.id : nil
        let matches = adjustments.filter { adjustment in
            if let sourceKey { return adjustment.sourceKey == sourceKey }
            return adjustment.id == request.entry?.adjustmentID
        }
        let existing = matches.first { $0.id == request.entry?.adjustmentID } ?? matches.last
        let name = details.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing {
            existing.date = imported ? request.date : date
            existing.details = name
            existing.amountInCents = cents
            existing.type = type
            existing.isExcluded = false
            existing.updatedAt = .now
            matches.filter { $0.id != existing.id }.forEach { context.delete($0) }
        } else {
            context.insert(SimulationAdjustment(
                sourceKey: sourceKey, date: imported ? request.date : date,
                details: name, amountInCents: cents, type: type
            ))
        }
        do {
            try context.save()
            onSave(imported ? request.date : date)
            dismiss()
        } catch {
            context.rollback()
            errorMessage = "A hipótese não foi guardada. Os registos reais não foram alterados."
        }
    }
}
