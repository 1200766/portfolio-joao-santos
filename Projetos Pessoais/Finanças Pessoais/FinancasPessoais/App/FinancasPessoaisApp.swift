import SwiftData
import SwiftUI
import UserNotifications

@main
struct FinancasPessoaisApp: App {
    init() {
        UNUserNotificationCenter.current().delegate = InstallationNotificationDelegate.shared
    }

    private let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(
                for: FinanceCategory.self,
                Movement.self,
                CategorizationRule.self,
                RecurringRule.self,
                RecurringOverride.self,
                BalanceSnapshot.self,
                MovementBudgetAssignment.self,
                BudgetNotificationRecord.self,
                WeeklyBudgetPlan.self,
                SimulationAdjustment.self
            )
        } catch {
            fatalError("Não foi possível iniciar a base de dados local: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
