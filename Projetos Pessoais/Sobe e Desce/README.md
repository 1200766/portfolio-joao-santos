# Sobe e Desce

Aplicação iOS nativa para gerir partidas de **Sobe e Desce** num único iPhone passado entre os jogadores. A versão **1.1** acrescentou Copas às cegas, participação obrigatória, preenchimento automático de zeros, histórico de partidas e um ícone próprio. A atualização **1.1.1** permite voltar ao início e retomar a partida, ou interrompê-la escolhendo se fica no histórico.

A aplicação funciona totalmente offline. Não cria contas, não movimenta dinheiro, não integra pagamentos e não envia dados para serviços externos.

## Requisitos

- macOS com Xcode 16 ou mais recente
- iOS 17 ou mais recente
- Um iPhone ou simulador de iPhone

## Abrir e executar

1. Abra `SobeEDesce.xcodeproj` no Xcode.
2. Escolha o scheme **SobeEDesce**.
3. Escolha um simulador de iPhone.
4. Prima **Run** (`⌘R`).

O simulador não precisa de uma conta Apple nem de configuração de assinatura.
Para instalar num iPhone real, abra **Signing & Capabilities**, selecione a sua
própria equipa Apple e, se necessário, substitua `pt.local.SobeEDesce` por um
Bundle Identifier único sob o seu controlo. A exportação pública não contém
qualquer identificador de equipa Apple.

## Fluxo implementado

- Configuração de exatamente 4 ou 5 jogadores.
- Nome opcional da partida; quando fica vazio, é atribuído um nome com a data e a hora.
- Modo sem dinheiro ou valor comum de 0,01 € a 2,00 € por ponto.
- Introdução individual dos nomes, mantendo a ordem física da mesa.
- Escolha de quem recebeu o rei de copas e rotação circular a partir dessa pessoa.
- Escolha de paus, copas, espadas, ouros ou **Copas às cegas** em cada ronda.
- Paus obriga todos a jogar. Nos outros trunfos, quem escolhe o trunfo e quem ficou de fora nas duas rondas anteriores têm participação obrigatória.
- Os controlos de participação obrigatória ficam bloqueados e explicam o motivo. Participar repõe a contagem de ausências consecutivas a zero.
- Distribuição sequencial com saldo visível, valores limitados ao saldo e atribuição automática ao último participante.
- Total de 5 pontos em rondas normais, 10 em copas (múltiplos de 2) e 20 em Copas às cegas (múltiplos de 4).
- Copas às cegas é escolhido antes de ver as cartas: resultados possíveis 0, 4, 8, 12, 16 e 20.
- Resultado zero sobe o total da ronda: 5, 10 ou 20 pontos. Um resultado positivo é subtraído; ausentes não mudam de pontuação.
- Quando o saldo se esgota, os restantes participantes recebem zero automaticamente. O passo **Verificar pontos** exige sempre confirmação antes de alterar a classificação.
- Classificação por menos pontos, depois menos escolhas de trunfo e, por fim, ordem original da mesa.
- Resumo final com dívidas individuais e total do vencedor quando o modo monetário está ativo.
- Correção do trunfo, participantes ou resultados antes de fechar a ronda.
- Persistência local da partida ativa e do histórico com SwiftData.
- Partidas concluídas são guardadas automaticamente, com nome, data, jogadores, resultados, vencedor e dados do acerto em cêntimos.
- O botão da casa permite regressar à página inicial sem terminar a partida; **Retomar partida** recupera a fase e todo o progresso confirmado. Seleções ainda não confirmadas têm de ser feitas novamente.
- **Interromper partida**, no menu da partida ou na página inicial, permite **Guardar no histórico**, **Sair sem guardar** ou cancelar. Nas apresentações em janela flutuante do iOS, tocar fora da janela cancela sem escolher nenhuma ação; nas restantes, existe o botão **Cancelar**. Guardar ou sair sem guardar encerra a partida ativa e regressa ao início; guardar conserva os resultados confirmados como partida interrompida, sem vencedor nem dívidas finais. Uma partida encerrada não pode ser retomada.
- Ao começar uma nova partida com outra em curso, é possível escolher se a anterior fica no histórico. A escolha só é aplicada ao concluir a configuração: cancelá-la ou indicar dados inválidos conserva a partida atual. O histórico anterior nunca é apagado por estas ações.
- As partidas concluídas mantêm a gravação automática e podem ser consultadas a partir de **Ver último resultado** ou do histórico.
- Histórico pesquisável por nome da partida ou participante, acessível no início e durante o jogo.
- Logótipo na página inicial e ícone integrado no catálogo de recursos do iPhone. Fonte e prompt em [Assets/README.md](Assets/README.md).

## Compatibilidade com partidas guardadas

O modelo SwiftData mantém o esquema anterior. A partida ativa e cada partida do histórico ocupam registos distintos; começar uma nova partida não apaga o histórico.

