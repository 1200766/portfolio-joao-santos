# Gestor de Roupa

Aplicação web criada por **João Pedro Ribeiro dos Santos** para organizar um
inventário de roupa, consultar as respetivas fotografias e preparar informação
útil para futuros anúncios de venda. A interface pública mantém a designação
visual **Segunda Volta**.

Esta pasta é uma exportação curada para o portefólio público. Não contém a
base de dados, o histórico Git, credenciais, configurações privadas nem
artefactos de compilação da área de trabalho original.

## Funcionalidades

- catálogo pesquisável de 46 peças e 135 fotografias;
- filtros por tipo e estado;
- galeria de fotografias por peça;
- edição local de tipo, marca, tamanho, preço e estado;
- reposição do inventário original incluído no repositório.

## Segurança da versão pública

O inventário é lido diretamente de `data/clothes.json`. A versão pública não
tem rotas de escrita, base de dados pública ou operações `POST`, `PUT` e
`DELETE` no servidor.

As alterações feitas no catálogo são guardadas apenas no `localStorage` do
navegador em utilização. Não são transmitidas para o servidor, não são
partilhadas entre dispositivos e podem ser eliminadas através da ação **Repor
dados originais**.

## Instalação e execução

Requisitos:

- Node.js 22.13 ou posterior;
- npm.

```bash
npm ci
npm run dev
```

O endereço local é indicado pelo servidor de desenvolvimento.

## Verificação

```bash
npm run lint
npm run build
npm test
```

`npm test` volta a compilar a aplicação e verifica o inventário, a existência
das 135 fotografias, os principais contratos visuais e a ausência da antiga
rota de escrita no servidor. Os resultados da exportação estão registados em
[VALIDACAO.md](VALIDACAO.md).

## Dados e fotografias

O autor decidiu incluir publicamente as 46 peças, os respetivos atributos, as
135 fotografias e `public/og.png`. Estes materiais pertencem ao inventário
selecionado pelo autor para demonstração no portefólio; não são dados
sintéticos. A finalidade, os metadados detetados e os limites de reutilização
estão explicados em [DATA_POLICY.md](DATA_POLICY.md).

## Importador opcional

O script `scripts/import-clothes.mjs` transforma um arquivo de origem numa
estrutura estática compatível com a aplicação. Lê as duas pastas esperadas,
extrai os parâmetros dos ficheiros `Parametros.rtf`, converte e dimensiona as
fotografias e volta a gerar `public/roupa/` e `data/clothes.json`.

O caminho privado anteriormente incorporado no script foi removido. A pasta de
origem tem agora de ser indicada explicitamente:

```bash
node scripts/import-clothes.mjs "/caminho/para/o/inventario" --dry-run
node scripts/import-clothes.mjs "/caminho/para/o/inventario" --replace
```

A pasta indicada deve conter `ROUPA Adicionada/` e `Roupa Por Adicionar/`. O
script depende de `textutil` e `sips`, pelo que esta ferramenta auxiliar é
específica de macOS. `--dry-run` valida a estrutura sem escrever. A opção
`--replace` é uma confirmação explícita: volta a gerar e substitui o catálogo e
as fotografias estáticas existentes. A conversão é preparada numa pasta
temporária antes dessa substituição, mas a execução deve ainda assim ser feita
apenas sobre uma cópia de trabalho.

## Limitações

- não é uma loja nem um mercado de roupa;
- não cria contas, anúncios, pagamentos ou vendas;
- não sincroniza alterações entre navegadores;
- não autentica utilizadores;
- as marcas mencionadas pertencem aos respetivos titulares e são usadas apenas
  para descrever as peças.

## Autoria e direitos

O site e o código foram criados por João Pedro Ribeiro dos Santos. Consulta
[AUTHORS.md](AUTHORS.md) e [RIGHTS.md](RIGHTS.md). Não foi atribuída uma licença
de código aberto.
