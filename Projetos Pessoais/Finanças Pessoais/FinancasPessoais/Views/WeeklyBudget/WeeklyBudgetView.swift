import SwiftData
import SwiftUI
import UserNotifications

struct WeeklyBudgetView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Movement.date) private var movements: [Movement]
    @Query private var assignments: [MovementBudgetAssignment]
    @Query private var plans: [WeeklyBudgetPlan]
    @AppStorage("weeklyBudget.reminderHour") private var reminderHour = 18
    @AppStorage("weeklyBudget.reminderMinute") private var reminderMinute = 0
    @State private var displayedWeek = Date.now
    @State private var now = Date.now
    @State private var editingWeek = Date.now
    @State private var showEditor = false
    @State private var showReminder = false
    @State private var notificationAllowed: Bool?

    private var calendar: Calendar { WeeklyBudgetService.calendar() }
    private var selectedKey: String { WeeklyBudgetService.weekKey(containing: displayedWeek) }
    private var plan: WeeklyBudgetPlan? { plans.first { $0.weekKey == selectedKey } }
    private var progresses: [WeeklyBudgetProgress] {
        WeeklyBudgetService.progress(
            for: displayedWeek, movements: movements, assignments: assignments,
            plan: plan, asOf: now, calendar: calendar
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    weekHeader
                    configurationCard
                    totalCard
                    ForEach(progresses) { budgetCard($0) }
                    reminderCard
                }
                .padding()
            }
            .navigationTitle("Semana")
            .sheet(isPresented: $showEditor) { WeeklyBudgetEditorView(week: editingWeek) }
            .sheet(isPresented: $showReminder, onDismiss: { Task { await updatePermission() } }) {
                WeeklyReminderEditorView()
            }
            .task { refreshDay(); await updatePermission() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refreshDay(); Task { await updatePermission() } }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refreshDay() }
        }
    }

    private var weekHeader: some View {
        HStack {
            Button { changeWeek(by: -1) } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }.accessibilityLabel("Semana anterior")
            Spacer()
            Text(WeeklyBudgetService.title(for: displayedWeek)).font(.headline)
            Spacer()
            Button { changeWeek(by: 1) } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }.accessibilityLabel("Semana seguinte")
        }
    }

    private var configurationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(plan == nil ? "Limites por definir" : "Limites confirmados",
                  systemImage: plan == nil ? "calendar.badge.exclamationmark" : "checkmark.circle")
                .font(.headline)
            Text(plan == nil
                 ? "Esta semana não tem limites ativos. Os gastos continuam registados, mas não há alertas de orçamento até confirmares os valores."
                 : "Estes limites aplicam-se apenas à semana selecionada. Na semana seguinte, é necessário confirmar novamente.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button(plan == nil ? "Definir limites desta semana" : "Editar limites desta semana") {
                editingWeek = displayedWeek
                showEditor = true
            }.buttonStyle(.borderedProminent)
            if calendar.component(.weekday, from: now) == 1,
               selectedKey == WeeklyBudgetService.weekKey(containing: now),
               let monday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
                Button("Preparar a próxima semana") { editingWeek = monday; showEditor = true }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var totalCard: some View {
        let spent = progresses.reduce(0) { $0 + $1.spentInCents }
        return VStack(spacing: 10) {
            LabeledContent("Limite total", value: plan.map { Money.formatted(cents: $0.totalLimitInCents) } ?? "Por definir")
            LabeledContent("Gasto nos objetivos", value: Money.formatted(cents: spent))
            if let plan { remainingRow(spent: spent, limit: plan.totalLimitInCents) }
        }
        .font(.body.weight(.medium))
        .padding()
        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
    }

    private func budgetCard(_ progress: WeeklyBudgetProgress) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(progress.bucket.title).font(.title3.weight(.semibold))
                Spacer()
                Text(progress.limitInCents.map { "Limite \(Money.formatted(cents: $0))" } ?? "Sem limite ativo")
                    .font(.caption).foregroundStyle(.secondary)
            }
            LabeledContent("Gasto", value: Money.formatted(cents: progress.spentInCents))
            if let limit = progress.limitInCents { remainingRow(spent: progress.spentInCents, limit: limit) }
            if progress.bucket == .transport { Text("Sem notificações").font(.caption).foregroundStyle(.secondary) }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private func remainingRow(spent: Int, limit: Int) -> some View {
        if spent > limit {
            LabeledContent("Excesso", value: Money.formatted(cents: spent - limit)).foregroundStyle(.red)
        } else {
            LabeledContent("Restante", value: Money.formatted(cents: limit - spent))
        }
    }

    private var reminderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Preparar a próxima semana", systemImage: "bell").font(.headline)
            Text("Lembrete todos os domingos às \(String(format: "%02d:%02d", reminderHour, reminderMinute)).")
                .font(.subheadline)
            if notificationAllowed == false {
                Text("As notificações ainda não estão autorizadas. Abre o lembrete para as ativar.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button("Configurar lembrete") { showReminder = true }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func changeWeek(by value: Int) {
        if let week = calendar.date(byAdding: .weekOfYear, value: value, to: displayedWeek) { displayedWeek = week }
    }

    private func refreshDay() {
        let wasCurrentWeek = selectedKey == WeeklyBudgetService.weekKey(containing: now)
        now = .now
        if wasCurrentWeek { displayedWeek = now }
    }

    private func updatePermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationAllowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }
}

