import SobeEDesceCore
import SwiftUI

struct RoundView: View {
    @EnvironmentObject private var store: GameStore
    let session: GameSession

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                RoundHeader(session: session)

                switch session.phase {
                case .choosingTrump:
                    TrumpSelectionView(session: session)
                case .choosingParticipants:
                    ParticipantSelectionView(session: session)
                case .assigningResults:
                    ResultAssignmentView(session: session)
                case .standings, .finished:
                    EmptyView()
                }
            }
            .padding(18)
        }
        .gameScreenBackground()
        .navigationTitle("Ronda \(session.roundNumber)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TrumpSelectionView: View {
    @EnvironmentObject private var store: GameStore
    let session: GameSession
    @State private var selectedSuit: Suit?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 5) {
                Text("Escolhe o trunfo")
                    .font(.title2.bold())
                Text("Quem escolhe o trunfo tem sempre de ir a jogo.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Suit.allCases) { suit in
                    Button {
                        selectedSuit = suit
                    } label: {
                        VStack(spacing: 7) {
                            Text(suit.symbol)
                                .font(.system(size: 42, weight: .semibold, design: .serif))
                            Text(suit.name)
                                .font(.headline)
                            if suit == .blindHearts {
                                Text("Sem ver · 20 pontos")
                                    .font(.caption2)
                            } else if suit == .hearts {
                                Text("A dobrar · 10 pontos")
                                    .font(.caption2)
                            } else if suit == .clubs {
                                Text("Todos jogam")
                                    .font(.caption2)
                            } else {
                                Text("5 pontos")
                                    .font(.caption2)
                            }
                        }
                        .foregroundStyle(
                            suit == .hearts || suit == .blindHearts || suit == .diamonds
                                ? AppTheme.burgundy
                                : .primary
                        )
                        .frame(maxWidth: .infinity, minHeight: 122)
                        .background(
                            selectedSuit == suit
                                ? AppTheme.burgundy.opacity(0.12)
                                : Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(
                                    selectedSuit == suit ? AppTheme.burgundy : .clear,
                                    lineWidth: 2
                                )
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("trump-\(suit.rawValue)")
                    .accessibilityValue(selectedSuit == suit ? "Selecionado" : "Não selecionado")
                }
            }

            if selectedSuit == .blindHearts {
                Text("Escolhe Copas às cegas antes de veres as tuas cartas. Cada jogada ganha vale 4 pontos; zero faz subir 20.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Confirmar trunfo") {
                guard let selectedSuit else { return }
                store.selectTrump(selectedSuit)
            }
            .buttonStyle(PrimaryGameButtonStyle())
            .disabled(selectedSuit == nil)
            .opacity(selectedSuit == nil ? 0.5 : 1)
        }
    }
}

private struct ParticipantSelectionView: View {
    @EnvironmentObject private var store: GameStore
    let session: GameSession
    @State private var selectedIDs: Set<UUID>
    @State private var validationMessage: String?

