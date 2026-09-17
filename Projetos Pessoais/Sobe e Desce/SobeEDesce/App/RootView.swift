import SobeEDesceCore
import SwiftUI

struct RootView: View {
    private enum ExitAction {
        case interrupt
        case newGame
    }

    @EnvironmentObject private var store: GameStore
    @State private var isShowingHome = false
    @State private var isPresentingSetup = false
    @State private var isConfirmingExit = false
    @State private var exitAction: ExitAction = .interrupt
    @State private var previousGameDisposition: GameDisposition = .saveToHistory
    @State private var isPresentingHistory = false

    var body: some View {
        NavigationStack {
            Group {
                if let session = store.session, !isShowingHome {
                    gameView(for: session)
                        .id(session.id)
                } else {
                    HomeView(
                        session: store.session,
                        onStart: requestNewGame,
                        onHistory: { isPresentingHistory = true },
                        onResume: { isShowingHome = false },
                        onInterrupt: requestInterruption
                    )
                }
            }
            .toolbar {
                if store.session != nil, !isShowingHome {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Página inicial", systemImage: "house") {
                            isShowingHome = true
                        }
                        .accessibilityIdentifier("go-home")
                        .accessibilityHint("Permite regressar ao início sem terminar a partida")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Histórico", systemImage: "clock.arrow.circlepath") {
                            isPresentingHistory = true
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            if store.session?.phase != .finished {
                                Button("Interromper partida", systemImage: "stop.circle", action: requestInterruption)
                            }
                            Button("Começar nova partida", systemImage: "plus", action: requestNewGame)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .accessibilityLabel("Mais opções")
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $isPresentingSetup) {
            SetupView(previousGameDisposition: previousGameDisposition, onStarted: {
                isShowingHome = false
            })
                .environmentObject(store)
        }
        .sheet(isPresented: $isPresentingHistory) {
            NavigationStack {
                HistoryView(onClose: { isPresentingHistory = false })
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Concluído") { isPresentingHistory = false }
                        }
                    }
            }
            .environmentObject(store)
        }
        .confirmationDialog(
            exitAction == .interrupt ? "Interromper a partida?" : "Começar uma nova partida?",
            isPresented: $isConfirmingExit,
            titleVisibility: .visible
        ) {
            if store.session?.phase == .finished {
                Button("Começar nova partida") { handleExit(.saveToHistory) }
            } else {
                Button(exitAction == .interrupt ? "Guardar no histórico" : "Guardar e continuar") {
                    handleExit(.saveToHistory)
                }
                Button(exitAction == .interrupt ? "Sair sem guardar" : "Não guardar e continuar", role: .destructive) {
                    handleExit(.discard)
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            if store.session?.phase == .finished {
                Text("A partida concluída já está guardada no histórico.")
            } else if exitAction == .interrupt {
                Text("Queres guardar esta partida no histórico? Ao sair, deixa de poder ser retomada. Se saíres sem guardar, a partida será descartada. O histórico anterior não é alterado.")
            } else {
                Text("Queres guardar a partida atual no histórico? A tua escolha só é aplicada quando começares a nova partida. Se cancelares a configuração, podes continuar a atual.")
            }
        }
        .alert(
            "Não foi possível concluir a ação",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.clearError() } }
            )
        ) {
            Button("OK", role: .cancel) { store.clearError() }
        } message: {
            Text(store.errorMessage ?? "Erro desconhecido.")
        }
    }

    @ViewBuilder
    private func gameView(for session: GameSession) -> some View {
        switch session.phase {
        case .choosingTrump, .choosingParticipants, .assigningResults:
            RoundView(session: session)
        case .standings:
            StandingsView(session: session)
        case .finished:
            GameOverView(session: session, onNewGame: requestNewGame)
        }
    }

    private func requestNewGame() {
        if store.session == nil {
            previousGameDisposition = .saveToHistory
            isPresentingSetup = true
        } else {
            exitAction = .newGame
            isConfirmingExit = true
        }
    }

    private func requestInterruption() {
        exitAction = .interrupt
        isConfirmingExit = true
    }

    private func handleExit(_ disposition: GameDisposition) {
        switch exitAction {
        case .newGame:
            previousGameDisposition = disposition
            isPresentingSetup = true
        case .interrupt:
            let didExit = disposition == .saveToHistory
                ? store.archiveCurrentGame()
                : store.discardGame()
            if didExit { isShowingHome = true }
        }
    }
}
