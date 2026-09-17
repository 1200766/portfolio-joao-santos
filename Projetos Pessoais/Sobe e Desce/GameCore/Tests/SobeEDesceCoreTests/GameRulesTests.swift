import Foundation
import Testing
@testable import SobeEDesceCore

private func session(
    count: Int = 4,
    firstChooserIndex: Int = 0,
    valuePerPointCents: Int? = nil
) throws -> GameSession {
    try GameEngine.makeSession(
        names: (1...count).map { "Jogador \($0)" },
        valuePerPointCents: valuePerPointCents,
        firstChooserIndex: firstChooserIndex
    )
}

@Test("A configuração aceita apenas quatro ou cinco jogadores")
func playerCountValidation() throws {
    #expect(throws: GameRuleError.invalidPlayerCount) {
        try GameEngine.makeSession(names: ["A", "B", "C"], valuePerPointCents: nil, firstChooserIndex: 0)
    }
    #expect(try session(count: 4).players.count == 4)
    #expect(try session(count: 5).players.count == 5)
}

@Test("A configuração rejeita nomes vazios e um primeiro jogador inexistente")
func requiredSetupValues() {
    #expect(throws: GameRuleError.emptyPlayerName(position: 2)) {
        try GameEngine.makeSession(
            names: ["Ana", "Bruno", "  ", "Duarte"],
            valuePerPointCents: nil,
            firstChooserIndex: 0
        )
    }
    #expect(throws: GameRuleError.invalidFirstChooser) {
        try GameEngine.makeSession(
            names: ["Ana", "Bruno", "Carla", "Duarte"],
            valuePerPointCents: nil,
            firstChooserIndex: 4
        )
    }
}

@Test("A ordem de introdução é a ordem física da mesa")
func tableOrderIsPreserved() throws {
    let game = try GameEngine.makeSession(
        names: ["  Ana ", "Bruno", "Carla", "Duarte"],
        valuePerPointCents: nil,
        firstChooserIndex: 2
    )
    #expect(game.players.map(\.name) == ["Ana", "Bruno", "Carla", "Duarte"])
    #expect(game.players.map(\.tablePosition) == [0, 1, 2, 3])
    #expect(game.players.allSatisfy { $0.score == 20 })
}

@Test("O valor por ponto respeita os limites ao cêntimo")
func moneyBounds() throws {
    #expect(try session(valuePerPointCents: 1).valuePerPointCents == 1)
    #expect(try session(valuePerPointCents: 200).valuePerPointCents == 200)
    #expect(throws: GameRuleError.invalidMoneyValue) {
        try session(valuePerPointCents: 0)
    }
    #expect(throws: GameRuleError.invalidMoneyValue) {
        try session(valuePerPointCents: 201)
    }
}

@Test("Paus obriga todos os jogadores a ir a jogo")
func clubsSelectsEveryone() throws {
    var game = try session(count: 5)
    try GameEngine.selectTrump(.clubs, in: &game)
    #expect(game.phase == .assigningResults)
    #expect(game.participantIDs == game.players.map(\.id))
}

@Test("Fora de paus, quem escolhe o trunfo também tem de jogar")
func optionalParticipationRules() throws {
    var emptyGame = try session()
    try GameEngine.selectTrump(.diamonds, in: &emptyGame)
    #expect(throws: GameRuleError.noParticipants) {
        try GameEngine.selectParticipants([], in: &emptyGame)
    }

    var game = try session(firstChooserIndex: 0)
    try GameEngine.selectTrump(.spades, in: &game)
    let otherPlayerID = game.players[1].id
    #expect(throws: GameRuleError.mandatoryParticipantsMissing) {
        try GameEngine.selectParticipants([otherPlayerID], in: &game)
    }
    let chooserID = game.players[0].id
    try GameEngine.selectParticipants([chooserID], in: &game)
    #expect(game.participantIDs == [chooserID])
    #expect(game.roundIsReady)
}

