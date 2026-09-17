# Sistema de Apoio à Decisão para Diagnóstico do Cancro da Próstata — frontend preservado

Esta pasta contém uma **versão anterior e incompleta do código académico** do
Sistema de Apoio à Decisão para Diagnóstico do Cancro da Próstata. A versão final do código não ficou integralmente preservada. O relatório preserva a descrição
histórica do trabalho realizado, mas esta cópia não reproduz integralmente o
estado final descrito nesse documento.

O **menu de utente era uma funcionalidade extra que não chegou a ser
implementada**. A sua ausência não deve ser atribuída à perda da versão final.
O ramo de login que encaminha um utente para `/loco` é um vestígio incompleto:
essa rota e os respetivos ecrãs não existem nesta pasta.

A preparação para publicação abrangeu a documentação, a adoção da designação
confirmada por João nos textos da interface e a remoção de valores e registos
de diagnóstico sensíveis. Não reconstruiu funcionalidades nem corrigiu
os problemas funcionais do código. Em particular, permanece um erro de compilação
Angular, documentado abaixo. **Esta pasta não constitui uma demonstração pronta
a executar.** Consulte o [README do projeto](../README.md) para o enquadramento,
a autoria e a relação com o relatório.

## Funcionalidades presentes no código

As funcionalidades abaixo foram identificadas por leitura do código. A sua
presença não equivale a uma validação funcional completa.

| Área | Conteúdo preservado |
| --- | --- |
| Autenticação | Login por email ou username, receção de token e papel, persistência local da sessão e logout. |
| Administrador — utentes | Listagem e pesquisa por nome/número de utente; criação, edição, eliminação e consulta de detalhes; associação a médico; indicação da próxima consulta. |
| Administrador — consultas | Registo e eliminação de consultas previamente marcadas; verificações locais de horário futuro, horário de funcionamento e sobreposição com consultas do médico e do utente. |
| Administrador — médicos | Listagem e pesquisa por nome/especialidade; criação, edição, eliminação e consulta de detalhes. |
| Administrador — administradores | Listagem, pesquisa e gestão de contas de administração. |
| Médico — calendário | Visualização diária, semanal e mensal de consultas, com duração fixa de 30 minutos e informação de contacto do utente. |
| Médico — utentes | Listagem geral ou filtro “Meus Utentes”; consulta de dados, respostas a questionário e anamnese; visualização de alertas. |

O frontend médico lê respostas existentes através da API. Não existe aqui um
ecrã de preenchimento de questionários pelo utente, nem um menu de dados pessoais
ou consultas destinado ao utente. A existência do método `registarResposta` no
serviço HTTP não representa a implementação desses ecrãs.

## Organização

- `src/main.ts`: entrada da aplicação e configuração Syncfusion/localização.
- `src/app/app.routes.ts`: login, três rotas de administração e duas rotas médicas.
- `src/app/auth.guard.ts`: controlo de navegação por papel guardado localmente.
- `src/app/administradores-lista/`, `medicos-lista/` e `utentes-lista/`: área de administração.
- `src/app/calendario/` e `utentes-lista-med/`: área médica.
- `src/app/services/`: autenticação, utilizadores, médicos, utentes, consultas,
  histórico e respostas.
- `src/app/pipes/`: filtros de pesquisa das listagens.
- `src/app/**/*.spec.ts`: testes preservados, maioritariamente gerados pelo Angular CLI.

## Diferenças e limitações conhecidas

O relatório e o código têm alcances diferentes: o primeiro documenta o projeto
histórico e esta pasta preserva apenas o código que foi recuperado. Não se deve
apresentar uma imagem ou descrição do relatório como prova de que o respetivo
comportamento funciona nesta cópia. Quanto à área de utente, a clarificação do
autor prevalece: foi um extra não implementado.

| Ponto | Estado verificável nesta cópia |
| --- | --- |
| Arranque Angular | `AppComponent` é standalone, mas aparece no `bootstrap` de `AppModule`. O compilador Angular devolve `NG6009`. `main.ts` conserva também duas tentativas de arranque: `bootstrapModule` e `bootstrapApplication`. |
| Área de utente | O login contém o destino `/loco`, sem rota ou componentes correspondentes. O menu extra não foi implementado. |
| Questionários e anamnese | Dois identificadores de documentos estão fixos em `utentes-lista-med.component.ts`. Não existe configuração ou rotina de povoamento nesta pasta que os recrie. Uma base de dados nova não assegura as associações esperadas. |
| Ausência de respostas | O componente acede diretamente a `data.respostas[0].respostas`. Uma resposta vazia da API pode produzir erro, apesar das mensagens de estado vazio existentes no HTML. |
| Edição de utente | `guardarEdicao` referencia `isNumeroUtenteValidoEdit` sem a chamar. A validação visual não garante que um número inválido seja rejeitado ao guardar. |
| Marcação de consultas | Faltam verificações explícitas de data válida e médico selecionado. A regra das 18h00 verifica o início, não o fim dos 30 minutos. A garantia contra marcações concorrentes depende do backend. |
| Calendário | Carrega todos os utentes e faz pedidos adicionais por histórico e consultas. Os contadores de conclusão assíncrona e o teste de arrays vazios são frágeis, em particular quando existem utentes sem histórico. |
| Sessão e permissões | O guard consulta apenas o papel em `localStorage`; não valida a expiração do token. O servidor tem de garantir a autorização. A sessão usa os nomes de token `userToken` e `auth_token`. |
| Configuração | Os serviços usam endereços fixos em `http://localhost:8080/med`. Não existe separação de configuração por ambiente. |
| Interface e acessibilidade | Existem ícones com eventos de clique sem equivalente por teclado, modais sem gestão de foco explícita e ausência de `meta viewport`. Não foi realizada uma auditoria visual ou de acessibilidade completa. |

