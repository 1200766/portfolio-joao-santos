# Validação da exportação pública

**Data:** 17 de setembro de 2026
**Estado:** aprovada para publicação no repositório público.

## Âmbito

A validação cobre a exportação pública desta pasta, sem reutilizar a base D1
local da aplicação original. O ensaio de integração usa uma base descartável,
credenciais de teste e um resultado fictício e determinístico.

## Resultados

- `npm ci`: instalação concluída a partir do `package-lock.json`;
- `npm run typecheck`: concluído sem erros; foram corrigidos os cinco erros
  TypeScript encontrados na versão de origem;
- `npm run lint`: concluído sem erros nem avisos;
- `npm test`: build de produção concluído e 5/5 testes automatizados aprovados;
- `npm run test:integration`: 35/35 verificações aprovadas numa D1 temporária;
- `npm audit --omit=dev`: zero vulnerabilidades nas dependências de produção;
- auditoria de conteúdo: sem credenciais, base de dados, contacto MB WAY real,
  identificador de alojamento, caminhos absolutos ou artefactos gerados;
- comparação SHA-256: os 65 ficheiros versionados da fonte original mantiveram
  exatamente o mesmo conteúdo.

O teste de integração usou a ordem fictícia `47, 11, 22, 33, 44` para
2026-07-24. Não efetuou pedidos à fonte real de resultados e apagou a base e o
diretório temporários no fim.

## Alterações de segurança e publicação

- o número MB WAY foi substituído por `9********`;
- os valores de `.env.example` são placeholders inequívocos;
- o identificador do projeto de alojamento foi removido;
- o nome pessoal do administrador foi generalizado na interface e nos testes;
- a base D1 local, `output/`, `outputs/`, caches, builds e repositórios Git
  aninhados não fazem parte da exportação;
- o Next.js foi atualizado para 16.3.5 e a dependência transitiva
  `baseline-browser-mapping` para uma versão sem o aviso de produção detetado.

## Limitações conhecidas

- a consulta da página pública de resultados depende de HTML externo e pode
  deixar de funcionar se esse formato mudar;
- o ensaio não valida transferências reais, porque não existe integração de
  pagamentos;
- a auditoria npm completa ainda reporta avisos em ferramentas usadas apenas
  durante o desenvolvimento; a auditoria das dependências de produção não
  reporta vulnerabilidades;
- uma instalação real continua a exigir uma D1 configurada, aplicação das
  migrações e credenciais próprias fora do Git.
