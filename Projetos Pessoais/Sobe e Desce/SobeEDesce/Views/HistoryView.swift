import SobeEDesceCore
import SwiftUI

struct HistoryView: View {
    let onClose: () -> Void
    @EnvironmentObject private var store: GameStore
    @State private var searchText = ""

    private var matches: [GameSession] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.history }
        return store.history.filter { game in
            game.name.localizedStandardContains(query)
                || game.players.contains { $0.name.localizedStandardContains(query) }
        }
    }

    var body: some View {
        Group {
            if store.history.isEmpty {
                ContentUnavailableView(
                    "Ainda não há partidas guardadas",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("As partidas concluídas e as que escolheres guardar ao interromper ficam aqui para consulta.")
                )
            } else if matches.isEmpty {
                ContentUnavailableView(
                    "Sem resultados",
                    systemImage: "magnifyingglass",
                    description: Text("Nenhuma partida ou participante corresponde à pesquisa.")
                )
            } else {
                List(matches) { game in
                    NavigationLink {
                        HistoryDetailView(session: game, onClose: onClose)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(game.name)
                                .font(.headline)
                            Text(game.createdAt, format: .dateTime.day().month(.wide).year().hour().minute().locale(Locale(identifier: "pt_PT")))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let winner = game.winner {
                                Label("Venceu \(winner.name)", systemImage: "trophy.fill")
                                    .foregroundStyle(AppTheme.felt)
                                    .font(.subheadline)
                            } else {
                                Text("Interrompida · Ronda \(game.roundNumber)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Text(game.players.map(\.name).joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                    .accessibilityIdentifier("history-entry-\(game.name)")
                }
                .scrollContentBackground(.hidden)
            }
        }
        .gameScreenBackground()
        .navigationTitle("Histórico")
        .searchable(text: $searchText, prompt: "Partida ou participante")
    }
}

private struct HistoryDetailView: View {
    let session: GameSession
    let onClose: () -> Void

    private var standings: [Player] {
        (try? GameEngine.finalStandings(in: session)) ?? GameEngine.standings(in: session)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                GameCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(session.name)
                            .font(.title2.bold())
                        Text(session.createdAt, format: .dateTime.day().month(.wide).year().hour().minute().locale(Locale(identifier: "pt_PT")))
                            .foregroundStyle(.secondary)
                        if let winner = session.winner {
                            Label("Venceu \(winner.name)", systemImage: "trophy.fill")
                                .font(.headline)
                                .foregroundStyle(AppTheme.felt)
                            Text("Terminou na ronda \(session.roundNumber).")
                                .font(.subheadline)
                        } else {
                            Text("Partida interrompida na ronda \(session.roundNumber).")
                                .font(.subheadline)
                            Text("Estes são os resultados guardados até à última ronda confirmada.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                GameCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(session.phase == .finished ? "Pontuação final" : "Pontuação guardada")
                            .font(.headline)
                        ForEach(Array(standings.enumerated()), id: \.element.id) { index, player in
                            HStack(alignment: .firstTextBaseline) {
                                Text("\(index + 1).")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24, alignment: .trailing)
                                Text(player.name)
                                Spacer()
                                Text("\(player.score) pontos")
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                            }
                            if index < standings.count - 1 { Divider() }
                        }
                    }
                }

                GameCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Acerto entre jogadores", systemImage: "eurosign.circle")
                            .font(.headline)
                        if let cents = session.valuePerPointCents {
                            Text("Valor por ponto: \(EuroMoney.formatted(cents: Int64(cents))).")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if session.phase == .finished {
                                if let debts = try? GameEngine.settlements(in: session),
                                   let total = try? GameEngine.totalToReceive(in: session),
                                   let winner = session.winner {
                                    ForEach(debts) { debt in
                                        HStack(alignment: .firstTextBaseline) {
                                            Text(debt.playerName)
                                            Spacer()
                                            Text("deve \(EuroMoney.formatted(cents: debt.amountCents))")
                                                .fontWeight(.semibold)
                                                .monospacedDigit()
                                        }
                                    }
                                    Divider()
                                    HStack(alignment: .firstTextBaseline) {
                                        Text("\(winner.name) recebe")
                                        Spacer()
                                        Text(EuroMoney.formatted(cents: total))
                                            .monospacedDigit()
                                    }
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.felt)
                                } else {
                                    Text("Não foi possível calcular as dívidas desta partida.")
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text("Sem dívidas finais: esta partida terminou antes de haver vencedor.")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Partida sem dinheiro.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(18)
        }
        .accessibilityIdentifier("history-detail")
        .gameScreenBackground()
        .navigationTitle("Partida guardada")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Concluído", action: onClose)
            }
        }
    }
}