Este é um protótipo académico, sem validação para diagnóstico, tratamento,
monitorização clínica ou utilização em produção. A sanitização para publicação
não constitui uma auditoria de segurança nem resolve as limitações de autorização
ou de tratamento de dados da aplicação.

## Dependências preservadas

Não foram atualizadas dependências. As versões seguintes constam do
`package-lock.json` preservado, que deve acompanhar o `package.json`:

| Dependência | Versão no lockfile |
| --- | --- |
| Angular core / compiler-cli | 15.2.10 |
| Angular CLI | 15.2.11 |
| TypeScript | 4.9.5 |
| RxJS | 7.8.2 |
| Syncfusion Angular Schedule | 29.2.8 |
| Syncfusion base | 29.2.4 |
| Karma | 6.4.4 |
| Jasmine core | 4.5.0 |

O HTML carrega ainda Bootstrap 5.3.3 e Font Awesome 6.5.0 por CDN. O calendário
carrega CSS Syncfusion por um endereço sem versão fixa. Por isso, a aparência
também depende de recursos externos que o lockfile npm não controla.

## Preparação local para estudo

Os comandos seguintes descrevem a instalação prevista; não implicam que esta
cópia esteja funcional. Não foram fornecidas contas, credenciais, dados clínicos
ou uma base de dados de demonstração neste frontend.

1. Instalar Node.js e npm e entrar nesta pasta. A revisão foi executada com
   Node.js 22.14.0; isto regista o ambiente usado, sem certificar a compatibilidade
   de todas as ferramentas ou do arranque da aplicação.
2. Instalar as versões preservadas:

   ```sh
   npm ci
   ```

3. Para estudar uma eventual execução, seria necessário preparar a API e os dados
   locais correspondentes, incluindo os documentos de questionário esperados.
   Os serviços apontam para `http://localhost:8080/med`.
4. `src/main.ts` contém o marcador `YOUR_SYNCFUSION_LICENSE_KEY`. Quem pretender
   usar o componente deve configurar localmente uma chave própria válida e
   adequada à utilização, respeitando os termos do fornecedor. Não publicar a
   chave pessoal nem substituir o marcador na cópia destinada ao repositório.
5. Os scripts originais são `npm start`, `npm run build`, `npm run watch` e
   `npm test`. O erro Angular conhecido impede assumir que os comandos de
   arranque e compilação tenham sucesso. A correção ou reconstrução do projeto
   não fez parte desta preparação.

## Verificação da cópia preparada

Foram executadas verificações sem emissão de ficheiros, em 17 de setembro de
2026, usando temporariamente as dependências locais já instaladas no arquivo
original. Essas dependências não foram copiadas para a publicação. Não foi
executada uma nova instalação, pelo que a instalação limpa permanece por validar.

```sh
node node_modules/typescript/bin/tsc --noEmit -p tsconfig.app.json
node node_modules/typescript/bin/tsc --noEmit -p tsconfig.spec.json
node node_modules/@angular/compiler-cli/bundles/src/bin/ngc.js --noEmit -p tsconfig.app.json
```

| Verificação | Resultado |
| --- | --- |
| Tipos TypeScript da aplicação | Passou. |
| Tipos TypeScript dos testes | Passou. |
| Compilador Angular | Falhou com `NG6009` em `src/app/app.module.ts`, no `bootstrap` de `AppComponent`. |
| Testes Karma no navegador | Não executados. |
| Arranque, API, base de dados e testes funcionais | Não executados. |

Passar as verificações TypeScript não demonstra que os templates compilam nem
que os fluxos funcionam. Existem 15 ficheiros de teste com 17 casos,
maioritariamente verificações de criação de instâncias. O teste da raiz mantém
expectativas do projeto inicial `FrontEn`, diferentes do componente atual
`Sistema de Apoio à Decisão para Diagnóstico do Cancro da Próstata`; não há cobertura dos principais fluxos de negócio.

## Sanitização da publicação

A chave Syncfusion foi substituída pelo marcador indicado. Foram removidos logs
de tokens, utilizadores, utentes, consultas, históricos, respostas e payloads com
palavras-passe. Os erros HTTP conservam mensagens genéricas, sem imprimir o objeto
de erro potencialmente portador de dados. Os restantes comportamentos, os
identificadores de questionários, os testes e os problemas de compilação foram
preservados. Nenhuma destas operações modificou o arquivo académico original.
