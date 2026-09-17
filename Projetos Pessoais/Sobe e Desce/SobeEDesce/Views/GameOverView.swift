import SobeEDesceCore
import SwiftUI

struct GameOverView: View {
    let session: GameSession
    let onNewGame: () -> Void

    private var settlements: [Settlement] {
        (try? GameEngine.settlements(in: session)) ?? []
    }

    private var totalToReceive: Int64 {
        (try? GameEngine.totalToReceive(in: session)) ?? 0
    }

    private var finalStandings: [Player] {
        (try? GameEngine.finalStandings(in: session)) ?? GameEngine.standings(in: session)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 4) {
                    Text(session.name)
                        .font(.headline)
                    Text(session.createdAt, format: .dateTime.day().month(.wide).year().hour().minute().locale(Locale(identifier: "pt_PT")))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 58))
                        .foregroundStyle(.yellow)
                        .shadow(color: .orange.opacity(0.25), radius: 8, y: 4)
                        .accessibilityHidden(true)

                    Text("Vitória!")
                        .font(.largeTitle.bold())

                    if let winner = session.winner {
                        Text("\(winner.name) chegou primeiro a zero.")
                            .font(.title3)
                            .multilineTextAlignment(.center)
                    }
                }

                finalScores

                if session.valuePerPointCents != nil {
                    moneySummary
                }

                Button("Começar nova partida", action: onNewGame)
                    .buttonStyle(PrimaryGameButtonStyle())

                Text("A partida terminou na ronda \(session.roundNumber) e está guardada no histórico.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
        }
        .gameScreenBackground()
        .navigationTitle("Fim da partida")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var finalScores: some View {
        GameCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pontuação final")
                    .font(.headline)

                ForEach(Array(finalStandings.enumerated()), id: \.element.id) { index, player in
                    HStack {
                        Text("\(index + 1).")
                            .foregroundStyle(.secondary)
                            .frame(width: 26, alignment: .trailing)
                        Text(player.name)
                        Spacer()
                        Text("\(player.score) pontos")
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    if player.id != finalStandings.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var moneySummary: some View {
        GameCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Acerto entre jogadores", systemImage: "eurosign.circle.fill")
                    .font(.headline)
                    .foregroundStyle(AppTheme.deepBurgundy)

                if let winner = session.winner,
                   let valuePerPointCents = session.valuePerPointCents {
                    Text("Cada ponto vale \(EuroMoney.formatted(cents: Int64(valuePerPointCents))).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(settlements) { settlement in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(settlement.playerName)
                                    .fontWeight(.medium)
                                Text("\(settlement.finalScore) pontos")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("deve \(EuroMoney.formatted(cents: settlement.amountCents))")
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                    }

                    Divider()

                    HStack {
                        Text("\(winner.name) recebe")
                            .font(.headline)
                        Spacer()
                        Text(EuroMoney.formatted(cents: totalToReceive))
                            .font(.title3.bold())
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.felt)
                    }

                    Text("A app não movimenta dinheiro nem integra pagamentos.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
