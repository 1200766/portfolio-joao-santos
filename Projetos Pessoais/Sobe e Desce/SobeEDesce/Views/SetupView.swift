import SobeEDesceCore
import SwiftUI

struct SetupView: View {
    let previousGameDisposition: GameDisposition
    let onStarted: () -> Void

    private enum Step {
        case options
        case names
        case firstChooser
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: GameStore
    @FocusState private var isNameFieldFocused: Bool
    @FocusState private var isMoneyFieldFocused: Bool
    @FocusState private var isGameNameFieldFocused: Bool

    @State private var step: Step = .options
    @State private var gameName = ""
    @State private var playerCount = 4
    @State private var playsForMoney = false
    @State private var valuePerPoint = "0,10"
    @State private var names = Array(repeating: "", count: 5)
    @State private var currentNameIndex = 0
    @State private var selectedFirstChooser: Int?
    @State private var validationMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .options:
                    optionsView
                case .names:
                    nameView
                case .firstChooser:
                    firstChooserView
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .interactiveDismissDisabled()
        .tint(AppTheme.burgundy)
        .onChange(of: playerCount) { _, newCount in
            if let selectedFirstChooser, selectedFirstChooser >= newCount {
                self.selectedFirstChooser = nil
            }
            if currentNameIndex >= newCount {
                currentNameIndex = max(0, newCount - 1)
            }
        }
    }

    private var navigationTitle: String {
        switch step {
        case .options: "Nova partida"
        case .names: "Jogador \(currentNameIndex + 1) de \(playerCount)"
        case .firstChooser: "Rei de copas"
        }
    }

    private var optionsView: some View {
        Form {
            Section {
                TextField("Nome da partida (opcional)", text: $gameName)
                    .textInputAutocapitalization(.sentences)
                    .focused($isGameNameFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { isGameNameFieldFocused = false }
                    .accessibilityIdentifier("game-name")
            } header: {
                Text("Nome da partida")
            } footer: {
                Text("Para a encontrares no histórico. Se deixares vazio, usamos a data do jogo.")
            }

            Section("Quantas pessoas vão jogar?") {
                Picker("Número de jogadores", selection: $playerCount) {
                    Text("4 jogadores").tag(4)
                    Text("5 jogadores").tag(5)
                }
                .pickerStyle(.segmented)
            }

            Section {
                Toggle("Jogar a dinheiro?", isOn: $playsForMoney.animation())

                if playsForMoney {
                    HStack {
                        TextField("0,01 a 2,00", text: $valuePerPoint)
                            .keyboardType(.decimalPad)
                            .focused($isMoneyFieldFocused)
                            .multilineTextAlignment(.trailing)
                        Text("€ por ponto")
                            .foregroundStyle(.secondary)
                    }
                    Text("A app calcula apenas o acerto final. Não efetua pagamentos.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            validationSection

            Section {
                Button("Continuar", action: continueFromOptions)
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var nameView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)

                Image(systemName: "hand.point.right.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(AppTheme.burgundy)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("Passa o telemóvel à pessoa à tua direita")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text("Cada pessoa escreve o próprio nome. A ordem fica igual à ordem da mesa.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                GameCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Qual é o teu nome?")
                            .font(.headline)
                        TextField("Nome", text: $names[currentNameIndex])
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.next)
                            .focused($isNameFieldFocused)
                            .onSubmit(saveCurrentName)
                            .padding(14)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                if let validationMessage {
                    Text(validationMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(currentNameIndex == playerCount - 1 ? "Guardar e continuar" : "Guardar nome", action: saveCurrentName)
                    .buttonStyle(PrimaryGameButtonStyle())

                if currentNameIndex > 0 {
                    Button("Voltar ao nome anterior", action: previousName)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Voltar às opções") {
                        validationMessage = nil
                        step = .options
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 20)
            }
            .padding(24)
        }
        .gameScreenBackground()
        .onAppear { isNameFieldFocused = true }
    }

    private var firstChooserView: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    Text("♥︎ K")
                        .font(.system(size: 54, weight: .bold, design: .serif))
                        .foregroundStyle(AppTheme.burgundy)
                        .accessibilityHidden(true)
                    Text("Quem recebeu o rei de copas?")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text("Essa pessoa recebe primeiro três cartas e escolhe o trunfo da ronda 1.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    ForEach(0..<playerCount, id: \.self) { index in
                        Button {
                            selectedFirstChooser = index
                            validationMessage = nil
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(names[index])
                                        .font(.headline)
                                    Text("Lugar \(index + 1) na mesa")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: selectedFirstChooser == index ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(selectedFirstChooser == index ? AppTheme.burgundy : .secondary)
                            }
                            .padding(16)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .contentShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(selectedFirstChooser == index ? "Selecionado" : "Não selecionado")
                    }
                }

                if let validationMessage {
                    Text(validationMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button("Começar a ronda 1", action: startGame)
                    .buttonStyle(PrimaryGameButtonStyle())

                Button("Voltar ao último nome") {
                    currentNameIndex = playerCount - 1
                    validationMessage = nil
                    step = .names
                }
                .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .gameScreenBackground()
    }

    @ViewBuilder
    private var validationSection: some View {
        if let validationMessage {
            Section {
                Text(validationMessage)
                    .foregroundStyle(.red)
            }
        }
    }

    private func continueFromOptions() {
        validationMessage = nil
        if playsForMoney {
            guard let cents = EuroMoney.cents(from: valuePerPoint),
                  (1...200).contains(cents) else {
                validationMessage = "Indica um valor entre 0,01 € e 2,00 €."
                isMoneyFieldFocused = true
                return
            }
        }
        currentNameIndex = 0
        step = .names
    }

    private func saveCurrentName() {
        let trimmed = names[currentNameIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            validationMessage = "Escreve o teu nome para continuar."
            isNameFieldFocused = true
            return
        }

        names[currentNameIndex] = trimmed
        validationMessage = nil
        if currentNameIndex == playerCount - 1 {
            isNameFieldFocused = false
            step = .firstChooser
        } else {
            currentNameIndex += 1
            isNameFieldFocused = true
        }
    }

    private func previousName() {
        currentNameIndex -= 1
        validationMessage = nil
        isNameFieldFocused = true
    }

    private func startGame() {
        guard let selectedFirstChooser else {
            validationMessage = "Escolhe quem recebeu o rei de copas."
            return
        }

        let cents = playsForMoney ? EuroMoney.cents(from: valuePerPoint) : nil
        if store.startGame(
            name: gameName,
            names: Array(names.prefix(playerCount)),
            valuePerPointCents: cents,
            firstChooserIndex: selectedFirstChooser,
            previousGameDisposition: previousGameDisposition
        ) {
            onStarted()
            dismiss()
        } else {
            validationMessage = store.errorMessage
            store.clearError()
        }
    }
}