@Test("A distribuição normal acompanha o saldo e atribui o último valor")
func normalDistribution() throws {
    var game = try session()
    try GameEngine.selectTrump(.spades, in: &game)
    try GameEngine.selectParticipants(Set(game.players.prefix(3).map(\.id)), in: &game)

    #expect(game.remainingRoundPoints == 5)
    #expect(GameEngine.availableResults(in: game) == [0, 1, 2, 3, 4, 5])
    try GameEngine.assignResult(2, in: &game)
    #expect(game.remainingRoundPoints == 3)
    try GameEngine.assignResult(0, in: &game)

    #expect(game.roundIsReady)
    #expect(game.results[game.players[0].id] == 2)
    #expect(game.results[game.players[1].id] == 0)
    #expect(game.results[game.players[2].id] == 3)
    #expect(game.remainingRoundPoints == 0)
}

@Test("Copas aceita apenas valores pares e totaliza dez")
func heartsDoubleEverything() throws {
    var game = try session()
    try GameEngine.selectTrump(.hearts, in: &game)
    try GameEngine.selectParticipants(Set(game.players.prefix(3).map(\.id)), in: &game)

    #expect(GameEngine.availableResults(in: game) == [0, 2, 4, 6, 8, 10])
    #expect(throws: GameRuleError.invalidResult) {
        try GameEngine.assignResult(3, in: &game)
    }
    try GameEngine.assignResult(2, in: &game)
    try GameEngine.assignResult(4, in: &game)

    #expect(game.results[game.players[2].id] == 4)
    #expect(game.results.values.reduce(0, +) == 10)
}

@Test("Zero faz subir, resultado positivo desce e ausentes não mudam")
func scoringAndNonParticipants() throws {
    var game = try session()
    try GameEngine.selectTrump(.diamonds, in: &game)
    try GameEngine.selectParticipants(Set(game.players.prefix(3).map(\.id)), in: &game)
    try GameEngine.assignResult(0, in: &game)
    try GameEngine.assignResult(2, in: &game)
    try GameEngine.closeRound(in: &game)

    #expect(game.players.map(\.score) == [25, 18, 17, 20])
}

@Test("Em copas, zero sobe dez pontos")
func heartsZeroAddsTen() throws {
    var game = try session()
    try GameEngine.selectTrump(.hearts, in: &game)
    try GameEngine.selectParticipants(Set(game.players.prefix(3).map(\.id)), in: &game)
    try GameEngine.assignResult(0, in: &game)
    try GameEngine.assignResult(4, in: &game)
    try GameEngine.closeRound(in: &game)

    #expect(game.players.map(\.score) == [30, 16, 14, 20])
}

@Test("A ronda incompleta não pode ser fechada")
func incompleteRoundIsRejected() throws {
    var game = try session()
    try GameEngine.selectTrump(.clubs, in: &game)
    #expect(throws: GameRuleError.incompleteRound) {
        try GameEngine.closeRound(in: &game)
    }
}

@Test("A configuração da ronda pode ser corrigida sem alterar a partida")
func roundSetupCanBeRestarted() throws {
    var game = try session()
    let playersBefore = game.players
    try GameEngine.selectTrump(.diamonds, in: &game)
    try GameEngine.selectParticipants(Set(game.players.prefix(3).map(\.id)), in: &game)
    try GameEngine.assignResult(2, in: &game)

    try GameEngine.restartRoundSetup(in: &game)

    #expect(game.phase == .choosingTrump)
    #expect(game.currentSuit == nil)
    #expect(game.participantIDs.isEmpty)
    #expect(game.results.isEmpty)
    #expect(game.players == playersBefore)
}

@Test("A rotação segue a mesa e dá a volta")
func chooserRotation() throws {
    var game = try session(count: 5, firstChooserIndex: 3)
    #expect(game.chooser?.tablePosition == 3)

    for expectedNext in [4, 0, 1] {
        try GameEngine.selectTrump(.spades, in: &game)
        try GameEngine.selectParticipants(GameEngine.requiredParticipantIDs(in: game), in: &game)
        if !game.roundIsReady {
            try GameEngine.assignResult(5, in: &game)
        }
        try GameEngine.closeRound(in: &game)
        try GameEngine.startNextRound(in: &game)
        #expect(game.chooser?.tablePosition == expectedNext)
    }
}

