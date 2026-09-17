import Foundation

public enum GameRuleError: Error, Equatable, LocalizedError, Sendable {
    case invalidPlayerCount
    case emptyPlayerName(position: Int)
    case invalidMoneyValue
    case invalidFirstChooser
    case invalidPhase
    case noParticipants
    case invalidParticipants
    case mandatoryParticipantsMissing
    case invalidResult
    case incompleteRound
    case noWinner
    case invalidSession

    public var errorDescription: String? {
        switch self {
        case .invalidPlayerCount:
            "A partida tem de ter exatamente 4 ou 5 jogadores."
        case let .emptyPlayerName(position):
            "Falta o nome do jogador no lugar \(position + 1)."
        case .invalidMoneyValue:
            "O valor por ponto tem de estar entre 0,01 € e 2,00 €."
        case .invalidFirstChooser:
            "Escolhe quem recebeu o rei de copas."
        case .invalidPhase:
            "Esta ação não está disponível neste momento da partida."
        case .noParticipants:
            "Pelo menos uma pessoa tem de ir a jogo."
        case .invalidParticipants:
            "A seleção de participantes não é válida."
        case .mandatoryParticipantsMissing:
            "Inclui quem escolheu o trunfo e quem ficou de fora nas duas rondas anteriores."
        case .invalidResult:
            "Esse resultado não pode ser atribuído nesta ronda."
        case .incompleteRound:
            "Ainda falta distribuir o total de pontos da ronda."
        case .noWinner:
            "A partida ainda não tem vencedor."
        case .invalidSession:
            "Os dados da partida não são válidos. Começa uma nova partida."
        }
    }
}

public enum GameEngine {
    public static func makeSession(
        name: String = "",
        createdAt: Date = Date(),
        names: [String],
        valuePerPointCents: Int?,
        firstChooserIndex: Int
    ) throws -> GameSession {
        guard createdAt.timeIntervalSinceReferenceDate.isFinite else {
            throw GameRuleError.invalidSession
        }
        guard names.count == 4 || names.count == 5 else {
            throw GameRuleError.invalidPlayerCount
        }

        let trimmedNames = names.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let emptyIndex = trimmedNames.firstIndex(where: \.isEmpty) {
            throw GameRuleError.emptyPlayerName(position: emptyIndex)
        }
        if let valuePerPointCents, !(1...200).contains(valuePerPointCents) {
            throw GameRuleError.invalidMoneyValue
        }
        guard trimmedNames.indices.contains(firstChooserIndex) else {
            throw GameRuleError.invalidFirstChooser
        }

        let players = trimmedNames.enumerated().map { index, name in
            Player(name: name, tablePosition: index)
        }
        let session = GameSession(
            name: normalizedSessionName(name, createdAt: createdAt),
            createdAt: createdAt,
            players: players,
            valuePerPointCents: valuePerPointCents,
            chooserIndex: firstChooserIndex
        )
        try validate(session)
        return session
    }

    public static func participationRequirement(
        for playerID: UUID,
        in session: GameSession
    ) -> ParticipationRequirement? {
        guard let player = session.players.first(where: { $0.id == playerID }) else {
            return nil
        }
        if session.currentSuit?.forcesEveryPlayer == true { return .clubs }
        if session.chooser?.id == playerID { return .trumpChooser }
        if player.consecutiveAbsences >= 2 { return .consecutiveAbsences }
        return nil
    }

    public static func requiredParticipantIDs(in session: GameSession) -> Set<UUID> {
        Set(session.players.compactMap { player in
            participationRequirement(for: player.id, in: session) == nil ? nil : player.id
        })
    }

    /// Uses the existing storage date only when an older snapshot had no date.
    public static func restoreMetadata(
        in session: inout GameSession,
        fallbackDate: Date
    ) throws {
        try validate(session)
        guard fallbackDate.timeIntervalSinceReferenceDate.isFinite else {
            throw GameRuleError.invalidSession
        }
        if session.createdAt == Date(timeIntervalSince1970: 0) {
            session.createdAt = fallbackDate
            if session.name == "Partida guardada" {
                session.name = normalizedSessionName("", createdAt: fallbackDate)
            }
        }
    }

