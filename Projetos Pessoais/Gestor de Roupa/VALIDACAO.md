# Validação da exportação pública

**Data da revisão:** 17 de setembro de 2026

## Âmbito

Esta validação abrange a cópia pública curada. A fonte original foi mantida
separada e não foi modificada.

## Controlos de segurança

- inventário servido a partir do ficheiro JSON estático;
- rota de escrita no servidor excluída;
- base de dados, migrações e exemplo D1 excluídos;
- edições limitadas ao `localStorage` do navegador;
- ação de reposição dos dados originais disponível;
- `.git`, credenciais, ficheiros de ambiente e estado local excluídos;
- caminhos privados removidos do importador;
- substituição pelo importador protegida por `--replace` e validação sem
  escrita disponível com `--dry-run`;
- 135 fotografias mantidas por decisão expressa do autor;
- nenhuma coordenada GPS detetada nas fotografias.

## Resultados técnicos

Ambiente utilizado: Node.js `v22.14.0` e npm `11.2.0`.

| Verificação | Resultado |
|---|---|
| `npm ci` | concluído com sucesso |
| `npm run lint` | concluído sem erros nem avisos |
| `npx tsc --noEmit` | concluído sem erros de tipos |
| `npm run build` | compilação Vinext concluída |
| `npm test` | 5 testes aprovados, 0 falhas |
| `npm audit` | 0 vulnerabilidades conhecidas no lockfile atual |
| arranque de produção | `/` e `/catalogo` responderam com HTTP 200 |

As dependências diretamente relacionadas com alertas encontrados durante a
revisão foram atualizadas antes desta validação. Em particular, a versão de
Next.js passou para `16.3.5`; o lockfile final foi novamente instalado,
compilado, testado e auditado.

## Nota sobre a compilação

O Vinext identifica `/` e `/catalogo`, mas apresenta um aviso informativo de
que a sua análise estática ainda não classifica todas as rotas que usam APIs
dinâmicas como `headers()`. A compilação termina normalmente e ambas as rotas
foram verificadas no servidor de produção local.