@Test("Escolher o trunfo conta uma vez quando a ronda fecha")
func trumpChoiceCountIsAtomic() throws {
    var game = try session()
    try GameEngine.selectTrump(.spades, in: &game)
    #expect(game.players[0].trumpChoiceCount == 0)
    try GameEngine.selectParticipants([game.players[0].id], in: &game)
    try GameEngine.closeRound(in: &game)
    #expect(game.players[0].trumpChoiceCount == 1)
    #expect(throws: GameRuleError.invalidPhase) {
        try GameEngine.closeRound(in: &game)
    }
    #expect(game.players[0].trumpChoiceCount == 1)
}

@Test("A classificação desempata sem alterar a ordem da mesa")
func standingsTieBreaks() throws {
    var game = try session()
    let originalOrder = game.players.map(\.id)
    game.players[0].score = 12
    game.players[0].trumpChoiceCount = 2
    game.players[1].score = 8
    game.players[1].trumpChoiceCount = 3
    game.players[2].score = 12
    game.players[2].trumpChoiceCount = 1
    game.players[3].score = 12
    game.players[3].trumpChoiceCount = 1

    let ordered = GameEngine.standings(in: game)
    #expect(ordered.map(\.tablePosition) == [1, 2, 3, 0])
    #expect(game.players.map(\.id) == originalOrder)
}

@Test("Chegar abaixo de zero termina em zero e dá a vitória")
func overshootingZeroWins() throws {
    var game = try session()
    game.players[0].score = 1
    try GameEngine.selectTrump(.spades, in: &game)
    try GameEngine.selectParticipants([game.players[0].id], in: &game)
    try GameEngine.closeRound(in: &game)

    #expect(game.players[0].score == 0)
    #expect(game.winnerID == game.players[0].id)
    #expect(game.phase == .finished)
}

@Test("Uma vitória simultânea usa a ordem física como desempate")
func simultaneousWinUsesTableOrder() throws {
    var game = try session()
    game.players[0].score = 1
    game.players[1].score = 4
    try GameEngine.selectTrump(.spades, in: &game)
    try GameEngine.selectParticipants(Set(game.players.prefix(2).map(\.id)), in: &game)
    try GameEngine.assignResult(1, in: &game)
    try GameEngine.closeRound(in: &game)

    #expect(game.players[0].score == 0)
    #expect(game.players[1].score == 0)
    #expect(game.winnerID == game.players[0].id)
    #expect(try GameEngine.finalStandings(in: game).first?.id == game.winnerID)
}

@Test("Um snapshot com chooser inválido é rejeitado sem indexar o array")
func invalidChooserSnapshotIsRejected() throws {
    var game = try session()
    game.chooserIndex = 99

    #expect(throws: GameRuleError.invalidSession) {
        try GameEngine.validate(game)
    }
    #expect(throws: GameRuleError.invalidSession) {
        try GameEngine.selectTrump(.clubs, in: &game)
    }
}

@Test("Um snapshot com participante desconhecido não pode fechar a ronda")
func unknownParticipantSnapshotIsRejected() throws {
    var game = try session()
    try GameEngine.selectTrump(.spades, in: &game)
    let unknownID = UUID()
    game.phase = .assigningResults
    game.participantIDs = [unknownID]
    game.results = [unknownID: 5]
    game.assignmentIndex = 1

    #expect(throws: GameRuleError.invalidSession) {
        try GameEngine.closeRound(in: &game)
    }
}

@Test("O acerto monetário multiplica os pontos finais pelo valor por ponto")
func settlementsAreCalculatedInCents() throws {
    var game = try session(valuePerPointCents: 100)
    game.players[0].score = 5
    game.players[1].score = 50
    game.players[2].score = 7
    game.players[3].score = 2
    try GameEngine.selectTrump(.spades, in: &game)
    try GameEngine.selectParticipants([game.players[0].id], in: &game)
    try GameEngine.closeRound(in: &game)

    let settlements = try GameEngine.settlements(in: game)
    #expect(settlements.map(\.amountCents) == [5_000, 700, 200])
    #expect(try GameEngine.totalToReceive(in: game) == 5_900)
}