    public static func selectTrump(_ suit: Suit, in session: inout GameSession) throws {
        try validate(session)
        guard session.phase == .choosingTrump else {
            throw GameRuleError.invalidPhase
        }

        session.currentSuit = suit
        session.participantIDs = []
        session.results = [:]
        session.assignmentIndex = 0

        if suit.forcesEveryPlayer {
            session.participantIDs = session.players.map(\.id)
            session.phase = .assigningResults
            autoAssignResultsIfNeeded(in: &session)
        } else {
            session.phase = .choosingParticipants
        }
    }

    public static func selectParticipants(
        _ playerIDs: Set<UUID>,
        in session: inout GameSession
    ) throws {
        try validate(session)
        guard session.phase == .choosingParticipants,
              let suit = session.currentSuit,
              !suit.forcesEveryPlayer else {
            throw GameRuleError.invalidPhase
        }
        guard !playerIDs.isEmpty else {
            throw GameRuleError.noParticipants
        }

        let knownIDs = Set(session.players.map(\.id))
        guard playerIDs.isSubset(of: knownIDs) else {
            throw GameRuleError.invalidParticipants
        }
        guard requiredParticipantIDs(in: session).isSubset(of: playerIDs) else {
            throw GameRuleError.mandatoryParticipantsMissing
        }

        session.participantIDs = session.players
            .filter { playerIDs.contains($0.id) }
            .map(\.id)
        session.results = [:]
        session.assignmentIndex = 0
        session.phase = .assigningResults
        autoAssignResultsIfNeeded(in: &session)
    }

    public static func availableResults(in session: GameSession) -> [Int] {
        guard session.phase == .assigningResults,
              session.currentParticipantID != nil,
              let suit = session.currentSuit else {
            return []
        }

        return Array(stride(
            from: 0,
            through: session.remainingRoundPoints,
            by: suit.resultStep
        ))
    }

    public static func assignResult(_ result: Int, in session: inout GameSession) throws {
        try validate(session)
        guard session.phase == .assigningResults,
              let playerID = session.currentParticipantID else {
            throw GameRuleError.invalidPhase
        }
        guard availableResults(in: session).contains(result) else {
            throw GameRuleError.invalidResult
        }

        session.results[playerID] = result
        session.assignmentIndex += 1
        autoAssignResultsIfNeeded(in: &session)
    }

    public static func restartAssignments(in session: inout GameSession) throws {
        try validate(session)
        guard session.phase == .assigningResults else {
            throw GameRuleError.invalidPhase
        }
        session.results = [:]
        session.assignmentIndex = 0
        autoAssignResultsIfNeeded(in: &session)
    }

    public static func restartRoundSetup(in session: inout GameSession) throws {
        try validate(session)
        guard session.phase == .choosingParticipants || session.phase == .assigningResults else {
            throw GameRuleError.invalidPhase
        }

        session.phase = .choosingTrump
        session.currentSuit = nil
        session.participantIDs = []
        session.results = [:]
        session.assignmentIndex = 0
    }

