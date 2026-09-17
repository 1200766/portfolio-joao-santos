# Instruções do projeto

- Esta é uma aplicação iOS nativa em SwiftUI, com iOS 17 como versão mínima.
- Toda a interface apresentada ao utilizador deve usar português de Portugal.
- As regras do jogo pertencem ao pacote Foundation `GameCore`; as vistas não devem duplicar cálculos de pontuação, rotação, classificação ou dinheiro.
- A matriz `GameSession.players` conserva sempre a ordem física original da mesa. Qualquer classificação é apenas uma projeção ordenada.
- Valores monetários são guardados em cêntimos inteiros; não usar `Double` para dinheiro.
- A app é local e offline. Não acrescentar contas, telemetria, pagamentos ou serviços externos sem aprovação explícita.
- Alterar uma regra exige atualizar os testes de `GameCore` e a secção de hipóteses do `README.md` quando aplicável.
- Não editar nem versionar `.build`, `DerivedData` ou `xcuserdata`.