@Test("Sem dinheiro, o resumo não tem valores monetários")
func moneyOffHasNoSettlements() throws {
    var game = try session()
    game.players[0].score = 5
    try GameEngine.selectTrump(.spades, in: &game)
    try GameEngine.selectParticipants([game.players[0].id], in: &game)
    try GameEngine.closeRound(in: &game)
    #expect(try GameEngine.settlements(in: game).isEmpty)
}

@Test("A sessão conserva a ronda em curso num ciclo Codable")
func codableRoundTrip() throws {
    var game = try session(count: 5, firstChooserIndex: 2, valuePerPointCents: 25)
    try GameEngine.selectTrump(.hearts, in: &game)
    try GameEngine.selectParticipants(Set(game.players.prefix(4).map(\.id)), in: &game)
    try GameEngine.assignResult(2, in: &game)

    let data = try JSONEncoder().encode(game)
    let restored = try JSONDecoder().decode(GameSession.self, from: data)
    #expect(restored == game)
    #expect(restored.remainingRoundPoints == 8)
}

@Test("O parser monetário aceita vírgula ou ponto sem arredondar")
func euroParser() {
    #expect(EuroMoney.cents(from: "0,01") == 1)
    #expect(EuroMoney.cents(from: "1.5") == 150)
    #expect(EuroMoney.cents(from: "2") == 200)
    #expect(EuroMoney.cents(from: "0,001") == nil)
    #expect(EuroMoney.cents(from: "-1") == nil)
}

@Test("Copas às cegas tem vinte pontos e quatro pontos por jogada")
func blindHeartsDistributionAndScoring() throws {
    var game = try session()
    try GameEngine.selectTrump(.blindHearts, in: &game)
    try GameEngine.selectParticipants(Set(game.players.prefix(3).map(\.id)), in: &game)
    #expect(game.currentSuit?.name == "Copas às cegas")
    #expect(GameEngine.availableResults(in: game) == [0, 4, 8, 12, 16, 20])
    #expect(throws: GameRuleError.invalidResult) {
        try GameEngine.assignResult(2, in: &game)
    }
    try GameEngine.assignResult(0, in: &game)
    try GameEngine.assignResult(8, in: &game)
    #expect(game.results[game.players[2].id] == 12)
    #expect(game.roundIsReady)
    try GameEngine.closeRound(in: &game)
    #expect(game.players.map(\.score) == [40, 12, 8, 20])
    try GameEngine.validate(game)
}

@Test("O responsável pelo trunfo é obrigatório em todos os modos", arguments: Suit.allCases)
func chooserIsRequiredForEverySuit(suit: Suit) throws {
    var game = try session(firstChooserIndex: 2)
    try GameEngine.selectTrump(suit, in: &game)
    let chooserID = game.players[2].id
    #expect(GameEngine.requiredParticipantIDs(in: game).contains(chooserID))
    #expect(GameEngine.participationRequirement(for: chooserID, in: game)
            == (suit == .clubs ? .clubs : .trumpChooser))
    if suit != .clubs {
        #expect(throws: GameRuleError.mandatoryParticipantsMissing) {
            try GameEngine.selectParticipants([game.players[0].id], in: &game)
        }
        #expect(game.phase == .choosingParticipants)
        #expect(game.participantIDs.isEmpty)
    }
}