    public static func closeRound(in session: inout GameSession) throws {
        try validate(session)
        guard session.phase == .assigningResults,
              let suit = session.currentSuit else {
            throw GameRuleError.invalidPhase
        }
        try validateRoundReady(session)

        let participantIDs = Set(session.participantIDs)
        var updatedPlayers = session.players
        for index in updatedPlayers.indices {
            let playerID = updatedPlayers[index].id
            updatedPlayers[index].consecutiveAbsences = participantIDs.contains(playerID)
                ? 0 : updatedPlayers[index].consecutiveAbsences + 1
            guard participantIDs.contains(playerID),
                  let result = session.results[playerID] else {
                continue
            }

            if result == 0 {
                let (newScore, overflow) = updatedPlayers[index].score.addingReportingOverflow(
                    suit.zeroIncrease
                )
                guard !overflow else { throw GameRuleError.invalidSession }
                updatedPlayers[index].score = newScore
            } else {
                // Hipótese do MVP: chegar a zero ou ultrapassá-lo vence.
                updatedPlayers[index].score = max(0, updatedPlayers[index].score - result)
            }
        }

        let (newChoiceCount, choiceCountOverflow) = updatedPlayers[session.chooserIndex]
            .trumpChoiceCount.addingReportingOverflow(1)
        guard !choiceCountOverflow else { throw GameRuleError.invalidSession }
        updatedPlayers[session.chooserIndex].trumpChoiceCount = newChoiceCount
        session.players = updatedPlayers

        // Hipótese do MVP: em vitória simultânea prevalece a ordem física da mesa.
        if let winner = session.players
            .filter({ $0.score == 0 })
            .min(by: { $0.tablePosition < $1.tablePosition }) {
            session.winnerID = winner.id
            session.phase = .finished
        } else {
            session.phase = .standings
        }
    }

    public static func startNextRound(in session: inout GameSession) throws {
        try validate(session)
        guard session.phase == .standings else {
            throw GameRuleError.invalidPhase
        }
        let (nextRoundNumber, overflow) = session.roundNumber.addingReportingOverflow(1)
        guard !overflow else { throw GameRuleError.invalidSession }

        if session.rulesVersion == 1 {
            let previousParticipants = Set(session.participantIDs)
            for index in session.players.indices {
                // The previous round is known, but older rounds are not stored.
                session.players[index].consecutiveAbsences = previousParticipants.contains(
                    session.players[index].id
                ) ? 0 : 1
            }
        }
        session.roundNumber = nextRoundNumber
        session.rulesVersion = 2
        session.chooserIndex = (session.chooserIndex + 1) % session.players.count
        session.phase = .choosingTrump
        session.currentSuit = nil
        session.participantIDs = []
        session.results = [:]
        session.assignmentIndex = 0
    }

