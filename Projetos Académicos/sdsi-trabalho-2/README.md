# Trabalho 2 — Segurança e conformidade num sistema hospitalar distribuído

[← Projetos Académicos](../README.md)

Proposta académica de consultoria para um hospital fictício. O trabalho combina arquitetura distribuída, interoperabilidade clínica, análise de ameaças, governação, enquadramento jurídico e normativo europeu e um plano faseado de melhoria.

> O cenário, a organização e os intervenientes são fictícios. O documento não é uma auditoria, parecer jurídico, orçamento comercial ou plano pronto a executar.

## Proposta

- proteger fluxos DICOM, HL7 v2 e FHIR com TLS e autenticação adequada;
- aplicar MFA, RBAC, mínimo privilégio, segregação e revisão periódica de acessos;
- centralizar logs, monitorização e resposta a incidentes;
- reforçar backups, redundância, continuidade e recuperação;
- separar serviços locais e cloud numa arquitetura híbrida;
- gerir dispositivos e integrações ao longo do ciclo de vida;
- considerar os requisitos aplicáveis do RGPD e do regime português que transpõe a NIS2, preparar a aplicação faseada do EEDS e usar a IEC 80001-1:2021 como referência técnica de gestão do risco.

Os controlos enumerados são propostas. A sua presença não demonstra conformidade jurídica, certificação ou eficácia numa organização real.

## Revisão regulatória

Esta secção foi revista em **14 de setembro de 2026** com base em fontes oficiais:

- o [RGPD](https://eur-lex.europa.eu/eli/reg/2016/679/oj?locale=pt) é diretamente aplicável e os dados de saúde são uma categoria especial. Um tratamento real exige um fundamento do artigo 6.º, uma condição aplicável do artigo 9.º e medidas adequadas ao risco nos termos do artigo 32.º; o consentimento é uma possibilidade, não a única base para todos os tratamentos hospitalares;
- Portugal transpôs a NIS2 através do [Decreto-Lei n.º 125/2025](https://diariodarepublica.pt/dr/detalhe/decreto-lei/125-2025-962603401), complementado pelo [Regulamento n.º 756/2026](https://diariodarepublica.pt/dr/detalhe/regulamento/756-2026-1134399056). Os prestadores de cuidados de saúde constam do setor da saúde, mas a qualificação e os deveres concretos de uma entidade dependem da sua natureza, dimensão e enquadramento. Para incidentes significativos, o regime prevê uma notificação inicial até 24 horas, uma atualização até 72 horas quando necessária, uma notificação até 24 horas após o fim do impacto significativo e um relatório final até 30 dias úteis depois desta última notificação;
- o [Regulamento (UE) 2025/327 relativo ao Espaço Europeu de Dados de Saúde](https://eur-lex.europa.eu/legal-content/PT/ALL/?uri=CELEX%3A32025R0327), ou EEDS/EHDS, entrou em vigor em 2025, mas a sua aplicação é faseada a partir de 2027, com partes essenciais em 2029 e 2031;
- a [IEC 80001-1:2021](https://webstore.iec.ch/en/publication/34263) é uma norma técnica internacional de gestão do risco para sistemas de TI de saúde ligados em rede. Não é um regulamento europeu nem, por si só, uma obrigação legal geral.

O plano de aproximadamente 12 meses é uma sequência académica ilustrativa, não um prazo legal nem um plano de implementação validado.

## Custos

O relatório académico original, concluído em dezembro de 2025, incluiu intervalos exploratórios elaborados com apoio de IA. Não existiam um inventário dimensionado, medições de consumo, preços por utilizador, volumes de logs ou propostas de fornecedores. Por isso, esses valores **não constituem uma estimativa de mercado verificável e não são reproduzidos nesta versão pública**.

Um orçamento atual exige uma arquitetura concreta, consumos medidos, exportações datadas das calculadoras oficiais e cotações comparáveis, incluindo implementação, suporte, impostos e contingência. Por exemplo, o custo de um SIEM varia com o volume de dados, a retenção e o nível de serviço, como explica a [documentação de custos do Microsoft Sentinel](https://learn.microsoft.com/en-us/azure/sentinel/billing).

## Conteúdo

- `docs/proposta-sanitizada.md` — síntese da arquitetura, riscos, controlos e roadmap;
- `docs/INVENTARIO_EXCLUIDO.md` — materiais do arquivo académico que ficaram de fora;
- `AUTHORS.md` e `CONTRIBUTIONS.md` — autoria conjunta;
- `RIGHTS.md` — direitos reservados.