@Test("Duas ausências obrigam à terceira ronda e a participação reinicia a contagem")
func thirdRoundParticipationIsMandatory() throws {
    var game = try session()
    let absentPlayerID = game.players[3].id
    for expectedAbsences in 1...2 {
        try GameEngine.selectTrump(.diamonds, in: &game)
        try GameEngine.selectParticipants([try #require(game.chooser?.id)], in: &game)
        #expect(game.players[3].consecutiveAbsences == expectedAbsences - 1)
        try GameEngine.closeRound(in: &game)
        #expect(game.players[3].consecutiveAbsences == expectedAbsences)
        try GameEngine.validate(game)
        try GameEngine.startNextRound(in: &game)
    }
    try GameEngine.selectTrump(.hearts, in: &game)
    #expect(GameEngine.participationRequirement(for: absentPlayerID, in: game) == .consecutiveAbsences)
    let mandatoryIDs = GameEngine.requiredParticipantIDs(in: game)
    #expect(mandatoryIDs == Set([game.players[2].id, absentPlayerID]))
    #expect(throws: GameRuleError.mandatoryParticipantsMissing) {
        try GameEngine.selectParticipants(mandatoryIDs.subtracting([absentPlayerID]), in: &game)
    }
    try GameEngine.selectParticipants(mandatoryIDs, in: &game)
    try GameEngine.assignResult(4, in: &game)
    try GameEngine.closeRound(in: &game)
    #expect(game.players[3].consecutiveAbsences == 0)
    #expect(game.players[2].consecutiveAbsences == 0)
    try GameEngine.validate(game)
    try GameEngine.startNextRound(in: &game)
    #expect(game.players[3].consecutiveAbsences == 0)
}

@Test("Paus reinicia todas as sequências de ausência")
func clubsResetsAbsences() throws {
    var game = try session()
    game.players[2].consecutiveAbsences = 2
    game.players[3].consecutiveAbsences = 1
    try GameEngine.selectTrump(.clubs, in: &game)
    try GameEngine.assignResult(5, in: &game)
    try GameEngine.closeRound(in: &game)
    #expect(game.players.allSatisfy { $0.consecutiveAbsences == 0 })
    try GameEngine.validate(game)
}

@Test("Corrigir a ronda não conta ausências nem escolhas de trunfo")
func correctionsPreserveParticipationCounters() throws {
    var game = try session()
    game.players[3].consecutiveAbsences = 2
    let initialPlayers = game.players
    try GameEngine.selectTrump(.spades, in: &game)
    try GameEngine.selectParticipants(GameEngine.requiredParticipantIDs(in: game), in: &game)
    try GameEngine.assignResult(5, in: &game)
    try GameEngine.restartAssignments(in: &game)
    #expect(game.players == initialPlayers)
    try GameEngine.restartRoundSetup(in: &game)
    #expect(game.players == initialPlayers)
    #expect(GameEngine.requiredParticipantIDs(in: game).contains(game.players[3].id))
}

@Test("Saldo esgotado preenche zeros e mantém a verificação antes de pontuar", arguments: Suit.allCases)
func automaticZerosRequireExplicitConfirmation(suit: Suit) throws {
    var game = try session(count: 5)
    try GameEngine.selectTrump(suit, in: &game)
    if suit != .clubs {
        try GameEngine.selectParticipants(Set(game.players.map(\.id)), in: &game)
    }
    let initialPlayers = game.players
    try GameEngine.assignResult(suit.roundTotal, in: &game)
    #expect(game.results[game.players[0].id] == suit.roundTotal)
    #expect(game.players.dropFirst().allSatisfy { game.results[$0.id] == 0 })
    #expect(game.assignmentIndex == 5)
    #expect(game.currentParticipant == nil)
    #expect(game.roundIsReady)
    #expect(game.phase == .assigningResults)
    #expect(game.players == initialPlayers)
    try GameEngine.validate(game)
    try GameEngine.restartAssignments(in: &game)
    #expect(game.results.isEmpty)
    #expect(game.assignmentIndex == 0)
    try GameEngine.assignResult(0, in: &game)
    try GameEngine.assignResult(suit.roundTotal, in: &game)
    #expect(game.results[game.players[0].id] == 0)
    #expect(game.results[game.players[1].id] == suit.roundTotal)
    #expect(game.phase == .assigningResults)
    try GameEngine.closeRound(in: &game)
    #expect(game.players[0].score == 20 + suit.zeroIncrease)
    #expect(game.players[1].score == max(0, 20 - suit.roundTotal))
}

@Test("Snapshots não podem contornar participantes obrigatórios")
func missingMandatoryParticipantSnapshotIsRejected() throws {
    for omitChooser in [true, false] {
        var game = try session()
        game.players[3].consecutiveAbsences = 2
        try GameEngine.selectTrump(.spades, in: &game)
        let selectedID = omitChooser ? game.players[3].id : game.players[0].id
        game.phase = .assigningResults
        game.participantIDs = [selectedID]
        game.results = [selectedID: 5]
        game.assignmentIndex = 1
        #expect(throws: GameRuleError.invalidSession) {
            try GameEngine.closeRound(in: &game)
        }
        #expect(throws: GameRuleError.invalidSession) {
            try JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(game))
        }
    }
}