    public static func standings(in session: GameSession) -> [Player] {
        session.players.sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score < rhs.score
            }
            if lhs.trumpChoiceCount != rhs.trumpChoiceCount {
                return lhs.trumpChoiceCount < rhs.trumpChoiceCount
            }
            return lhs.tablePosition < rhs.tablePosition
        }
    }

    public static func finalStandings(in session: GameSession) throws -> [Player] {
        try validate(session)
        guard session.phase == .finished,
              let winnerID = session.winnerID,
              let winner = session.players.first(where: { $0.id == winnerID }) else {
            throw GameRuleError.noWinner
        }

        return [winner] + standings(in: session).filter { $0.id != winnerID }
    }

    public static func settlements(in session: GameSession) throws -> [Settlement] {
        try validate(session)
        guard session.phase == .finished,
              let winnerID = session.winnerID else {
            throw GameRuleError.noWinner
        }
        guard let valuePerPointCents = session.valuePerPointCents else {
            return []
        }

        return try session.players.compactMap { player in
            guard player.id != winnerID else { return nil }
            let (amount, overflow) = Int64(player.score).multipliedReportingOverflow(
                by: Int64(valuePerPointCents)
            )
            guard !overflow else { throw GameRuleError.invalidSession }
            return Settlement(
                playerID: player.id,
                playerName: player.name,
                finalScore: player.score,
                amountCents: amount
            )
        }
    }

    public static func totalToReceive(in session: GameSession) throws -> Int64 {
        try settlements(in: session).reduce(0) { total, settlement in
            let (newTotal, overflow) = total.addingReportingOverflow(settlement.amountCents)
            guard !overflow else { throw GameRuleError.invalidSession }
            return newTotal
        }
    }

    public static func validate(_ session: GameSession) throws {
        guard session.players.count == 4 || session.players.count == 5,
              (1...2).contains(session.rulesVersion),
              !session.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              session.createdAt.timeIntervalSinceReferenceDate.isFinite,
              session.roundNumber >= 1,
              session.players.indices.contains(session.chooserIndex),
              Set(session.players.map(\.id)).count == session.players.count,
              session.players.enumerated().allSatisfy({ index, player in
                  player.tablePosition == index
                      && !player.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      && player.score >= 0
                      && player.trumpChoiceCount >= 0
                      && (0...2).contains(player.consecutiveAbsences)
              }),
              session.valuePerPointCents.map({ (1...200).contains($0) }) ?? true else {
            throw GameRuleError.invalidSession
        }

        let knownIDs = Set(session.players.map(\.id))
        let participantSet = Set(session.participantIDs)
        guard participantSet.count == session.participantIDs.count,
              participantSet.isSubset(of: knownIDs),
              session.players.filter({ participantSet.contains($0.id) }).map(\.id)
                == session.participantIDs,
              Set(session.results.keys).isSubset(of: participantSet),
              (0...session.participantIDs.count).contains(session.assignmentIndex) else {
            throw GameRuleError.invalidSession
        }

        if let suit = session.currentSuit {
            guard session.results.values.allSatisfy({ result in
                      (0...suit.roundTotal).contains(result)
                          && result.isMultiple(of: suit.resultStep)
                  }),
                  session.results.values.reduce(0, +) <= suit.roundTotal,
                  Set(session.participantIDs.prefix(session.assignmentIndex))
                    == Set(session.results.keys),
                  session.results.count == session.assignmentIndex else {
                throw GameRuleError.invalidSession
            }
        } else if !session.participantIDs.isEmpty
                    || !session.results.isEmpty
                    || session.assignmentIndex != 0 {
            throw GameRuleError.invalidSession
        }

        switch session.phase {
        case .choosingTrump:
            guard session.currentSuit == nil,
                  session.participantIDs.isEmpty,
                  session.results.isEmpty,
                  session.assignmentIndex == 0,
                  session.winnerID == nil,
                  session.players.allSatisfy({ $0.score > 0 }) else {
                throw GameRuleError.invalidSession
            }

        case .choosingParticipants:
            guard let suit = session.currentSuit,
                  !suit.forcesEveryPlayer,
                  session.participantIDs.isEmpty,
                  session.results.isEmpty,
                  session.assignmentIndex == 0,
                  session.winnerID == nil,
                  session.players.allSatisfy({ $0.score > 0 }) else {
                throw GameRuleError.invalidSession
            }

        case .assigningResults:
            guard let suit = session.currentSuit,
                  !session.participantIDs.isEmpty,
                  session.winnerID == nil,
                  session.players.allSatisfy({ $0.score > 0 }),
                  !suit.forcesEveryPlayer || session.participantIDs == session.players.map(\.id) else {
                throw GameRuleError.invalidSession
            }
            if session.rulesVersion >= 2,
               !requiredParticipantIDs(in: session).isSubset(of: participantSet) {
                throw GameRuleError.invalidSession
            }
            if session.assignmentIndex == session.participantIDs.count,
               session.results.values.reduce(0, +) != suit.roundTotal {
                throw GameRuleError.invalidSession
            }

        case .standings:
            guard session.winnerID == nil,
                  session.players.allSatisfy({ $0.score > 0 }),
                  session.assignmentIndex == session.participantIDs.count,
                  session.roundIsReady else {
                throw GameRuleError.invalidSession
            }

        case .finished:
            guard let winnerID = session.winnerID,
                  let winner = session.players.first(where: { $0.id == winnerID }),
                  winner.score == 0,
                  winner.tablePosition == session.players
                    .filter({ $0.score == 0 })
                    .map(\.tablePosition)
                    .min(),
                  session.assignmentIndex == session.participantIDs.count,
                  session.roundIsReady else {
                throw GameRuleError.invalidSession
            }
        }

        if session.rulesVersion >= 2,
           session.phase == .standings || session.phase == .finished {
            guard let chooserID = session.chooser?.id,
                  participantSet.contains(chooserID),
                  session.currentSuit?.forcesEveryPlayer != true
                    || session.participantIDs == session.players.map(\.id),
                  session.players.allSatisfy({ player in
                      participantSet.contains(player.id)
                        ? player.consecutiveAbsences == 0
                        : (1...2).contains(player.consecutiveAbsences)
                  }) else {
                throw GameRuleError.invalidSession
            }
        }
    }

    /// Old completed rounds retain their original rules. Unclosed rounds adopt
    /// the new participation rules without changing scores already accumulated.
    static func migrateLegacySession(in session: inout GameSession) throws {
        try validate(session)
        guard session.rulesVersion == 1,
              session.phase != .finished,
              session.phase != .standings else { return }

        session.rulesVersion = 2
        if session.phase == .assigningResults,
           !requiredParticipantIDs(in: session).isSubset(of: Set(session.participantIDs)) {
            session.phase = .choosingParticipants
            session.participantIDs = []
            session.results = [:]
            session.assignmentIndex = 0
        }
        autoAssignResultsIfNeeded(in: &session)
        try validate(session)
    }

    private static func normalizedSessionName(_ name: String, createdAt: Date) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty else { return trimmedName }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_PT")
        formatter.dateFormat = "dd/MM/yyyy 'às' HH:mm"
        return "Partida de \(formatter.string(from: createdAt))"
    }

    private static func autoAssignResultsIfNeeded(in session: inout GameSession) {
        guard session.phase == .assigningResults,
              session.assignmentIndex < session.participantIDs.count else {
            return
        }

        if session.remainingRoundPoints == 0 {
            for playerID in session.participantIDs.dropFirst(session.assignmentIndex) {
                session.results[playerID] = 0
            }
            session.assignmentIndex = session.participantIDs.count
            return
        }

        guard session.participantIDs.count - session.assignmentIndex == 1 else { return }

        let finalID = session.participantIDs[session.assignmentIndex]
        session.results[finalID] = session.remainingRoundPoints
        session.assignmentIndex += 1
    }

    private static func validateRoundReady(_ session: GameSession) throws {
        guard session.roundIsReady,
              let suit = session.currentSuit else {
            throw GameRuleError.incompleteRound
        }

        if suit.forcesEveryPlayer {
            guard session.participantIDs == session.players.map(\.id) else {
                throw GameRuleError.invalidParticipants
            }
        } else if session.participantIDs.isEmpty {
            throw GameRuleError.noParticipants
        }
        guard requiredParticipantIDs(in: session).isSubset(of: Set(session.participantIDs)) else {
            throw GameRuleError.mandatoryParticipantsMissing
        }

        let validRange = 0...suit.roundTotal
        guard session.results.values.allSatisfy({ result in
            validRange.contains(result) && result.isMultiple(of: suit.resultStep)
        }) else {
            throw GameRuleError.invalidResult
        }
    }
}