private struct WeeklyBudgetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [WeeklyBudgetPlan]
    let week: Date
    @State private var total = ""
    @State private var groceries = ""
    @State private var transport = ""
    @State private var leisure = ""
    @State private var loaded = false
    @State private var error: String?

    private var weekKey: String { WeeklyBudgetService.weekKey(containing: week) }
    private var plan: WeeklyBudgetPlan? { plans.first { $0.weekKey == weekKey } }
    private var parsedLimits: [Int]? {
        let values = [total, groceries, transport, leisure].compactMap { WeeklyBudgetService.limitCents(from: $0) }
        return values.count == 4 ? values : nil
    }
    private var categorySum: Int? {
        let values = [groceries, transport, leisure].compactMap { WeeklyBudgetService.limitCents(from: $0) }
        return values.count == 3 ? values.reduce(0, +) : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(WeeklyBudgetService.title(for: week)).font(.headline)
                    Text("Os valores só ficam ativos para esta semana ao tocares em Confirmar. Podes mantê-los ou alterá-los a cada semana.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section("Limite geral da semana") { limitField("Total (€)", text: $total) }
                Section("Limites por categoria") {
                    limitField("Alimentação (€)", text: $groceries)
                    limitField("Transportes (€)", text: $transport)
                    limitField("Lazer (€)", text: $leisure)
                    if let sum = categorySum {
                        LabeledContent("Soma das categorias", value: Money.formatted(cents: sum))
                        Button("Usar esta soma como limite geral") { total = input(sum) }
                    }
                }
                Section {
                    Text("O limite geral controla a soma dos gastos nos três objetivos. Pode ser diferente da soma dos limites individuais. Um limite de 0 € significa que não pretendes gastar nessa rubrica.")
                    Text("Os limites não criam despesas nem alteram o saldo. Os gastos já registados nesta semana entram imediatamente no acompanhamento.")
                }.font(.footnote).foregroundStyle(.secondary)
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("Limites da semana")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Confirmar", action: save).disabled(parsedLimits == nil) }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                if let plan {
                    total = input(plan.totalLimitInCents)
                    groceries = input(plan.groceriesLimitInCents)
                    transport = input(plan.transportLimitInCents)
                    leisure = input(plan.leisureLimitInCents)
                } else {
                    // Suggestions only; no active plan exists until this week is confirmed.
                    total = "200,00"; groceries = "90,00"; transport = "50,00"; leisure = "40,00"
                }
            }
        }
    }

    private func limitField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0,00", text: text).keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing).accessibilityLabel(label)
        }
    }

    private func input(_ cents: Int) -> String {
        "\(cents / 100),\(String(format: "%02d", cents % 100))"
    }

    private func save() {
        guard let limits = parsedLimits else { return }
        if let plan {
            plan.totalLimitInCents = limits[0]; plan.groceriesLimitInCents = limits[1]
            plan.transportLimitInCents = limits[2]; plan.leisureLimitInCents = limits[3]
            plan.confirmedAt = .now
        } else {
            modelContext.insert(WeeklyBudgetPlan(
                weekKey: weekKey, weekStart: WeeklyBudgetService.weekInterval(containing: week).start,
                totalLimitInCents: limits[0], groceriesLimitInCents: limits[1],
                transportLimitInCents: limits[2], leisureLimitInCents: limits[3]
            ))
        }
        do { try modelContext.save(); dismiss() }
        catch { modelContext.rollback(); self.error = "Não foi possível guardar os limites. Tenta novamente." }
    }
}

private struct WeeklyReminderEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("weeklyBudget.reminderHour") private var hour = 18
    @AppStorage("weeklyBudget.reminderMinute") private var minute = 0
    @State private var time = Date.now
    @State private var message: String?
    @State private var denied = false
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Todos os domingos") {
                    DatePicker("Hora", selection: $time, displayedComponents: .hourAndMinute)
                    Text("Recebes um lembrete para definir ou confirmar os limites da semana que começa na segunda-feira. Sem confirmação, a nova semana fica sem limites ativos.")
                }
                if let message { Section { Text(message) } }
                if denied {
                    Button("Abrir definições de notificações") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
            }
            .navigationTitle("Lembrete de domingo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }.disabled(saving)
                }
            }
            .onAppear { time = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let newHour = components.hour ?? 18
        let newMinute = components.minute ?? 0
        do {
            let allowed = try await WeeklyBudgetNotificationService.scheduleSundayReminder(
                hour: newHour, minute: newMinute, requestAuthorization: true
            )
            hour = newHour; minute = newMinute
            denied = !allowed
            if allowed { dismiss() }
            else { message = "A hora ficou guardada, mas é necessário permitir notificações nas Definições do iPhone." }
        } catch { message = "Não foi possível agendar o lembrete. Tenta novamente." }
    }
}