    init(session: GameSession) {
        self.session = session
        _selectedIDs = State(initialValue: Set(session.players.map(\.id)))
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 5) {
                Text("Quem vai a jogo?")
                    .font(.title2.bold())
                Text("Desmarca quem fica de fora. A pontuação dessas pessoas não muda.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            GameCard {
                VStack(spacing: 0) {
                    ForEach(session.players) { player in
                        Toggle(isOn: Binding(
                            get: { selectedIDs.contains(player.id) },
                            set: { isSelected in
                                if isSelected {
                                    selectedIDs.insert(player.id)
                                } else if GameEngine.participationRequirement(for: player.id, in: session) == nil {
                                    selectedIDs.remove(player.id)
                                }
                                validationMessage = nil
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(player.name)
                                    .font(.headline)
                                if let requirement = GameEngine.participationRequirement(for: player.id, in: session) {
                                    Label(requirement.description, systemImage: "lock.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else if player.consecutiveAbsences > 0 {
                                    Text("Ficou de fora na ronda anterior")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(GameEngine.participationRequirement(for: player.id, in: session) != nil)
                        .accessibilityIdentifier("participant-\(player.tablePosition)")
                        .padding(.vertical, 11)

                        if player.id != session.players.last?.id {
                            Divider()
                        }
                    }
                }
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button("Confirmar participantes") {
                guard !selectedIDs.isEmpty else {
                    validationMessage = "Pelo menos uma pessoa tem de ir a jogo."
                    return
                }
                store.selectParticipants(selectedIDs.union(GameEngine.requiredParticipantIDs(in: session)))
            }
            .buttonStyle(PrimaryGameButtonStyle())

            Button("Alterar trunfo") {
                store.restartRoundSetup()
            }
            .foregroundStyle(.secondary)
        }
    }
}

private struct ResultAssignmentView: View {
    @EnvironmentObject private var store: GameStore
    let session: GameSession
    @State private var isConfirmingRoundRestart = false

    var body: some View {
        VStack(spacing: 18) {
            remainingPanel

            if session.roundIsReady {
                resultReview
            } else if let participant = session.currentParticipant {
                ResultPicker(
                    participant: participant,
                    values: GameEngine.availableResults(in: session),
                    zeroIncrease: session.currentSuit?.zeroIncrease ?? 5,
                    onConfirm: store.assignResult
                )
                .id(participant.id)
            }

            assignedResults

            Button("Alterar trunfo ou participantes") {
                isConfirmingRoundRestart = true
            }
            .foregroundStyle(.secondary)
        }
        .confirmationDialog(
            "Recomeçar a configuração desta ronda?",
            isPresented: $isConfirmingRoundRestart,
            titleVisibility: .visible
        ) {
            Button("Recomeçar ronda", role: .destructive) {
                store.restartRoundSetup()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("O trunfo, os participantes e os resultados desta ronda serão limpos. A pontuação da partida não muda.")
        }
    }

    private var remainingPanel: some View {
        VStack(spacing: 4) {
            Text("Por distribuir")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(session.remainingRoundPoints)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(session.remainingRoundPoints == 0 ? AppTheme.felt : AppTheme.deepBurgundy)
            Text(session.remainingRoundPoints == 1 ? "ponto" : "pontos")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(AppTheme.cream.opacity(0.75), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }

    private var resultReview: some View {
        GameCard {
            VStack(spacing: 14) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.largeTitle)
                    .foregroundStyle(AppTheme.felt)
                    .accessibilityHidden(true)
                Text("Verificar pontos")
                    .font(.title3.bold())
                Text("O saldo final e os zeros restantes são preenchidos automaticamente. Revê os resultados abaixo antes de fechar a ronda.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Fechar ronda") { store.closeRound() }
                    .buttonStyle(PrimaryGameButtonStyle())

                Button("Recomeçar atribuição") { store.restartAssignments() }
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var assignedResults: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !session.results.isEmpty {
                Text("Resultados atribuídos")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(session.participantIDs, id: \.self) { playerID in
                    if let result = session.results[playerID],
                       let player = session.players.first(where: { $0.id == playerID }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.felt)
                            Text(player.name)
                            Spacer()
                            Text("\(result)")
                                .font(.headline.monospacedDigit())
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }
}

private struct ResultPicker: View {
    let participant: Player
    let values: [Int]
    let zeroIncrease: Int
    let onConfirm: (Int) -> Void
    @State private var selectedValue: Int?

    private let columns = [GridItem(.adaptive(minimum: 54), spacing: 10)]

    var body: some View {
        GameCard {
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text(participant.name)
                        .font(.title2.bold())
                    Text("Quantos pontos conseguiu?")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(values, id: \.self) { value in
                        Button {
                            selectedValue = value
                        } label: {
                            Text("\(value)")
                                .font(.title3.bold().monospacedDigit())
                                .frame(minWidth: 48, minHeight: 48)
                                .background(
                                    selectedValue == value
                                        ? AppTheme.burgundy
                                        : Color(.tertiarySystemFill),
                                    in: Circle()
                                )
                                .foregroundStyle(selectedValue == value ? .white : .primary)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("result-\(value)")
                        .accessibilityLabel("\(value) pontos")
                        .accessibilityValue(selectedValue == value ? "Selecionado" : "Não selecionado")
                    }
                }

                Text("0 faz subir \(zeroIncrease) pontos; um valor positivo é subtraído.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Confirmar resultado") {
                    guard let selectedValue else { return }
                    onConfirm(selectedValue)
                }
                .buttonStyle(PrimaryGameButtonStyle())
                .disabled(selectedValue == nil)
                .opacity(selectedValue == nil ? 0.5 : 1)
            }
        }
    }
}