public enum EuroMoney {
    public static func cents(from input: String) -> Int? {
        let compact = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")

        guard !compact.isEmpty,
              !compact.hasPrefix("-"),
              compact.filter({ $0 == "." }).count <= 1 else {
            return nil
        }

        let pieces = compact.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count <= 2 else { return nil }

        let wholeText = pieces[0].isEmpty ? "0" : String(pieces[0])
        guard wholeText.allSatisfy(\.isNumber),
              let whole = Int(wholeText) else {
            return nil
        }

        let decimalText = pieces.count == 2 ? String(pieces[1]) : ""
        guard decimalText.count <= 2,
              decimalText.allSatisfy(\.isNumber) else {
            return nil
        }

        let paddedDecimal = decimalText.padding(
            toLength: 2,
            withPad: "0",
            startingAt: 0
        )
        guard let decimals = Int(paddedDecimal),
              whole <= (Int.max - decimals) / 100 else {
            return nil
        }
        return whole * 100 + decimals
    }

    public static func inputValue(cents: Int) -> String {
        String(format: "%d,%02d", cents / 100, cents % 100)
    }

    public static func formatted(cents: Int64) -> String {
        let amount = NSDecimalNumber(value: cents).decimalValue / 100
        return amount.formatted(
            .currency(code: "EUR").locale(Locale(identifier: "pt_PT"))
        )
    }
}
