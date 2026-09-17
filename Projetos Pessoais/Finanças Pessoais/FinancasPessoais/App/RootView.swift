import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var movements: [Movement]
    @Query private var assignments: [MovementBudgetAssignment]
    @Query private var budgetPlans: [WeeklyBudgetPlan]
    @AppStorage("weeklyBudget.reminderHour") private var reminderHour = 18
    @AppStorage("weeklyBudget.reminderMinute") private var reminderMinute = 0
    @State private var evaluationDate = Date.now
    @State private var startupError: String?

    private var budgetSignature: String {
        let movementValues = movements.map {
            "\($0.id)|\($0.date)|\($0.amountInCents)|\($0.typeRawValue)|\($0.isConfirmed)|\($0.category?.name ?? "")"
        }.sorted().joined(separator: ";")
        let assignmentValues = assignments.map {
            "\($0.movementID)|\($0.selectionRawValue)|\($0.updatedAt)"
        }.sorted().joined(separator: ";")
        let planValues = budgetPlans.map {
            "\($0.weekKey)|\($0.totalLimitInCents)|\($0.groceriesLimitInCents)|\($0.transportLimitInCents)|\($0.leisureLimitInCents)|\($0.confirmedAt)"
        }.sorted().joined(separator: ";")
        return "\(movementValues)/\(assignmentValues)/\(planValues)/\(evaluationDate)/\(reminderHour):\(reminderMinute)"
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Início", systemImage: "house") }

            WeeklyBudgetView()
                .tabItem { Label("Semana", systemImage: "calendar.badge.clock") }

            CalendarView()
                .tabItem { Label("Calendário", systemImage: "calendar") }

            SimulationView()
                .tabItem { Label("Simulador", systemImage: "calendar.badge.plus") }

            MovementsView()
                .tabItem { Label("Movimentos", systemImage: "list.bullet.rectangle") }

            RecurringView()
                .tabItem { Label("Recorrentes", systemImage: "repeat") }

            SettingsView()
                .tabItem { Label("Definições", systemImage: "gearshape") }
        }
        .task {
            do {
                try SeedService.seedIfNeeded(in: modelContext)
                try RecurrenceService.removeLegacyFutureMaterializationsIfNeeded(in: modelContext)
                try RecurrenceService.generateDueMovements(in: modelContext)
            } catch {
                startupError = error.localizedDescription
            }
        }
        .task(id: budgetSignature) {
            do {
                try await WeeklyBudgetNotificationService.requestAuthorizationAndEvaluate(
                    movements: movements, assignments: assignments, records: [],
                    in: modelContext, date: evaluationDate, requestAuthorization: false
                )
            } catch {
                startupError = "Não foi possível atualizar os alertas semanais. \(error.localizedDescription)"
            }
        }
        .task(id: evaluationDate) {
            await InstallationReminderService.shared.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshCurrentDay() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            refreshCurrentDay()
        }
        .alert("Não foi possível preparar os dados", isPresented: Binding(
            get: { startupError != nil },
            set: { if !$0 { startupError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(startupError ?? "Erro desconhecido")
        }
    }

    private func refreshCurrentDay() {
        evaluationDate = .now
        do { try RecurrenceService.generateDueMovements(in: modelContext) }
        catch { startupError = error.localizedDescription }
    }
}
