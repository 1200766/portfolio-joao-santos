# Sexta 50

Aplicação Web para gerir semanalmente 50 números: reserva por participante,
confirmação manual do pagamento, fecho da semana, apuramento das três primeiras
posições e consulta do histórico pelo administrador.

Esta pasta é uma exportação pública curada. Não contém a base D1 usada durante
o desenvolvimento, credenciais, documentos de impressão nem outros resultados
gerados localmente.

## Funcionalidades

- mapa público dos números disponíveis e reservados;
- área individual protegida por um token aleatório de reserva;
- autenticação da área administrativa com sessão assinada;
- confirmação, devolução e desbloqueio manual de pagamentos;
- processamento semanal e arquivo dos resultados;
- persistência em Cloudflare D1 através de Drizzle ORM.

## Requisitos

- Node.js 22.13 ou posterior;
- npm;
- `sqlite3` apenas para executar o teste de integração local descartável.

## Instalação e configuração

```bash
npm ci
cp .env.example .env.local
```

Preenche `ADMIN_USERNAME`, `ADMIN_PASSWORD` e `ADMIN_SESSION_SECRET` em
`.env.local`. A palavra-passe deve ser exclusiva e o segredo de sessão deve ser
longo e aleatório. Os ficheiros `.env*`, com exceção de `.env.example`, estão
ignorados pelo Git.

A aplicação espera um binding D1 denominado `DB`. As migrações versionadas
estão em `drizzle/`; devem ser aplicadas à base configurada pelo ambiente de
alojamento antes da utilização. Para desenvolvimento rápido e inteiramente
descartável, `npm run test:integration` cria e migra automaticamente uma base
D1 temporária.

## Utilização

```bash
npm run dev
```

O mapa público fica na raiz e a administração em `/admin`. A aplicação guarda
nomes, números de telemóvel, reservas e estados de pagamento na base D1 que for
configurada pelo responsável da instalação.

O contacto apresentado para transferência é deliberadamente fictício
(`9********`). Quem reutilizar o código terá de definir o seu próprio processo
operacional fora desta demonstração.

## Validação

```bash
npm run typecheck
npm run lint
npm test
npm run test:integration
```

O teste de integração inicia uma instância local isolada, cria uma base D1 num
diretório temporário e usa um resultado determinístico. Não lê nem altera a
base local de desenvolvimento e não consulta o resultado real do Euromilhões.
Os resultados da preparação desta exportação estão em
[VALIDACAO.md](VALIDACAO.md).

## Dados e privacidade

- não são publicados ficheiros SQLite nem estado de execução do D1;
- `node_modules`, `.wrangler`, `.vinext`, `dist`, `output` e `outputs` são
  gerados ou privados e permanecem fora do repositório;
- os registos criados pelos testes são fictícios e existem apenas na base
  temporária;
- uma instalação real deve limitar o acesso administrativo, proteger as
  credenciais e definir retenção e eliminação dos dados dos participantes.

## Limitações e independência

Este projeto é uma ferramenta pessoal e uma demonstração técnica. **Não existe
integração de pagamentos ou integração técnica com o MB WAY**: o site não
inicia, recebe nem valida transferências. A confirmação é sempre manual.

Também **não existe associação, parceria ou API oficial com a entidade que
gere o Euromilhões**. O código contém um leitor experimental da página pública
de resultados, sujeito a alterações do formato e a indisponibilidade. Antes de
usar a aplicação num contexto real, é necessário avaliar autonomamente os
requisitos legais, fiscais, de proteção de dados e de organização do sorteio.

Autoria e direitos: [AUTHORS.md](AUTHORS.md) e [RIGHTS.md](RIGHTS.md).
