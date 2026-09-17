# Finanças Pessoais

Aplicação iOS nativa para registar movimentos, gerir recorrências, acompanhar um orçamento semanal e simular o saldo futuro. Foi desenvolvida com SwiftUI e SwiftData e funciona localmente, sem contas, servidor, ligações bancárias ou serviços externos.

Esta pasta é uma **cópia pública curada**. Não contém movimentos, saldos, hábitos, horários ou configurações pessoais da instalação original.

## Funcionalidades

- registo de ganhos e despesas;
- categorias e regras de categorização editáveis;
- movimentos recorrentes semanais, quinzenais, de três em três semanas e mensais;
- saldo atual e previsão até ao fim do mês;
- orçamento semanal com limites gerais e por categoria;
- simulação de cenários sem alterar os movimentos reais;
- lembretes locais opcionais.

Numa instalação nova, a aplicação cria apenas exemplos neutros: Alimentação, Transportes, Habitação, Saúde, Lazer e Outros. As palavras de categorização, os limites sugeridos e o lembrete de domingo às 18:00 são demonstrativos e podem ser alterados na própria aplicação.

## Requisitos

- macOS;
- Xcode 16 ou posterior;
- iOS 17 ou posterior.

## Instalação e execução

1. Abra `FinancasPessoais.xcodeproj` no Xcode.
2. Selecione o scheme `FinancasPessoais`.
3. Escolha um simulador de iPhone.
4. Execute com **Run** (`⌘R`).

Para instalar num dispositivo físico, selecione a sua própria equipa em **Signing & Capabilities**. O identificador `com.example.FinancasPessoais` é apenas demonstrativo e pode ter de ser substituído por um identificador único sob o seu controlo. Nenhuma equipa Apple está configurada no projeto público.

## Testes

Execute a bateria de verificações a partir desta pasta:

```sh
bash tests/run-finance-checks.sh
```

O núcleo independente também pode ser testado diretamente:

```sh
swift test --package-path FinanceCore
```

Para compilar para um simulador genérico sem assinatura:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project FinancasPessoais.xcodeproj \
  -scheme FinancasPessoais \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/FinancasPessoaisDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Os resultados da preparação desta cópia estão registados em [VALIDACAO.md](VALIDACAO.md).

## Dados e privacidade

Os dados introduzidos pelo utilizador são guardados por SwiftData no contentor local da aplicação. Esta versão não transmite dados, não sincroniza com a nuvem e não contém uma base de dados preparada. Desinstalar a aplicação pode eliminar os dados locais; não existe nesta versão um mecanismo de exportação ou restauro.

Os dados e valores presentes no código e nos testes são exclusivamente sintéticos. Não devem ser interpretados como dados financeiros reais nem como aconselhamento financeiro.

## Limitações

- sem integração bancária, autenticação ou sincronização entre dispositivos;
- sem cópia de segurança ou importação/exportação;
- moeda e apresentação orientadas para EUR e `pt_PT`;
- a leitura da validade de uma instalação assinada é informativa e pode não estar disponível;
- os lembretes dependem das permissões e das políticas de notificações do iOS.

## Autoria e direitos

O projeto e o respetivo ícone foram criados por João Pedro Ribeiro dos Santos. Consulte [AUTHORS.md](AUTHORS.md) e [RIGHTS.md](RIGHTS.md). Não foi concedida uma licença aberta.
