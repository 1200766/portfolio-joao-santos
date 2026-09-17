# Verificação da seleção histórica

**Data:** 17 de setembro de 2026.  
**Objetivo:** verificar a curadoria do arquivo, sem reconstruir a entrega final.

## Resultado

O conteúdo está preparado como uma seleção de código académico histórico,
acompanhada pelo relatório original e por documentação das diferenças. Não se
apresenta como uma demonstração integral executável da versão final.

| Verificação | Resultado |
|---|---|
| Integridade do relatório | SHA-256 idêntico ao original; conteúdo e metadados preservados |
| Backend — TypeScript sem emissão | Passou |
| Frontend — TypeScript da aplicação sem emissão | Passou |
| Frontend — TypeScript dos ficheiros de testes sem emissão | Passou |
| Frontend — compilador Angular sem emissão | Falha conhecida NG6009, preservada e documentada |
| Nova configuração de backend | Três verificações em memória passaram: rejeição de configuração ausente, rejeição de segredo vazio e aceitação de valores sintéticos explícitos |
| Credenciais históricas | Valores MongoDB/JWT/Syncfusion retirados da cópia preparada |
| Dependências instaladas, caches e compilados | Excluídos |
| Lógica histórica e modelos | Preservados; apenas alterações de curadoria identificadas em PROVENIENCIA.md |

Os resultados TypeScript referem-se à cópia preparada, usando Node.js 22.14.0
e as dependências já existentes no arquivo local. Não foi executada uma
instalação limpa. As ligações temporárias usadas para disponibilizar as
dependências durante a verificação foram removidas da seleção.

## Comandos executados

Dentro de `Backend/`:

```sh
node node_modules/typescript/bin/tsc --noEmit --pretty false -p tsconfig.json
```

Dentro de `FrontEnd/`:

```sh
node node_modules/typescript/bin/tsc --noEmit -p tsconfig.app.json
node node_modules/typescript/bin/tsc --noEmit -p tsconfig.spec.json
node node_modules/@angular/compiler-cli/bundles/src/bin/ngc.js --noEmit -p tsconfig.app.json
```

O último comando identifica `AppComponent` como standalone, apesar de constar
no `bootstrap` de um `NgModule`. O erro já existia na cópia original e não foi
corrigido nesta preparação, de acordo com o âmbito de arquivo histórico.

As verificações da nova configuração executaram apenas a transpilação de
`config.ts` em memória, com um ambiente simulado. Não carregaram o servidor,
as rotas ou o cliente MongoDB e não efetuaram ligações.

## Verificação posterior da designação

A designação confirmada por João foi aplicada aos textos, títulos e mensagens
da cópia preparada. Foi feita uma verificação textual, sem alterações de lógica
e sem repetir o build ou os testes da aplicação. O relatório e os originais
permanecem intactos.

## Limites da verificação

Passar a verificação TypeScript dos testes não significa que os testes tenham
sido executados. Não foram executados Karma, testes de integração, servidor,
base de dados, build de produção, instalação limpa ou auditoria atual de
dependências. Não houve ensaio clínico ou teste com dados reais.

Os limites de autenticação/autorização, palavras-passe, regras, dados em falta
e interface estão documentados nos README das componentes. A remoção de
credenciais não transforma a aplicação histórica num sistema seguro para
produção.

A confirmação de João Santos sobre o trabalho realizado e a documentação do
relatório constituem evidência histórica. Os resultados desta página
descrevem apenas a cópia atualmente preservada.
