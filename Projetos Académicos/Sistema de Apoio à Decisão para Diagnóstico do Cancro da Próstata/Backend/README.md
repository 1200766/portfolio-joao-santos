# Sistema de Apoio à Decisão para Diagnóstico do Cancro da Próstata — Backend

**Esta pasta não contém a versão final do código desenvolvido na unidade
curricular de Informática Médica.** É uma cópia anterior e incompleta que ficou
preservada. Segundo o esclarecimento de João Santos, alguns ficheiros da versão final
perderam-se com o tempo; o relatório é o registo do trabalho realizado.
As diferenças abaixo descrevem este arquivo e não demonstram que essas
funcionalidades estivessem ausentes da entrega académica.

O menu do utente foi um extra apresentado como proposta e **não foi
implementado**. A sua ausência é distinta das partes da versão final que não
ficaram preservadas.

Este backend pertence a um protótipo académico coletivo de apoio à decisão por
regras relacionado com o cancro da próstata. Não foi validado para diagnóstico,
tratamento ou utilização clínica e não está preparado para produção ou para
receber dados pessoais reais.

## Conteúdo preservado

A API usa TypeScript, Node.js, Express, MongoDB/Mongoose e JSON Web Tokens.
O código contém 32 endpoints, concentrados em `routes/UserRoutes.ts`, e sete
modelos em `models/`:

- utilizadores e respetivos perfis de médico e utente;
- históricos e registo de consultas previamente marcadas;
- questionários com perguntas e opções, e respostas dos utilizadores;
- autenticação por JWT e operações de criação, consulta, edição e remoção;
- uma rotina de geração de alertas a partir do questionário de perfil.

`server.ts` liga a base de dados à API, publicada sob o prefixo `/med`.
`auth/VerifyToken.ts` verifica os tokens. `config.ts` foi acrescentado durante a
preparação do arquivo para retirar os valores sensíveis do código.

## Diferenças face ao trabalho documentado

| Elemento do relatório | Estado desta cópia |
| --- | --- |
| Alertas de perfil e anamnese | Existe geração de alertas de perfil; não foi localizada uma rotina equivalente para os alertas de anamnese, apesar de existirem campos destinados a esses alertas. |
| Apresentação dos alertas da submissão mais recente | O código procura a resposta mais recente, mas acrescenta alertas ao conjunto já guardado. A política completa documentada não está reproduzida nesta cópia. |
| Omissão de alertas quando existe uma consulta adequada | A geração de alertas preservada não consulta os registos de consultas para aplicar esse comportamento. |
| Questionários de perfil e anamnese usados no projeto | Há modelos e operações para questionários e respostas, mas faltam a exportação da base de dados e os dados de inicialização. As regras dependem de identificadores fixos das perguntas e opções. |

Não foi reconstruída nenhuma destas funcionalidades. O relatório original é
mantido sem alterações na seleção do projeto, conforme a decisão de João Santos.

## Limitações técnicas conhecidas

- A geração de alertas usa `findOne`, que devolve um documento, e depois tenta
  ler `resposta[0].respostas`. Este acesso é incompatível com o resultado normal
  da consulta. Também existem condições incoerentes e ramos que não são
  alcançados na cadeia de regras preservada.
- As palavras-passe são guardadas e comparadas em texto simples. O login
  devolve o documento completo de utilizador, incluindo o campo de palavra-passe.
  Externalizar o segredo JWT não corrige estes comportamentos.
- A verificação JWT não implementa autorização efetiva por papel ou por
  titularidade dos registos. Os registos aceitam `isAdmin` do corpo do pedido.
- Não existe um procedimento preservado para inicializar o primeiro
  administrador; as rotas de registo exigem um token.
- Uma base de dados vazia não reproduz os questionários nem os alertas. Não são
  distribuídas contas, respostas, históricos ou outros dados da base original.
- Existem referências de modelos e operações sobre vários documentos cuja
  integridade precisa de revisão; alguns ramos continuam depois de enviar uma
  resposta HTTP.
