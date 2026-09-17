# Validação

## Exportação pública

Esta pasta foi preparada a partir da versão 1.1.1 da aplicação. A exportação
inclui o código-fonte, os testes e os recursos necessários, mas exclui o
repositório Git da área de desenvolvimento, resultados de testes, compilações,
dados derivados do Xcode e configuração pessoal de assinatura Apple.

## Verificação da exportação

Em 17 de setembro de 2026, na própria pasta pública:

- os 38 testes do motor `GameCore` foram executados com sucesso;
- a aplicação compilou para um simulador iOS genérico com a assinatura de
  código desativada;
- foram revistos os links Markdown, o inventário de ficheiros e a ausência de
  credenciais, dados pessoais e artefactos de desenvolvimento.

Comandos principais:

```sh
cd GameCore
swift test

cd ..
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild \
  -project SobeEDesce.xcodeproj \
  -scheme SobeEDesce \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

Os ficheiros gerados por estes comandos pertencem a `.build/` e não fazem
parte do repositório.

## Validação funcional anterior

Na validação final da versão 1.1.1, em 8 de setembro de 2026, foram aprovados
38 testes do motor, 14 testes de persistência e 5 percursos da interface. Estes
resultados registam o estado validado da aplicação; os respetivos artefactos
locais não integram a exportação pública.
