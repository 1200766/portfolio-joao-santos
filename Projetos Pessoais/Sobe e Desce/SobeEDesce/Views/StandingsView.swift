import SobeEDesceCore
import SwiftUI

struct StandingsView: View {
    @EnvironmentObject private var store: GameStore
    let session: GameSession

    private var standings: [Player] {
        GameEngine.standings(in: session)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    Text("Classificação")
                        .font(.largeTitle.bold())
                    Text("Fim da ronda \(session.roundNumber)")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    ForEach(Array(standings.enumerated()), id: \.element.id) { index, player in
                        HStack(spacing: 14) {
                            Text("\(index + 1)")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(index == 0 ? .white : .primary)
                                .frame(width: 36, height: 36)
                                .background(index == 0 ? AppTheme.felt : Color(.tertiarySystemFill), in: Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text(player.name)
                                    .font(.headline)
                                Label(
                                    trumpCountText(player.trumpChoiceCount),
                                    systemImage: "suit.club.fill"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 1) {
                                Text("\(player.score)")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                Text("pontos")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                        .accessibilityElement(children: .combine)
                    }
                }

                if let nextChooser = nextChooser {
                    GameCard {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title)
                                .foregroundStyle(AppTheme.burgundy)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Na próxima ronda")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(nextChooser.name) escolhe o trunfo")
                                    .font(.headline)
                            }
                        }
                    }
                }

                Button("Avançar para a ronda \(session.roundNumber + 1)") {
                    store.startNextRound()
                }
                .buttonStyle(PrimaryGameButtonStyle())

                Text("Em caso de empate, fica à frente quem escolheu o trunfo menos vezes. Se o empate continuar, vale a ordem original da mesa.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(18)
        }
        .gameScreenBackground()
        .navigationTitle("Classificação")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var nextChooser: Player? {
        guard !session.players.isEmpty else { return nil }
        let index = (session.chooserIndex + 1) % session.players.count
        return session.players[index]
    }

    private func trumpCountText(_ count: Int) -> String {
        count == 1 ? "Escolheu o trunfo 1 vez" : "Escolheu o trunfo \(count) vezes"
    }
}
