# Validação da cópia pública

Validação concluída em 17 de setembro de 2026, a partir desta pasta.

## Testes automáticos

Comando:

```sh
bash tests/run-finance-checks.sh
```

Resultado final:

- 38 testes do pacote `FinanceCore` aprovados;
- 72 verificações do orçamento semanal aprovadas;
- 43 verificações de recorrências aprovadas;
- 136 verificações do simulador aprovadas;
- 94 verificações da validade da instalação aprovadas;
- 132 verificações do serviço de lembrete aprovadas.

Os testes utilizam dados sintéticos e diretórios temporários fora da aplicação.

## Build

Foi executado um build para o destino genérico iOS Simulator, com a assinatura desativada e `DerivedData` num diretório temporário:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project FinancasPessoais.xcodeproj \
  -scheme FinancasPessoais \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/financas-public-build \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Resultado: `BUILD SUCCEEDED`.

Esta validação não instala a aplicação num dispositivo físico nem testa a entrega visual de notificações.
