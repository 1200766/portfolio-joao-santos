import Foundation
import SobeEDesceCore
import SwiftData

enum GameDisposition: Equatable, Sendable {
    case saveToHistory
    case discard
}

@Model
final class StoredGameSession {
    @Attribute(.unique) var slot: String
    var payload: Data
    var updatedAt: Date

    init(slot: String = "active", payload: Data, updatedAt: Date = .now) {
        self.slot = slot
        self.payload = payload
        self.updatedAt = updatedAt
    }
}

@MainActor
final class GameStore: ObservableObject {
    @Published private(set) var session: GameSession?
    @Published private(set) var history: [GameSession] = []
    @Published var errorMessage: String?

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadSession()
    }

    @discardableResult
    func startGame(
        name: String = "",
        names: [String],
        valuePerPointCents: Int?,
        firstChooserIndex: Int,
        previousGameDisposition: GameDisposition = .saveToHistory
    ) -> Bool {
        do {
            let newSession = try GameEngine.makeSession(
                name: name,
                names: names,
                valuePerPointCents: valuePerPointCents,
                firstChooserIndex: firstChooserIndex
            )
            // The previous snapshot and the new active game commit together.
            // A failed save must never discard the game being replaced.
            if previousGameDisposition == .saveToHistory {
                if let session {
                    try upsertHistory(session)
                } else {
                    try preserveUnreadableActiveRecord()
                }
            }
            try upsertActive(newSession)
            try modelContext.save()
            if previousGameDisposition == .saveToHistory, let session {
                includeInHistory(session)
            }
            session = newSession
            errorMessage = nil
            return true
        } catch {
            modelContext.rollback()
            report(error)
            return false
        }
    }

    func selectTrump(_ suit: Suit) {
        update { try GameEngine.selectTrump(suit, in: &$0) }
    }

    func selectParticipants(_ playerIDs: Set<UUID>) {
        update { try GameEngine.selectParticipants(playerIDs, in: &$0) }
    }

    func assignResult(_ result: Int) {
        update { try GameEngine.assignResult(result, in: &$0) }
    }

    func restartAssignments() {
        update { try GameEngine.restartAssignments(in: &$0) }
    }

    func restartRoundSetup() {
        update { try GameEngine.restartRoundSetup(in: &$0) }
    }

    func closeRound() {
        update { try GameEngine.closeRound(in: &$0) }
    }

    func startNextRound() {
        update { try GameEngine.startNextRound(in: &$0) }
    }

    @discardableResult
    func archiveCurrentGame() -> Bool {
        do {
            if let session {
                try upsertHistory(session)
            } else {
                try preserveUnreadableActiveRecord()
            }
            if let active = try record(in: "active") {
                modelContext.delete(active)
            }
            try modelContext.save()
            if let session { includeInHistory(session) }
            session = nil
            errorMessage = nil
            return true
        } catch {
            modelContext.rollback()
            report(error, prefix: "Não foi possível guardar a partida no histórico")
            return false
        }
    }

    @discardableResult
    func discardGame() -> Bool {
        do {
            // Discard only the active snapshot. Completed games and any
            // previously archived snapshots remain in the history.
            if let active = try record(in: "active") {
                modelContext.delete(active)
            }
            try modelContext.save()
            session = nil
            errorMessage = nil
            return true
        } catch {
            modelContext.rollback()
            report(error, prefix: "Não foi possível descartar a partida")
            return false
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func update(_ mutation: (inout GameSession) throws -> Void) {
        guard var candidate = session else { return }
        do {
            try mutation(&candidate)
            try GameEngine.validate(candidate)
            try persist(candidate)
            session = candidate
            if candidate.phase == .finished { includeInHistory(candidate) }
            errorMessage = nil
        } catch {
            modelContext.rollback()
            report(error)
        }
    }

    private func loadSession() {
        do {
            let records = try modelContext.fetch(FetchDescriptor<StoredGameSession>())
            var damagedRecordCount = 0
            for record in records where record.slot.hasPrefix("history-") {
                do {
                    includeInHistory(try restoredSession(from: record))
                } catch {
                    // Preserve unreadable records for recovery; one bad record
                    // must not prevent other games from being displayed.
                    damagedRecordCount += 1
                }
            }
            if let active = records.first(where: { $0.slot == "active" }) {
                do {
                    let restored = try restoredSession(from: active)
                    session = restored
                    // Save compatible metadata and archive a legacy completed game.
                    try persist(restored)
                    if restored.phase == .finished { includeInHistory(restored) }
                } catch {
                    modelContext.rollback()
                    report(error, prefix: "Não foi possível retomar a partida guardada")
                }
            }
            if damagedRecordCount > 0 {
                let warning = "Não foi possível abrir \(damagedRecordCount) partida(s) do histórico. Os dados guardados foram preservados."
                errorMessage = [errorMessage, warning].compactMap { $0 }.joined(separator: "\n")
            }
        } catch {
            report(error, prefix: "Não foi possível carregar as partidas guardadas")
        }
    }

    private func restoredSession(from record: StoredGameSession) throws -> GameSession {
        var restored = try JSONDecoder().decode(GameSession.self, from: record.payload)
        try GameEngine.restoreMetadata(in: &restored, fallbackDate: record.updatedAt)
        try GameEngine.validate(restored)
        return restored
    }

    private func persist(_ session: GameSession) throws {
        try upsertActive(session)
        if session.phase == .finished {
            try upsertHistory(session)
        }
        try modelContext.save()
    }

    private func upsertActive(_ session: GameSession) throws {
        try upsert(session, slot: "active")
    }

    private func upsertHistory(_ session: GameSession) throws {
        try upsert(session, slot: "history-\(session.id.uuidString)")
    }

    private func upsert(_ session: GameSession, slot: String) throws {
        let payload = try JSONEncoder().encode(session)
        if let record = try record(in: slot) {
            record.payload = payload
            record.updatedAt = .now
        } else {
            modelContext.insert(StoredGameSession(slot: slot, payload: payload))
        }
    }

    private func record(in slot: String) throws -> StoredGameSession? {
        var descriptor = FetchDescriptor<StoredGameSession>(
            predicate: #Predicate { $0.slot == slot }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func preserveUnreadableActiveRecord() throws {
        guard let active = try record(in: "active") else { return }
        modelContext.insert(StoredGameSession(
            slot: "recovery-\(UUID().uuidString)",
            payload: active.payload,
            updatedAt: active.updatedAt
        ))
    }

    private func includeInHistory(_ session: GameSession) {
        history.removeAll { $0.id == session.id }
        history.append(session)
        history.sort { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private func report(_ error: Error, prefix: String? = nil) {
        if let prefix {
            errorMessage = "\(prefix). \(error.localizedDescription)"
        } else {
            errorMessage = error.localizedDescription
        }
    }
}