- Não existe uma suite de testes do backend. `npm test` é o marcador original
  que termina com erro. As dependências e as regras mantêm as versões e a lógica
  do arquivo; não foi feita uma atualização de segurança nem uma validação
  funcional completa.

Estas limitações ficam documentadas para preservar o contexto histórico da
cópia, sem a apresentar como demonstração funcional do sistema final.

## Inspeção e verificação local

Os comandos seguintes são executados **dentro de `Backend/`**. A preparação foi
verificada com Node.js 22.14.0. Não são necessários MongoDB ou credenciais para
a verificação TypeScript.

Para instalar as dependências fixadas no lockfile, num ambiente de inspeção:

```sh
npm ci --ignore-scripts
```

Esse comando requer acesso ao registo npm; não foi executado nesta preparação.
As dependências já disponíveis no arquivo local foram utilizadas apenas para
verificação estática.

Para verificar o TypeScript sem emitir ficheiros e sem iniciar o servidor:

```sh
node node_modules/typescript/bin/tsc --noEmit --pretty false -p tsconfig.json
```

Para apenas compilar para `dist/`, se necessário para estudo local:

```sh
node node_modules/typescript/bin/tsc -p tsconfig.json
```

`dist/` é um resultado gerado e fica excluído da seleção para o repositório.
Passar a compilação não verifica o funcionamento dos endpoints, das regras ou
da ligação à base de dados.

## Configuração explícita para eventual estudo em execução

Não existem valores MongoDB ou JWT predefinidos. `config.ts` exige
`MONGODB_URI` e `JWT_SECRET`; valores ausentes ou vazios interrompem o arranque
antes da ligação à base de dados. A porta conserva o comportamento histórico:
`PORT`, quando definida, ou 8080.

Se se preparar posteriormente um ambiente isolado com dados exclusivamente
sintéticos, copiar `.env.example` para `.env` e preencher localmente os dois
valores obrigatórios. Não reutilizar credenciais do arquivo académico.

O Node.js 22 carrega o ficheiro com a opção nativa `--env-file`, sem acrescentar
`dotenv` ou outra dependência. Depois da compilação, o comando de arranque é:

```sh
node --env-file=.env dist/server.js
```

Este comando inicia efetivamente o servidor e tenta ligar à base configurada;
**não foi executado durante a preparação**. O código histórico não limita a
escuta à interface local e não deve ser exposto a uma rede pública. A
configuração de ambiente, por si só, não resolve os dados em falta nem as
limitações funcionais e de acesso descritas acima.

Como alternativa ao ficheiro, as variáveis podem ser fornecidas pelo ambiente
do processo e o Node iniciado sem `--env-file`. O ficheiro `.env` nunca deve
entrar no repositório.

## Alterações realizadas para preparar a publicação

- Mensagem inicial da API: adoção da designação do projeto confirmada por João.
- `server.ts`, `auth/VerifyToken.ts` e `routes/UserRoutes.ts`: substituição dos
  valores MongoDB/JWT embutidos por configuração externa obrigatória.
- `config.ts` e `.env.example`: declaração das variáveis necessárias, sem
  credenciais ou segredo de recurso.
- `routes/UserRoutes.ts`: remoção de dois logs que imprimiam o corpo integral
  de um pedido e o conteúdo de respostas clínicas.
- `package.json` e a entrada raiz de `package-lock.json`: o marcador original
  `ISC` passou a `UNLICENSED`, coerente com os direitos reservados da seleção.
  As dependências não foram alteradas.
- Este `README.md`: identificação da versão, lacunas, limitações e protocolo
  de inspeção.

As fontes académicas originais foram preservadas fora desta seleção. Não houve
correções funcionais, reconstrução de módulos nem contacto com a base de dados
original.

## Resultado da verificação

Em 17 de setembro de 2026, a verificação TypeScript sem emissão da cópia
preparada passou. Esta verificação é estática: não comprova o funcionamento
integral do backend. Não foram executados servidor, testes de integração,
instalação limpa ou atualização das dependências.

Para autoria e condições de reutilização, consultar o
[README do projeto](../README.md) e [RIGHTS.md](../RIGHTS.md).