@Test("Contadores inválidos são rejeitados e os contadores válidos persistem")
func absenceCounterValidationAndPersistence() throws {
    var game = try session()
    game.players[2].consecutiveAbsences = 2
    let restored = try JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(game))
    #expect(restored.players[2].consecutiveAbsences == 2)
    for invalidCount in [-1, 3] {
        game.players[2].consecutiveAbsences = invalidCount
        #expect(throws: GameRuleError.invalidSession) { try GameEngine.validate(game) }
    }
}

private func legacyPayload(from game: GameSession) throws -> Data {
    var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(game)) as? [String: Any])
    for key in ["name", "createdAt", "rulesVersion"] {
        object.removeValue(forKey: key)
    }
    var players = try #require(object["players"] as? [[String: Any]])
    for index in players.indices {
        players[index].removeValue(forKey: "consecutiveAbsences")
    }
    object["players"] = players
    return try JSONSerialization.data(withJSONObject: object)
}

@Test("Partidas novas guardam nome e data; nomes vazios recebem um nome identificável")
func sessionNameAndDate() throws {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let named = try GameEngine.makeSession(
        name: "  Noite de cartas  ", createdAt: date,
        names: ["A", "B", "C", "D"], valuePerPointCents: nil, firstChooserIndex: 0
    )
    #expect(named.name == "Noite de cartas")
    #expect(named.createdAt == date)
    let unnamed = try GameEngine.makeSession(
        createdAt: date, names: ["A", "B", "C", "D"], valuePerPointCents: nil, firstChooserIndex: 0
    )
    #expect(unnamed.name.hasPrefix("Partida de "))
    #expect(unnamed.name.contains("2027"))
    #expect(try JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(named)) == named)
}

@Test("Uma ronda antiga sem o responsável pelo trunfo reabre a seleção sem perder pontuações")
func legacyActiveRoundMigration() throws {
    var oldGame = try session(firstChooserIndex: 2)
    oldGame.players[0].score = 13
    oldGame.currentSuit = .hearts
    oldGame.phase = .assigningResults
    oldGame.participantIDs = Array(oldGame.players.prefix(2).map(\.id))
    oldGame.results = [oldGame.players[0].id: 4]
    oldGame.assignmentIndex = 1
    var restored = try JSONDecoder().decode(GameSession.self, from: legacyPayload(from: oldGame))
    #expect(restored.rulesVersion == 2)
    #expect(restored.phase == .choosingParticipants)
    #expect(restored.currentSuit == .hearts)
    #expect(restored.participantIDs.isEmpty)
    #expect(restored.results.isEmpty)
    #expect(restored.players.map(\.score) == oldGame.players.map(\.score))
    #expect(restored.players.allSatisfy { $0.consecutiveAbsences == 0 })
    #expect(restored.createdAt == Date(timeIntervalSince1970: 0))
    let savedAt = Date(timeIntervalSince1970: 1_800_000_000)
    try GameEngine.restoreMetadata(in: &restored, fallbackDate: savedAt)
    #expect(restored.createdAt == savedAt)
    #expect(restored.name.hasPrefix("Partida de "))
    try GameEngine.validate(restored)
}

@Test("Rondas antigas válidas mantêm resultados e completam zeros sem fechar")
func legacyActiveRoundKeepsValidResults() throws {
    var oldGame = try session()
    oldGame.currentSuit = .diamonds
    oldGame.phase = .assigningResults
    oldGame.participantIDs = oldGame.players.map(\.id)
    oldGame.results = [oldGame.players[0].id: 5]
    oldGame.assignmentIndex = 1
    let restored = try JSONDecoder().decode(GameSession.self, from: legacyPayload(from: oldGame))
    #expect(restored.phase == .assigningResults)
    #expect(restored.rulesVersion == 2)
    #expect(restored.roundIsReady)
    #expect(restored.players.map(\.score) == [20, 20, 20, 20])
    #expect(restored.results[oldGame.players[0].id] == 5)
}

