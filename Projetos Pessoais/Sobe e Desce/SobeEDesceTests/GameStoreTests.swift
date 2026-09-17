import Foundation
import SobeEDesceCore
import SwiftData
import Testing
@testable import SobeEDesce

@MainActor
@Suite("Histórico e persistência das partidas")
struct GameStoreTests {
    private let names = ["Ana", "Bruno", "Carla", "Duarte"]

    @Test("A vitória guarda o resultado e as dívidas sem duplicar o histórico")
    func completedGameIsArchivedExactlyOnce() throws {
        let container = try memoryContainer()
        let store = GameStore(modelContext: ModelContext(container))
        #expect(store.startGame(name: "Mesa de sexta", names: names, valuePerPointCents: 5, firstChooserIndex: 0))
        let originalID = try #require(store.session?.id)
        try finishGame(store)

        let archived = try #require(store.history.first)
        #expect(archived.id == originalID)
        #expect(archived.name == "Mesa de sexta")
        #expect(archived.phase == .finished)
        #expect(archived.winner?.name == "Ana")
        #expect(archived.players.map(\.name) == names)
        #expect(try GameEngine.settlements(in: archived).map(\.amountCents) == [200, 200, 200])
        #expect(try GameEngine.totalToReceive(in: archived) == 600)

        let reloaded = GameStore(modelContext: ModelContext(container))
        #expect(reloaded.history == [archived])
        #expect(reloaded.session == archived)
        #expect(reloaded.archiveCurrentGame())
        #expect(reloaded.archiveCurrentGame())
        #expect(reloaded.session == nil)
        #expect(reloaded.history == [archived])
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<StoredGameSession>()) == 1)
    }

    @Test("Uma nova partida preserva a concluída e guarda a interrompida")
    func replacingGamePreservesAllGames() throws {
        let container = try memoryContainer()
        let store = GameStore(modelContext: ModelContext(container))
        #expect(store.startGame(name: "Primeira", names: names, valuePerPointCents: nil, firstChooserIndex: 0))
        try finishGame(store)
        let completed = try #require(store.session)

        #expect(store.startGame(name: "Segunda", names: names, valuePerPointCents: nil, firstChooserIndex: 1))
        let interrupted = try #require(store.session)
        #expect(store.startGame(name: "Terceira", names: names, valuePerPointCents: 10, firstChooserIndex: 2))
        #expect(store.history.count == 2)
        #expect(store.history.contains(completed))
        #expect(store.history.contains(interrupted))
        #expect(store.session?.name == "Terceira")
        #expect(try GameEngine.settlements(in: completed).isEmpty)
        #expect(try GameEngine.totalToReceive(in: completed) == 0)

        let reloaded = GameStore(modelContext: ModelContext(container))
        #expect(reloaded.history == store.history)
        #expect(reloaded.session == store.session)
    }

    @Test("Um início inválido não altera a partida ativa nem o histórico", arguments: [GameDisposition.saveToHistory, .discard])
    func invalidNewGameKeepsExistingState(disposition: GameDisposition) throws {
        let container = try memoryContainer()
        let store = GameStore(modelContext: ModelContext(container))
        #expect(store.startGame(name: "Guardar", names: names, valuePerPointCents: nil, firstChooserIndex: 0))
        let active = try #require(store.session)
        #expect(!store.startGame(name: "Inválida", names: [], valuePerPointCents: nil, firstChooserIndex: 0, previousGameDisposition: disposition))
        #expect(store.session == active)
        #expect(store.history.isEmpty)
        #expect(store.errorMessage != nil)
        #expect(GameStore(modelContext: ModelContext(container)).session == active)
    }

    @Test("Guardar uma interrupção preserva o estado sem criar vencedor nem dívidas")
    func interruptedGameCanBeSaved() throws {
        let container = try memoryContainer()
        let store = GameStore(modelContext: ModelContext(container))
        #expect(store.startGame(name: "Interrompida", names: names, valuePerPointCents: 10, firstChooserIndex: 0))
        store.selectTrump(.spades)
        store.selectParticipants(Set(try #require(store.session).players.map(\.id)))
        store.assignResult(2)
        let interrupted = try #require(store.session)
        #expect(interrupted.phase == .assigningResults)

        #expect(store.archiveCurrentGame())
        #expect(store.archiveCurrentGame())
        #expect(store.session == nil)
        #expect(store.history == [interrupted])
        #expect(store.history.first?.winner == nil)
        #expect(throws: GameRuleError.noWinner) {
            try GameEngine.settlements(in: interrupted)
        }
        #expect(throws: GameRuleError.noWinner) {
            try GameEngine.totalToReceive(in: interrupted)
        }
        let reopened = GameStore(modelContext: ModelContext(container))
        #expect(reopened.session == nil)
        #expect(reopened.history == [interrupted])
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<StoredGameSession>()) == 1)
    }

    @Test("Descartar uma interrupção remove apenas a ativa e preserva todo o histórico")
    func discardingActivePreservesHistory() throws {
        let container = try memoryContainer()
        let store = GameStore(modelContext: ModelContext(container))
        #expect(store.startGame(name: "Concluída", names: names, valuePerPointCents: 5, firstChooserIndex: 0))
        try finishGame(store)
        let completed = try #require(store.session)
        #expect(store.startGame(name: "Para descartar", names: names, valuePerPointCents: nil, firstChooserIndex: 1))
        let discardedID = try #require(store.session?.id)

        #expect(store.discardGame())
        #expect(store.discardGame())
        #expect(store.session == nil)
        #expect(store.errorMessage == nil)
        #expect(store.history == [completed])
        #expect(!store.history.contains { $0.id == discardedID })
        let reopened = GameStore(modelContext: ModelContext(container))
        #expect(reopened.session == nil)
        #expect(reopened.history == [completed])
        #expect(try GameEngine.totalToReceive(in: completed) == 600)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<StoredGameSession>()) == 1)
    }

    @Test("Descartar uma partida concluída não apaga a cópia já guardada no histórico")
    func discardingFinishedOnlyClearsActive() throws {
        let container = try memoryContainer()
        let store = GameStore(modelContext: ModelContext(container))
        #expect(store.startGame(names: names, valuePerPointCents: 5, firstChooserIndex: 0))
        try finishGame(store)
        let completed = try #require(store.session)

        #expect(store.discardGame())
        #expect(store.session == nil)
        #expect(store.history == [completed])
        let reopened = GameStore(modelContext: ModelContext(container))
        #expect(reopened.session == nil)
        #expect(reopened.history == [completed])
    }

    @Test("Uma nova partida pode substituir a ativa sem a guardar no histórico")
    func replacementCanDiscard() throws {
        let container = try memoryContainer()
        let store = GameStore(modelContext: ModelContext(container))
        #expect(store.startGame(name: "Guardar antes", names: names, valuePerPointCents: nil, firstChooserIndex: 0))
        let historical = try #require(store.session)
        #expect(store.startGame(name: "Não guardar", names: names, valuePerPointCents: nil, firstChooserIndex: 1))
        let discardedID = try #require(store.session?.id)

        #expect(store.startGame(name: "Nova", names: names, valuePerPointCents: 10, firstChooserIndex: 2, previousGameDisposition: .discard))
        #expect(store.session?.name == "Nova")
        #expect(store.history == [historical])
        #expect(!store.history.contains { $0.id == discardedID })
        let reopened = GameStore(modelContext: ModelContext(container))
        #expect(reopened.session == store.session)
        #expect(reopened.history == [historical])
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<StoredGameSession>()) == 2)
    }

    @Test("Substituir com descartar conserva uma partida já concluída no histórico")
    func replacingFinishedWithDiscardPreservesCompletedHistory() throws {
        let container = try memoryContainer()
        let store = GameStore(modelContext: ModelContext(container))
        #expect(store.startGame(names: names, valuePerPointCents: 5, firstChooserIndex: 0))
        try finishGame(store)
        let completed = try #require(store.session)

        #expect(store.startGame(name: "Nova", names: names, valuePerPointCents: nil, firstChooserIndex: 1, previousGameDisposition: .discard))
        #expect(store.session?.id != completed.id)
        #expect(store.history == [completed])
        let reopened = GameStore(modelContext: ModelContext(container))
        #expect(reopened.session == store.session)
        #expect(reopened.history == [completed])
    }

    @Test("Guardar ou descartar uma interrupção mantém a escolha depois de reabrir o disco", arguments: [GameDisposition.saveToHistory, .discard])
    func interruptionChoicesSurviveDiskReopening(disposition: GameDisposition) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SobeEDesce-InterruptionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("interruption.store")
        let expectedHistory = try interruptGameOnDisk(at: url, disposition: disposition)

        let container = try ModelContainer(for: StoredGameSession.self, configurations: ModelConfiguration(url: url))
        let reopened = GameStore(modelContext: ModelContext(container))
        #expect(reopened.session == nil)
        #expect(reopened.errorMessage == nil)
        #expect(reopened.history == expectedHistory)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<StoredGameSession>()) == expectedHistory.count)
    }

    @Test("A retoma usa o registo ativo mesmo havendo histórico mais recente")
    func activeSlotIsNotConfusedWithHistory() throws {
        let container = try memoryContainer()
        let context = ModelContext(container)
        let active = try makeSession(name: "Ativa", date: Date(timeIntervalSince1970: 100))
        let historical = try makeSession(name: "Histórica", date: Date(timeIntervalSince1970: 200))
        context.insert(StoredGameSession(payload: try JSONEncoder().encode(active), updatedAt: Date(timeIntervalSince1970: 100)))
        context.insert(StoredGameSession(slot: "history-\(historical.id.uuidString)", payload: try JSONEncoder().encode(historical), updatedAt: Date(timeIntervalSince1970: 300)))
        try context.save()

        let store = GameStore(modelContext: ModelContext(container))
        #expect(store.session == active)
        #expect(store.history == [historical])
    }

    @Test("O histórico sobrevive ao fecho e reabertura do armazenamento em disco")
    func diskHistorySurvivesReopening() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SobeEDesce-HistoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("history.store")
        let snapshots = try writeGamesToDisk(at: url)

        let configuration = ModelConfiguration(url: url)
        let container = try ModelContainer(for: StoredGameSession.self, configurations: configuration)
        let reopened = GameStore(modelContext: ModelContext(container))
        #expect(reopened.errorMessage == nil)
        #expect(reopened.history == [snapshots.archived])
        #expect(reopened.session == snapshots.active)
        #expect(reopened.history.first?.createdAt == snapshots.archived.createdAt)
        #expect(try GameEngine.totalToReceive(in: #require(reopened.history.first)) == 600)
    }

    @Test("Uma partida antiga concluída ganha metadados e entra no histórico")
    func legacyFinishedGameIsMigratedWithoutLosingDebts() throws {
        let container = try memoryContainer()
        let source = GameStore(modelContext: ModelContext(try memoryContainer()))
        #expect(source.startGame(names: names, valuePerPointCents: 5, firstChooserIndex: 0))
        try finishGame(source)
        let finished = try #require(source.session)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(finished)) as? [String: Any])
        json.removeValue(forKey: "name")
        json.removeValue(forKey: "createdAt")
        json.removeValue(forKey: "rulesVersion")
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let context = ModelContext(container)
        context.insert(StoredGameSession(payload: try JSONSerialization.data(withJSONObject: json), updatedAt: date))
        try context.save()

        let restored = GameStore(modelContext: ModelContext(container))
        let archived = try #require(restored.history.first)
        #expect(restored.errorMessage == nil)
        #expect(archived.id == finished.id)
        #expect(archived.createdAt == date)
        #expect(!archived.name.isEmpty)
        #expect(archived.players == finished.players)
        #expect(try GameEngine.totalToReceive(in: archived) == 600)
        #expect(GameStore(modelContext: ModelContext(container)).history.count == 1)
    }

    @Test("Um histórico danificado não bloqueia partidas válidas nem é apagado")
    func corruptHistoryIsPreservedAlongsideValidGames() throws {
        let container = try memoryContainer()
        let context = ModelContext(container)
        let valid = try makeSession(name: "Válida", date: .now)
        context.insert(StoredGameSession(slot: "history-\(valid.id.uuidString)", payload: try JSONEncoder().encode(valid)))
        context.insert(StoredGameSession(slot: "history-damaged", payload: Data("invalid".utf8)))
        try context.save()

        let store = GameStore(modelContext: ModelContext(container))
        #expect(store.history == [valid])
        #expect(store.errorMessage != nil)
        #expect(store.archiveCurrentGame())
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<StoredGameSession>()) == 2)
    }

    @Test("Substituir uma partida ilegível preserva o conteúdo para recuperação")
    func corruptActiveIsPreservedBeforeStartingNewGame() throws {
        let container = try memoryContainer()
        let context = ModelContext(container)
        let damagedPayload = Data("unreadable active".utf8)
        context.insert(StoredGameSession(payload: damagedPayload))
        try context.save()

        let store = GameStore(modelContext: ModelContext(container))
        #expect(store.session == nil)
        #expect(store.errorMessage != nil)
        #expect(store.startGame(names: names, valuePerPointCents: nil, firstChooserIndex: 0))
        let records = try ModelContext(container).fetch(FetchDescriptor<StoredGameSession>())
        #expect(records.count == 2)
        #expect(records.contains { $0.slot.hasPrefix("recovery-") && $0.payload == damagedPayload })
    }

    private func memoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: StoredGameSession.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeSession(name: String, date: Date) throws -> GameSession {
        try GameEngine.makeSession(name: name, createdAt: date, names: names, valuePerPointCents: nil, firstChooserIndex: 0)
    }

    private func finishGame(_ store: GameStore) throws {
        for round in 0..<2 {
            if round > 0 { store.startNextRound() }
            store.selectTrump(.hearts)
            let playerIDs = try #require(store.session?.players.map(\.id))
            store.selectParticipants(Set(playerIDs))
            store.assignResult(10)
            while let session = store.session, session.currentParticipantID != nil {
                store.assignResult(0)
                try #require(store.errorMessage == nil)
            }
            try #require(store.session?.roundIsReady == true)
            store.closeRound()
            try #require(store.errorMessage == nil)
        }
        try #require(store.session?.phase == .finished)
    }

    private func writeGamesToDisk(at url: URL) throws -> (archived: GameSession, active: GameSession) {
        let container = try ModelContainer(for: StoredGameSession.self, configurations: ModelConfiguration(url: url))
        let store = GameStore(modelContext: ModelContext(container))
        #expect(store.startGame(name: "No disco", names: names, valuePerPointCents: 5, firstChooserIndex: 0))
        try finishGame(store)
        let archived = try #require(store.session)
        #expect(store.startGame(name: "Retomar depois", names: names, valuePerPointCents: nil, firstChooserIndex: 1))
        return (archived, try #require(store.session))
    }

    private func interruptGameOnDisk(at url: URL, disposition: GameDisposition) throws -> [GameSession] {
        let container = try ModelContainer(for: StoredGameSession.self, configurations: ModelConfiguration(url: url))
        let store = GameStore(modelContext: ModelContext(container))
        #expect(store.startGame(name: "Histórica", names: names, valuePerPointCents: nil, firstChooserIndex: 0))
        #expect(store.archiveCurrentGame())
        #expect(store.startGame(name: "Interrompida no disco", names: names, valuePerPointCents: 5, firstChooserIndex: 1))
        let interrupted = try #require(store.session)
        switch disposition {
        case .saveToHistory:
            #expect(store.archiveCurrentGame())
            #expect(store.history.contains(interrupted))
        case .discard:
            #expect(store.discardGame())
            #expect(!store.history.contains(interrupted))
        }
        return store.history
    }
}
