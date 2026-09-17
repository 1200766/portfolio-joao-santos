import SobeEDesceCore
import SwiftUI

struct HomeView: View {
    let session: GameSession?
    let onStart: () -> Void
    let onHistory: () -> Void
    let onResume: () -> Void
    let onInterrupt: () -> Void

    var body: some View {
        ZStack {
            AppTheme.background

            ScrollView {
                VStack(spacing: 26) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: session == nil ? 154 : 112, height: session == nil ? 154 : 112)
                        .clipShape(RoundedRectangle(cornerRadius: 34))
                        .shadow(color: .black.opacity(0.16), radius: 16, y: 8)
                        .accessibilityHidden(true)

                    VStack(spacing: 10) {
                        Text("Sobe e Desce")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.deepBurgundy)
                            .multilineTextAlignment(.center)

                        Text("Pontuação simples para o jogo à mesa")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if let session {
                        GameCard {
                            VStack(spacing: 12) {
                                Label(session.phase == .finished ? "Última partida concluída" : "Partida em curso",
                                      systemImage: session.phase == .finished ? "checkmark.circle" : "pause.circle")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(session.name)
                                    .font(.title3.bold())
                                    .multilineTextAlignment(.center)
                                if session.phase != .finished {
                                    Text("Ronda \(session.roundNumber) · O progresso confirmado está guardado.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                Button(session.phase == .finished ? "Ver último resultado" : "Retomar partida", action: onResume)
                                    .buttonStyle(PrimaryGameButtonStyle())
                                if session.phase != .finished {
                                    Button("Interromper partida", systemImage: "stop.circle", action: onInterrupt)
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.vertical, 8)
                                }
                            }
                        }
                    }

                    if session == nil {
                        Button("Iniciar jogo", action: onStart)
                            .buttonStyle(PrimaryGameButtonStyle())
                            .accessibilityHint("Abre a configuração de uma nova partida")
                    } else {
                        Button("Começar nova partida", systemImage: "plus", action: onStart)
                            .font(.headline)
                    }

                    Button("Histórico de partidas", systemImage: "clock.arrow.circlepath", action: onHistory)
                        .font(.headline)

                    Label("Funciona sem Internet e não movimenta dinheiro", systemImage: "iphone.and.arrow.forward")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .padding(.top, session == nil ? 48 : 8)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