@Test("Partidas antigas concluídas mantêm vencedor e dívidas mesmo com o responsável de fora")
func legacyFinishedGameRemainsReadable() throws {
    var oldGame = try session(firstChooserIndex: 2, valuePerPointCents: 25)
    oldGame.phase = .finished
    oldGame.currentSuit = .spades
    oldGame.participantIDs = [oldGame.players[0].id]
    oldGame.results = [oldGame.players[0].id: 5]
    oldGame.assignmentIndex = 1
    oldGame.players[0].score = 0
    oldGame.winnerID = oldGame.players[0].id
    let restored = try JSONDecoder().decode(GameSession.self, from: legacyPayload(from: oldGame))
    #expect(restored.rulesVersion == 1)
    #expect(restored.phase == .finished)
    #expect(restored.winnerID == oldGame.winnerID)
    #expect(try GameEngine.totalToReceive(in: restored) == 1_500)
    #expect(try JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(restored)) == restored)
}

@Test("A ronda seguinte de uma partida antiga adota as regras atuais")
func legacyStandingsAdoptCurrentRulesOnNextRound() throws {
    var oldGame = try session(firstChooserIndex: 2)
    oldGame.phase = .standings
    oldGame.currentSuit = .spades
    oldGame.participantIDs = [oldGame.players[0].id]
    oldGame.results = [oldGame.players[0].id: 5]
    oldGame.assignmentIndex = 1
    oldGame.players[0].score = 15
    var restored = try JSONDecoder().decode(GameSession.self, from: legacyPayload(from: oldGame))
    #expect(restored.rulesVersion == 1)
    try GameEngine.startNextRound(in: &restored)
    #expect(restored.rulesVersion == 2)
    #expect(restored.chooserIndex == 3)
    #expect(restored.players[0].score == 15)
    #expect(restored.players.map(\.consecutiveAbsences) == [0, 1, 1, 1])
    try GameEngine.selectTrump(.diamonds, in: &restored)
    #expect(throws: GameRuleError.mandatoryParticipantsMissing) {
        try GameEngine.selectParticipants([restored.players[0].id], in: &restored)
    }
    try GameEngine.selectParticipants([restored.players[3].id], in: &restored)
    try GameEngine.closeRound(in: &restored)
    try GameEngine.startNextRound(in: &restored)
    #expect(GameEngine.requiredParticipantIDs(in: restored)
            == Set(restored.players.prefix(3).map(\.id)))
}

@Test("Valores extremos num snapshot são rejeitados sem falhar nem alterar parte da ronda")
func scoreAndChoiceCountOverflowAreAtomic() throws {
    for overflowsScore in [true, false] {
        var game = try session()
        if overflowsScore {
            game.players[2].score = Int.max
        } else {
            game.players[0].trumpChoiceCount = Int.max
        }
        try GameEngine.selectTrump(.blindHearts, in: &game)
        try GameEngine.selectParticipants(Set(game.players.map(\.id)), in: &game)
        try GameEngine.assignResult(8, in: &game)
        try GameEngine.assignResult(4, in: &game)
        try GameEngine.assignResult(0, in: &game)
        let beforeClosing = game
        #expect(throws: GameRuleError.invalidSession) { try GameEngine.closeRound(in: &game) }
        #expect(game == beforeClosing)
    }
}

@Test("Um número de ronda extremo não provoca falha ao avançar")
func roundNumberOverflowIsRejected() throws {
    var game = try session()
    try GameEngine.selectTrump(.spades, in: &game)
    try GameEngine.selectParticipants([game.players[0].id], in: &game)
    try GameEngine.closeRound(in: &game)
    game.roundNumber = Int.max
    let beforeStarting = game
    #expect(throws: GameRuleError.invalidSession) { try GameEngine.startNextRound(in: &game) }
    #expect(game == beforeStarting)
}
