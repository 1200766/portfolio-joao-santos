import Foundation

public enum Suit: String, CaseIterable, Codable, Identifiable, Sendable {
    case clubs
    case hearts
    case blindHearts
    case spades
    case diamonds

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .clubs: "Paus"
        case .hearts: "Copas"
        case .blindHearts: "Copas às cegas"
        case .spades: "Espadas"
        case .diamonds: "Ouros"
        }
    }

    public var symbol: String {
        switch self {
        case .clubs: "♣︎"
        case .hearts, .blindHearts: "♥︎"
        case .spades: "♠︎"
        case .diamonds: "♦︎"
        }
    }

    public var roundTotal: Int {
        switch self {
        case .blindHearts: 20
        case .hearts: 10
        default: 5
        }
    }

    public var resultStep: Int {
        switch self {
        case .blindHearts: 4
        case .hearts: 2
        default: 1
        }
    }

    public var zeroIncrease: Int {
        roundTotal
    }

    public var forcesEveryPlayer: Bool {
        self == .clubs
    }
}

public struct Player: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let tablePosition: Int
    public internal(set) var score: Int
    public internal(set) var trumpChoiceCount: Int
    public internal(set) var consecutiveAbsences: Int

    public init(
        id: UUID = UUID(),
        name: String,
        tablePosition: Int,
        score: Int = 20,
        trumpChoiceCount: Int = 0,
        consecutiveAbsences: Int = 0
    ) {
        self.id = id
        self.name = name
        self.tablePosition = tablePosition
        self.score = score
        self.trumpChoiceCount = trumpChoiceCount
        self.consecutiveAbsences = consecutiveAbsences
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, tablePosition, score, trumpChoiceCount, consecutiveAbsences
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        tablePosition = try container.decode(Int.self, forKey: .tablePosition)
        score = try container.decode(Int.self, forKey: .score)
        trumpChoiceCount = try container.decode(Int.self, forKey: .trumpChoiceCount)
        consecutiveAbsences = try container.decodeIfPresent(Int.self, forKey: .consecutiveAbsences) ?? 0
    }
}

public enum ParticipationRequirement: Equatable, Sendable {
    case clubs
    case trumpChooser
    case consecutiveAbsences

    public var description: String {
        switch self {
        case .clubs: "Em paus, todos têm de ir a jogo."
        case .trumpChooser: "Quem escolhe o trunfo tem de ir a jogo."
        case .consecutiveAbsences: "Ficou de fora nas duas rondas anteriores. Tem de ir a jogo."
        }
    }
}

public enum GamePhase: String, Codable, Equatable, Sendable {
    case choosingTrump
    case choosingParticipants
    case assigningResults
    case standings
    case finished
}

public struct GameSession: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public internal(set) var name: String
    public internal(set) var createdAt: Date
    public internal(set) var rulesVersion: Int
    public internal(set) var players: [Player]
    public let valuePerPointCents: Int?
    public internal(set) var roundNumber: Int
    public internal(set) var chooserIndex: Int
    public internal(set) var phase: GamePhase
    public internal(set) var currentSuit: Suit?
    public internal(set) var participantIDs: [UUID]
    public internal(set) var results: [UUID: Int]
    public internal(set) var assignmentIndex: Int
    public internal(set) var winnerID: UUID?

    init(
        id: UUID = UUID(),
        name: String = "Partida guardada",
        createdAt: Date = Date(),
        rulesVersion: Int = 2,
        players: [Player],
        valuePerPointCents: Int?,
        roundNumber: Int = 1,
        chooserIndex: Int,
        phase: GamePhase = .choosingTrump,
        currentSuit: Suit? = nil,
        participantIDs: [UUID] = [],
        results: [UUID: Int] = [:],
        assignmentIndex: Int = 0,
        winnerID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.rulesVersion = rulesVersion
        self.players = players
        self.valuePerPointCents = valuePerPointCents
        self.roundNumber = roundNumber
        self.chooserIndex = chooserIndex
        self.phase = phase
        self.currentSuit = currentSuit
        self.participantIDs = participantIDs
        self.results = results
        self.assignmentIndex = assignmentIndex
        self.winnerID = winnerID
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, createdAt, rulesVersion, players, valuePerPointCents
        case roundNumber, chooserIndex, phase, currentSuit, participantIDs
        case results, assignmentIndex, winnerID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Partida guardada"
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
            ?? Date(timeIntervalSince1970: 0)
        rulesVersion = try container.decodeIfPresent(Int.self, forKey: .rulesVersion) ?? 1
        players = try container.decode([Player].self, forKey: .players)
        valuePerPointCents = try container.decodeIfPresent(Int.self, forKey: .valuePerPointCents)
        roundNumber = try container.decode(Int.self, forKey: .roundNumber)
        chooserIndex = try container.decode(Int.self, forKey: .chooserIndex)
        phase = try container.decode(GamePhase.self, forKey: .phase)
        currentSuit = try container.decodeIfPresent(Suit.self, forKey: .currentSuit)
        participantIDs = try container.decode([UUID].self, forKey: .participantIDs)
        results = try container.decode([UUID: Int].self, forKey: .results)
        assignmentIndex = try container.decode(Int.self, forKey: .assignmentIndex)
        winnerID = try container.decodeIfPresent(UUID.self, forKey: .winnerID)
        try GameEngine.migrateLegacySession(in: &self)
    }

    public var chooser: Player? {
        players.indices.contains(chooserIndex) ? players[chooserIndex] : nil
    }

    public var winner: Player? {
        guard let winnerID else { return nil }
        return players.first { $0.id == winnerID }
    }

    public var currentParticipantID: UUID? {
        guard phase == .assigningResults,
              participantIDs.indices.contains(assignmentIndex) else {
            return nil
        }
        return participantIDs[assignmentIndex]
    }

    public var currentParticipant: Player? {
        guard let currentParticipantID else { return nil }
        return players.first { $0.id == currentParticipantID }
    }

    public var remainingRoundPoints: Int {
        max(0, (currentSuit?.roundTotal ?? 0) - results.values.reduce(0, +))
    }

    public var roundIsReady: Bool {
        guard let currentSuit,
              !participantIDs.isEmpty,
              results.count == participantIDs.count,
              Set(results.keys) == Set(participantIDs) else {
            return false
        }
        return results.values.reduce(0, +) == currentSuit.roundTotal
    }
}

public struct Settlement: Identifiable, Equatable, Sendable {
    public let playerID: UUID
    public let playerName: String
    public let finalScore: Int
    public let amountCents: Int64

    public var id: UUID { playerID }

    public init(playerID: UUID, playerName: String, finalScore: Int, amountCents: Int64) {
        self.playerID = playerID
        self.playerName = playerName
        self.finalScore = finalScore
        self.amountCents = amountCents
    }
}
