# Site Pessoal

[← Projetos Pessoais](../README.md) · [Índice geral](../../README.md)

Site público de João Santos, Engenheiro Biomédico em início de carreira. O
projeto reúne evidência de trabalho em sinais biomédicos, software e dados,
sistemas clínicos, segurança e dispositivos médicos, com uma distinção explícita
entre autoria individual e trabalho realizado em equipa.

Site: [joao-santos-biomedica.joaprs.chatgpt.site](https://joao-santos-biomedica.joaprs.chatgpt.site)

Repositório: [github.com/1200766/portfolio-joao-santos](https://github.com/1200766/portfolio-joao-santos)

## Relação com o portefólio

Esta pasta contém apenas o código e os recursos que constroem o site público.
As versões públicas completas dos projetos apresentados no site encontram-se
nas duas coleções do repositório.

| Área | Onde consultar |
|---|---|
| Site publicado | [joao-santos-biomedica.joaprs.chatgpt.site](https://joao-santos-biomedica.joaprs.chatgpt.site) |
| Código do site | [`app/`](app/), [`worker/`](worker/) e [`tests/`](tests/) |
| Projetos académicos | [Abrir a coleção](<../../Projetos Académicos/>) |
| Projetos pessoais | [Abrir a coleção](../) |

As pastas de projetos são artefactos consultáveis diretamente no GitHub.
Acrescentar uma pasta ao repositório não cria automaticamente uma página ou
uma ligação no site: os projetos apresentados na interface continuam definidos
em `app/data/projects.ts`.

## O que este repositório demonstra

- implementação de uma aplicação Web em TypeScript e React;
- organização de conteúdo através de um modelo de dados tipado e escalável;
- atenção a acessibilidade, responsividade, metadados e segurança HTTP;
- testes sobre a aplicação compilada e integração contínua;
- utilização real de Git e GitHub sem transformar atividade ou histórico em
  prova de competências que o próprio trabalho não demonstra.

## Estrutura do conteúdo

No site, os projetos públicos estão definidos em `app/data/projects.ts` e
separados em duas coleções:

- **projetos pessoais**, com autoria individual e responsabilidade direta pela
  publicação;
- **projetos académicos e curriculares**, com o contexto, o tipo de autoria, a
  evidência disponível e os limites de cada resultado.

O MediBrain é também apresentado como experiência curricular em destaque. O
repositório inclui apenas versões públicas curadas dos projetos que concluíram
a respetiva revisão. Os arquivos originais, dados privados e materiais
excluídos permanecem fora do repositório.

Projetos privados ou ainda sem uma decisão explícita de publicação são omitidos
deliberadamente.

## Arquitetura

| Área | Responsabilidade |
|---|---|
| `app/page.tsx` | composição semântica da página e apresentação do conteúdo |
| `app/data/projects.ts` | fonte tipada dos casos de projeto publicáveis |
| `app/globals.css` | sistema visual, estados de interação e adaptação responsiva |
| `app/layout.tsx` | metadados, origem canónica e dados estruturados |
| `lib/sites-vite-plugin.ts` | empacotamento da configuração de Sites no artefacto compilado |
| `worker/index.ts` | entrada Cloudflare Worker e cabeçalhos de segurança |
| `tests/rendered-html.test.mjs` | contratos públicos sobre HTML, privacidade e ativos |

O projeto usa Next.js através de Vinext e é compilado para um Cloudflare Worker.
A configuração de OpenAI Sites permanece em `.openai/hosting.json`; esse ficheiro
contém apenas o identificador do Site e as declarações lógicas de recursos.

## Desenvolvimento local

Requisito: Node.js 22.13 ou superior.

```bash
npm ci
npm run dev
```

Validação completa:

```bash
npm run lint
npm test
```

`npm test` produz primeiro a compilação de produção e executa depois os testes
contra a entrada real do Worker. O workflow do repositório em
[`../../.github/workflows/ci.yml`](../../.github/workflows/ci.yml) repete estas
verificações em cada alteração ao ramo `main` e em pull requests; não faz
publicações automáticas.

## Salvaguardas de publicação

- O site expõe como contactos apenas nome, email e LinkedIn. O currículo segue
  a sua própria política de contacto e é verificado separadamente.
- Nenhuma credencial ou variável de ambiente é guardada no repositório.
- O histórico Git completo deve ser auditado antes de qualquer push público;
  corrigir apenas a versão atual não remove dados de revisões anteriores.
- Uma ligação para código académico só é acrescentada depois de existirem
  autorização e contexto suficientes para a interpretar corretamente.
- Visibilidade pública não é usada para sugerir experiência de produção,
  validação clínica ou autoria individual quando a evidência não as suporta.

## Assistência de IA

O desenvolvimento e a revisão deste projeto tiveram apoio do OpenAI Codex. João
Santos mantém a decisão sobre o conteúdo, revê as alterações, valida os
resultados e autoriza a publicação. Esta transparência faz parte da forma como o
repositório documenta o trabalho realizado; a assistência não é apresentada
como experiência ou contribuição humana que não existiu.

## Licença

Não foi escolhida uma licença de reutilização. A disponibilidade pública do
código não concede, por si só, autorização para o reutilizar ou redistribuir.
