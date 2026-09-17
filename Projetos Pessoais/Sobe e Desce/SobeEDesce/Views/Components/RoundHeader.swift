import SobeEDesceCore
import SwiftUI

struct RoundHeader: View {
    let session: GameSession

    var body: some View {
        GameCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(session.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("RONDA \(session.roundNumber)")
                    .font(.caption.bold())
                    .tracking(1.4)
                    .foregroundStyle(AppTheme.burgundy)

                if let chooser = session.chooser {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.title2)
                            .foregroundStyle(.yellow)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(chooser.name)
                                .font(.title2.bold())
                            Text("escolhe o trunfo")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let suit = session.currentSuit {
                    Divider()
                    HStack {
                        Text(suit.symbol)
                            .font(.title)
                            .foregroundStyle(suit == .hearts || suit == .blindHearts || suit == .diamonds ? AppTheme.burgundy : .primary)
                        Text("Trunfo: \(suit.name)")
                            .font(.headline)
                        Spacer()
                        Text("\(suit.roundTotal) pontos")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
