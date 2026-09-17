import XCTest

@MainActor
final class GameFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UI_TESTING"] = "1"
        app.launchArguments = ["-AppleLanguages", "(pt-PT)", "-AppleLocale", "pt_PT"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    func testBlindHeartsAutomaticZerosAndNamedHistoryWithDebts() {
        XCTAssertTrue(app.buttons["Iniciar jogo"].waitForExistence(timeout: 10))
        screenshot("Início com o novo logótipo")
        tap(app.buttons["Iniciar jogo"])
        configureGame(name: "Copas de setembro", players: ["Ana", "Bruno", "Carla", "Diogo"], money: true)

        chooseTrump("blindHearts")
        XCTAssertTrue(app.staticTexts["Trunfo: Copas às cegas"].exists)
        assertLockedParticipant(0)
        screenshot("Copas às cegas e participação obrigatória do trunfo")
        tap(app.buttons["Confirmar participantes"])

        tap(app.buttons["result-20"])
        tap(app.buttons["Confirmar resultado"])
        assertReviewBeforeClosing()
        XCTAssertGreaterThanOrEqual(app.staticTexts.matching(identifier: "0").count, 3,
                                    "Os outros três resultados devem ser preenchidos com zero.")
        screenshot("Verificação obrigatória com os zeros automáticos")
        tap(app.buttons["Fechar ronda"])

        XCTAssertTrue(app.staticTexts["Vitória!"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ana chegou primeiro a zero."].exists)
        XCTAssertGreaterThanOrEqual(app.staticTexts.matching(identifier: "40 pontos").count, 3,
                                    "Cada adversário termina com 40 pontos.")
        assertTwelveEuroSettlement()
        screenshot("Vitória e acerto de doze euros")

        tap(app.buttons["Histórico"])
        openSavedGame("Copas de setembro")
        assertSavedGameDetails()
        screenshot("Partida guardada com participantes, resultados e dívidas")
        tap(app.buttons["Concluído"])

        tap(app.buttons["Começar nova partida"])
        let confirmation = app.sheets.buttons["Começar nova partida"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.tap()
        configureGame(name: "Segunda partida", players: ["Ana", "Bruno", "Carla", "Diogo"], money: false)
        XCTAssertTrue(app.staticTexts["Segunda partida"].exists)
        tap(app.buttons["Histórico"])
        openSavedGame("Copas de setembro")
        assertSavedGameDetails()
        screenshot("Histórico preservado depois de começar outra partida")
    }

    func testTwoConsecutiveAbsencesForceParticipationInThirdRound() {
        tap(app.buttons["Iniciar jogo"])
        configureGame(name: "Duas ausências", players: ["Ana", "Bruno", "Carla", "Diogo", "Eva"], money: false)

        for round in 1...2 {
            chooseTrump("spades")
            assertLockedParticipant(round - 1)
            let absentPlayer = app.switches["participant-4"]
            reveal(absentPlayer)
            XCTAssertTrue(absentPlayer.isEnabled, "Eva ainda pode ficar de fora nesta ronda.")
            XCTAssertEqual(absentPlayer.value as? String, "1")
            absentPlayer.tap()
            XCTAssertEqual(absentPlayer.value as? String, "0")
            if round == 2 {
                screenshot("Segunda ausência consecutiva permitida")
            }
            tap(app.buttons["Confirmar participantes"])
            tap(app.buttons["result-5"])
            tap(app.buttons["Confirmar resultado"])
            assertReviewBeforeClosing()
            tap(app.buttons["Fechar ronda"])
            XCTAssertTrue(app.staticTexts["Fim da ronda \(round)"].waitForExistence(timeout: 5))
            tap(app.buttons["Avançar para a ronda \(round + 1)"])
        }

        chooseTrump("spades")
        assertLockedParticipant(2)
        assertLockedParticipant(4)
        XCTAssertTrue(app.staticTexts["Ficou de fora nas duas rondas anteriores. Tem de ir a jogo."].exists)
        screenshot("Terceira ronda obriga a jogar após duas ausências")
        tap(app.buttons["Confirmar participantes"])
        tap(app.buttons["result-5"])
        tap(app.buttons["Confirmar resultado"])
        assertReviewBeforeClosing()
        XCTAssertTrue(app.staticTexts["Eva"].exists,
                      "A participante obrigatória tem de receber um resultado nesta ronda.")
        tap(app.buttons["Fechar ronda"])
        XCTAssertTrue(app.staticTexts["Fim da ronda 3"].waitForExistence(timeout: 5))
        screenshot("Classificação após a terceira ronda")
    }

    func testHomeResumesProgressAndInterruptionCanSaveOrDiscard() {
        tap(app.buttons["Iniciar jogo"])
        configureGame(name: "Partida para guardar", players: ["Ana", "Bruno", "Carla", "Diogo"], money: false)
        chooseTrump("spades")
        tap(app.buttons["Confirmar participantes"])
        tap(app.buttons["result-5"])
        tap(app.buttons["Confirmar resultado"])
        assertReviewBeforeClosing()
        tap(app.buttons["Fechar ronda"])
        XCTAssertTrue(app.staticTexts["Fim da ronda 1"].waitForExistence(timeout: 5))

        tap(app.buttons["go-home"])
        XCTAssertTrue(app.buttons["Retomar partida"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Partida para guardar"].exists)
        screenshot("Página inicial com a partida disponível para retomar")
        tap(app.buttons["Retomar partida"])
        XCTAssertTrue(app.staticTexts["Fim da ronda 1"].waitForExistence(timeout: 5),
                      "Regressar à página inicial não pode reiniciar a partida.")
        XCTAssertTrue(app.buttons["Avançar para a ronda 2"].exists)

        tap(app.buttons["Mais opções"])
        tap(app.buttons["Interromper partida"])
        screenshot("Escolha entre guardar e sair sem guardar")
        cancelInterruptionDialog()
        XCTAssertTrue(app.staticTexts["Fim da ronda 1"].waitForExistence(timeout: 5),
                      "Cancelar a interrupção deve manter a ronda confirmada.")

        tap(app.buttons["go-home"])
        tap(app.buttons["Interromper partida"])
        tapDialogAction("Guardar no histórico")
        assertHomeWithoutActiveGame()
        tap(app.buttons["Histórico de partidas"])
        openSavedGame("Partida para guardar")
        let detail = app.scrollViews["history-detail"]
        XCTAssertTrue(detail.staticTexts["Partida interrompida na ronda 1."].exists)
        XCTAssertTrue(detail.staticTexts["15 pontos"].exists)
        XCTAssertEqual(detail.staticTexts.matching(identifier: "25 pontos").count, 3,
                       "O histórico deve conservar os resultados da última ronda confirmada.")
        screenshot("Interrupção guardada com a pontuação confirmada")
        tap(app.buttons["Concluído"])

        tap(app.buttons["Iniciar jogo"])
        configureGame(name: "Partida para descartar", players: ["Ana", "Bruno", "Carla", "Diogo"], money: false)
        tap(app.buttons["Mais opções"])
        tap(app.buttons["Interromper partida"])
        tapDialogAction("Sair sem guardar")
        assertHomeWithoutActiveGame()
        tap(app.buttons["Histórico de partidas"])
        XCTAssertTrue(app.buttons["history-entry-Partida para guardar"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["history-entry-Partida para descartar"].exists,
                       "Sair sem guardar não deve criar uma entrada no histórico.")
        openSavedGame("Partida para guardar")
        XCTAssertTrue(app.scrollViews["history-detail"].staticTexts["15 pontos"].exists,
                      "Descartar a partida ativa não pode apagar o histórico anterior.")
        screenshot("Histórico anterior preservado depois de descartar outra partida")
    }

    func testCancellingReplacementSetupKeepsTheActiveGame() {
        tap(app.buttons["Iniciar jogo"])
        configureGame(name: "Partida original", players: ["Ana", "Bruno", "Carla", "Diogo"], money: false)
        chooseTrump("spades")

        tap(app.buttons["Mais opções"])
        tap(app.buttons["Começar nova partida"])
        tapDialogAction("Guardar e continuar")
        cancelNewGameSetup()
        XCTAssertTrue(app.staticTexts["Quem vai a jogo?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Trunfo: Espadas"].exists,
                      "Cancelar a configuração deve conservar também a ronda em curso.")

        tap(app.buttons["go-home"])
        tap(app.buttons["Começar nova partida"])
        tapDialogAction("Não guardar e continuar")
        cancelNewGameSetup()
        XCTAssertTrue(app.buttons["Retomar partida"].waitForExistence(timeout: 5))
        tap(app.buttons["Retomar partida"])
        XCTAssertTrue(app.staticTexts["Quem vai a jogo?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Partida original"].exists)
        XCTAssertTrue(app.staticTexts["Trunfo: Espadas"].exists,
                      "A escolha de não guardar só deve ter efeito ao concluir a nova configuração.")
        screenshot("Partida original intacta depois de cancelar as duas opções de substituição")

        tap(app.buttons["go-home"])
        tap(app.buttons["Interromper partida"])
        tapDialogAction("Sair sem guardar")
        assertHomeWithoutActiveGame()
        tap(app.buttons["Histórico de partidas"])
        XCTAssertTrue(app.staticTexts["Ainda não há partidas guardadas"].waitForExistence(timeout: 5),
                      "Cancelar a configuração também não pode arquivar a partida antes da decisão final.")
    }

    func testCompletingReplacementAppliesDiscardAndSaveChoices() {
        let players = ["Ana", "Bruno", "Carla", "Diogo"]
        tap(app.buttons["Iniciar jogo"])
        configureGame(name: "Partida A", players: players, money: false)

        tap(app.buttons["Mais opções"])
        tap(app.buttons["Começar nova partida"])
        tapDialogAction("Não guardar e continuar")
        configureGame(name: "Partida B", players: players, money: false)
        XCTAssertTrue(app.staticTexts["Partida B"].exists)
        XCTAssertTrue(app.buttons["Confirmar trunfo"].exists,
                      "Concluir a substituição deve abrir a nova partida ativa.")
        tap(app.buttons["Histórico"])
        XCTAssertTrue(app.staticTexts["Ainda não há partidas guardadas"].waitForExistence(timeout: 5),
                      "Escolher não guardar deve descartar a primeira partida quando a segunda começa.")
        tap(app.buttons["Concluído"])

        tap(app.buttons["go-home"])
        XCTAssertTrue(app.staticTexts["Partida B"].exists)
        tap(app.buttons["Começar nova partida"])
        tapDialogAction("Guardar e continuar")
        configureGame(name: "Partida C", players: players, money: false)
        XCTAssertTrue(app.staticTexts["Partida C"].exists)
        XCTAssertTrue(app.buttons["Confirmar trunfo"].exists)
        tap(app.buttons["Histórico"])
        XCTAssertTrue(app.buttons["history-entry-Partida B"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["history-entry-Partida A"].exists,
                       "A partida descartada não pode reaparecer numa substituição posterior.")
        XCTAssertFalse(app.buttons["history-entry-Partida C"].exists,
                       "A nova partida em curso ainda não deve estar no histórico.")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history-entry-")).count, 1)
        openSavedGame("Partida B")
        let detail = app.scrollViews["history-detail"]
        XCTAssertTrue(detail.staticTexts["Partida interrompida na ronda 1."].exists)
        XCTAssertEqual(detail.staticTexts.matching(identifier: "20 pontos").count, 4)
        screenshot("Substituição guarda apenas a partida escolhida")
        tap(app.buttons["Concluído"])
        XCTAssertTrue(app.staticTexts["Partida C"].waitForExistence(timeout: 5),
                      "Consultar a partida substituída não pode alterar a nova partida ativa.")
    }

    private func tapDialogAction(_ title: String) {
        let action = app.sheets.buttons[title]
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        tap(action)
    }

    private func cancelInterruptionDialog() {
        let dialog = app.sheets["Interromper a partida?"]
        XCTAssertTrue(dialog.waitForExistence(timeout: 5))
        let cancel = dialog.buttons["Cancelar"]
        if cancel.exists {
            tap(cancel)
        } else {
            // Native popovers omit the cancel-role button; tapping outside
            // dismisses them without selecting either action.
            XCTAssertGreaterThan(dialog.frame.minX, 0)
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: dialog.frame.minX / 2, dy: dialog.frame.midY))
                .tap()
        }
        let dismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: dialog
        )
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
    }

    private func assertHomeWithoutActiveGame() {
        XCTAssertTrue(app.buttons["Iniciar jogo"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Retomar partida"].exists)
        XCTAssertFalse(app.buttons["Interromper partida"].exists)
    }

    private func cancelNewGameSetup() {
        let navigation = app.navigationBars["Nova partida"]
        XCTAssertTrue(navigation.waitForExistence(timeout: 5))
        let gameName = app.textFields["game-name"]
        tap(gameName)
        gameName.typeText("Configuração cancelada\n")
        tap(navigation.buttons["Cancelar"])
        let dismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: navigation
        )
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 10), .completed)
    }

    private func configureGame(name: String, players: [String], money: Bool) {
        let gameName = app.textFields["game-name"]
        XCTAssertTrue(gameName.waitForExistence(timeout: 5))
        gameName.tap()
        gameName.typeText(name + "\n")
        if players.count == 5 {
            tap(app.segmentedControls.buttons["5 jogadores"])
        }
        if money {
            // A Form exposes both the whole row and the native switch.
            // Tap the control: the middle of the row is just empty space.
            let moneySwitch = app.switches["Jogar a dinheiro?"].switches.firstMatch
            tap(moneySwitch)
            XCTAssertEqual(moneySwitch.value as? String, "1")
            let amount = app.textFields["0,01 a 2,00"]
            XCTAssertTrue(amount.waitForExistence(timeout: 3))
            XCTAssertEqual(amount.value as? String, "0,10")
        }
        tap(app.buttons["Continuar"])

        for (index, name) in players.enumerated() {
            XCTAssertTrue(app.navigationBars["Jogador \(index + 1) de \(players.count)"].waitForExistence(timeout: 5))
            let nameField = app.textFields["Nome"]
            XCTAssertTrue(nameField.waitForExistence(timeout: 3))
            nameField.tap()
            nameField.typeText(name + "\n")
        }

        XCTAssertTrue(app.navigationBars["Rei de copas"].waitForExistence(timeout: 5))
        tap(app.buttons.containing(.staticText, identifier: players[0]).firstMatch)
        tap(app.buttons["Começar a ronda 1"])
        let setupDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.navigationBars["Rei de copas"]
        )
        XCTAssertEqual(XCTWaiter.wait(for: [setupDismissed], timeout: 20), .completed,
                       "A configuração tem de fechar antes de tocar na ronda que está por trás.")
        XCTAssertTrue(app.navigationBars["Ronda 1"].waitForExistence(timeout: 5))
    }

    private func chooseTrump(_ suit: String) {
        tap(app.buttons["trump-\(suit)"])
        XCTAssertEqual(app.buttons["trump-\(suit)"].value as? String, "Selecionado")
        tap(app.buttons["Confirmar trunfo"])
        XCTAssertTrue(app.staticTexts["Quem vai a jogo?"].waitForExistence(timeout: 5))
    }

    private func assertLockedParticipant(_ position: Int) {
        let participant = app.switches["participant-\(position)"]
        reveal(participant)
        XCTAssertFalse(participant.isEnabled)
        XCTAssertEqual(participant.value as? String, "1")
    }

    private func assertReviewBeforeClosing() {
        XCTAssertTrue(app.staticTexts["Verificar pontos"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Fechar ronda"].exists)
        XCTAssertFalse(app.staticTexts["Vitória!"].exists,
                       "A atribuição automática nunca deve fechar a ronda por si só.")
        XCTAssertFalse(app.buttons["Confirmar resultado"].exists,
                       "Com o saldo esgotado, não deve pedir zeros manualmente.")
    }

    private func assertTwelveEuroSettlement(in scope: XCUIElement? = nil) {
        let scope = scope ?? app!
        let total = scope.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "12,00", "€")).firstMatch
        reveal(total)
        XCTAssertTrue(total.exists)
        XCTAssertEqual(scope.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "deve", "4,00")).count, 3)
        XCTAssertTrue(scope.staticTexts["Ana recebe"].exists)
    }

    private func openSavedGame(_ name: String) {
        let savedName = app.buttons["history-entry-\(name)"]
        XCTAssertTrue(savedName.waitForExistence(timeout: 5))
        tap(savedName)
        XCTAssertTrue(app.navigationBars["Partida guardada"].waitForExistence(timeout: 5))
    }

    private func assertSavedGameDetails() {
        let detail = app.scrollViews["history-detail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertTrue(detail.staticTexts["Copas de setembro"].exists)
        XCTAssertTrue(detail.staticTexts["Venceu Ana"].exists)
        XCTAssertTrue(detail.staticTexts["Terminou na ronda 1."].exists)
        for name in ["Ana", "Bruno", "Carla", "Diogo"] {
            XCTAssertTrue(detail.staticTexts[name].firstMatch.exists)
        }
        XCTAssertEqual(detail.staticTexts.matching(identifier: "40 pontos").count, 3)
        XCTAssertTrue(detail.staticTexts["0 pontos"].exists)
        let month = DateFormatter()
        month.locale = Locale(identifier: "pt_PT")
        month.dateFormat = "MMMM"
        XCTAssertTrue(detail.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", month.string(from: Date()))).firstMatch.exists)
        assertTwelveEuroSettlement(in: detail)
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        reveal(element, file: file, line: line)
        XCTAssertTrue(element.isEnabled, file: file, line: line)
        element.press(forDuration: 0.15)
    }

    private func reveal(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        _ = element.waitForExistence(timeout: 3)
        if element.isHittable { return }
        // Form is a collection view. Ignore the keyboard's suggestion scroll view.
        let surface: XCUIElement = app.collectionViews.firstMatch.exists
            ? app.collectionViews.firstMatch
            : app.scrollViews.allElementsBoundByIndex.first(where: { $0.frame.height > 100 }) ?? app
        for _ in 0..<4 {
            surface.swipeUp()
            if element.isHittable { return }
        }
        for _ in 0..<4 {
            surface.swipeDown()
            if element.isHittable { return }
        }
        XCTFail("Elemento não acessível no ecrã: \(element)", file: file, line: line)
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