Snapshots antigos recebem nome e data a partir da data de gravação disponível. Rondas antigas já fechadas conservam os seus resultados e regras. Uma ronda antiga ainda em distribuição cuja seleção não cumpra as novas obrigações volta ao passo de participantes, sem alterar as pontuações já acumuladas.

A ausência na última ronda antiga é recuperada quando conhecida. A versão anterior não guardava o histórico das ausências anteriores a essa ronda; a partir da atualização, a contagem fica guardada com a partida.

A confirmação da ronda e a gravação da partida concluída no histórico são feitas na mesma transação. Guardar uma interrupção e remover a partida ativa também é atómico, tal como substituir a partida ao terminar uma nova configuração. Uma falha de gravação mantém a sessão em memória e apresenta um erro. Uma partida não é duplicada ao reabrir a app. Registos ilegíveis são preservados no percurso normal de recuperação; uma escolha explícita de descartar elimina apenas o registo ativo. Um registo danificado não bloqueia a leitura dos restantes.

## Testes

O pacote `GameCore` contém o motor Foundation usado diretamente pela app e testes Swift Testing. A partir da raiz do projeto:

```sh
cd GameCore
swift test
```

O target **SobeEDesceTests** inclui os testes do motor e testes integrados de persistência em memória e em disco. **SobeEDesceUITests** percorre a configuração, participação, verificação, vitória e histórico pela interface. Para compilar e testar num simulador disponível:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

xcodebuild \
  -project SobeEDesce.xcodeproj \
  -scheme SobeEDesce \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild \
  -project SobeEDesce.xcodeproj \
  -scheme SobeEDesce \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO test
```

Se esse modelo não existir, consulte os simuladores disponíveis com `xcrun simctl list devices available` e substitua o nome.

Os testes cobrem limites da configuração, ordem física, distribuição e saldo, os cinco trunfos, participantes obrigatórios, ausências consecutivas, zeros automáticos sem fechar a ronda, correções, rotação, classificação, desempates, vitória, snapshots atuais e legados, euros e acertos. A persistência é testada com fecho e reabertura de um armazenamento em disco, escolha de guardar ou descartar, preservação do histórico ao substituir a ativa, idempotência e registos danificados. Os testes da interface usam um armazenamento isolado em memória e incluem o regresso ao início, retoma, cancelamento, interrupção e substituição de partidas.

Validação da versão 1.1.1 em 2026-09-08: 38 testes do motor, 14 de
persistência e 5 percursos da interface aprovados nas respetivas execuções
finais (**57 testes; 67 casos parametrizados**), além das compilações de
simulador e de iPhone. A versão de iOS usada no simulador foi a 26.5; o alvo
mínimo da aplicação continua a ser iOS 17. A compilação 3 não foi instalada
num iPhone real durante essa validação. A verificação reproduzível da
exportação pública está resumida em [VALIDACAO.md](VALIDACAO.md), sem depender
dos artefactos locais da área de desenvolvimento.

## Estrutura

- `SobeEDesce/App`: arranque e encaminhamento entre as fases da partida.
- `SobeEDesce/Services`: snapshot SwiftData e coordenação persistente dos comandos do motor.
- `SobeEDesce/Views`: início, configuração, ronda, classificação e resultado final.
- `SobeEDesce/Support`: estilo visual partilhado.
- `SobeEDesce/Assets.xcassets`: logótipo e ícone da aplicação.
- `SobeEDesceTests`: testes integrados de SwiftData e histórico.
- `SobeEDesceUITests`: testes completos da interface.
- `GameCore/Sources`: modelos e regras puras, sem SwiftUI nem SwiftData.
- `GameCore/Tests`: testes automatizados do mesmo motor ligado à app.

## Hipóteses de regras ainda por confirmar

As seguintes decisões estão isoladas no motor e podem ser alteradas sem redesenhar a interface:

1. **Ultrapassar zero:** chegar a zero ou passar abaixo conta como vitória; a pontuação final é limitada a zero.
2. **Vitória simultânea:** se várias pessoas chegarem a zero na mesma ronda, vence a primeira na ordem física original da mesa. O vencedor declarado aparece sempre em primeiro no resultado final.

As regras de participação deixaram de ser hipóteses: quem escolhe o trunfo participa sempre e cada jogador só pode ficar de fora duas rondas consecutivas.

## Estado do projeto

Esta pasta é a exportação pública curada da versão 1.1.1, integrada em
`Projetos Pessoais/Sobe e Desce/` no repositório único de portefólio. Não tem
um repositório `.git` próprio: o histórico é gerido exclusivamente pela raiz
do portefólio. O arquivo original, o histórico de desenvolvimento e os
artefactos de compilação permanecem fora desta exportação.

O ícone e os testes integrados de SwiftData estão incluídos na versão 1.1. Mantém-se como melhoria futura um ecrã de recuperação para a falha rara de inicialização do armazenamento. Os snapshots restaurados são validados semanticamente antes de a app os aceitar.

O projeto é individual. Consulte [AUTHORS.md](AUTHORS.md) para a autoria e
[RIGHTS.md](RIGHTS.md) para as condições de utilização.
