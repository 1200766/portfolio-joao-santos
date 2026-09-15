# Proposta sanitizada

## Cenário

Uma organização hospitalar fictícia troca dados entre sistemas clínicos, laboratório, imagiologia, utilizadores remotos e serviços cloud. Protocolos históricos, integrações heterogéneas e equipamentos com diferentes ciclos de vida criam uma superfície de ataque distribuída.

## Arquitetura proposta

```text
Dispositivos e modalidades
          |
    rede clínica segmentada
          |
  gateways DICOM / HL7 / FHIR
          |
serviços clínicos + identidade + logs
          |
 cloud híbrida / cópia resiliente
```

Os gateways terminam comunicações protegidas, validam origem e formato, reduzem exposição direta e centralizam auditoria. Identidade, regras de acesso e logs atravessam as várias camadas.

## Ameaças principais

- interceção ou alteração de tráfego clínico;
- credenciais fracas, reutilizadas ou sem MFA;
- privilégios excessivos e contas órfãs;
- movimento lateral entre segmentos;
- dispositivos sem atualização ou inventário;
- indisponibilidade, ransomware e perda de dados;
- integrações sem rastreabilidade ou validação.

## Controlos propostos

1. inventário de ativos, fluxos, proprietários e dependências;
2. segmentação de rede e filtragem por necessidade;
3. TLS 1.3 quando suportado, mTLS em integrações adequadas e gestão formal de certificados;
4. MFA, RBAC, mínimo privilégio e revisão periódica de acessos;
5. centralização de logs, SIEM, alertas e procedimentos de resposta;
6. backups imutáveis testados, redundância e exercícios de recuperação;
7. hardening, gestão de vulnerabilidades e atualização faseada;
8. requisitos de segurança e privacidade para fornecedores e cloud;
9. formação e exercícios regulares.

## Roadmap académico ilustrativo

Esta sequência organiza a proposta original. Não representa um prazo legal, uma garantia de conclusão em 12 meses ou um plano validado para uma entidade real.

- **0–3 meses:** inventário, segmentação prioritária, identidade, backups e riscos críticos;
- **4–6 meses:** gateways seguros, TLS, logging central e procedimentos de incidentes;
- **7–9 meses:** resiliência, cloud híbrida, testes de recuperação e gestão de terceiros;
- **10–12 meses:** auditoria, métricas, formação e melhoria contínua.

## Enquadramento regulatório revisto

Revisão efetuada em **14 de setembro de 2026**:

- **RGPD:** o [Regulamento (UE) 2016/679](https://eur-lex.europa.eu/eli/reg/2016/679/oj?locale=pt) é diretamente aplicável e a sua execução em Portugal é assegurada pela [Lei n.º 58/2019](https://diariodarepublica.pt/dr/detalhe/lei/58-2019-123815982). Os dados de saúde são uma categoria especial. O tratamento requer um fundamento jurídico do artigo 6.º e uma condição aplicável do artigo 9.º; consentimento explícito é uma das possibilidades, não uma regra universal. As medidas de segurança do artigo 32.º devem ser adequadas ao risco.
- **NIS2 em Portugal:** a Diretiva (UE) 2022/2555 foi transposta pelo [Decreto-Lei n.º 125/2025](https://diariodarepublica.pt/dr/detalhe/decreto-lei/125-2025-962603401), em vigor desde abril de 2026, e complementada pelo [Regulamento n.º 756/2026](https://diariodarepublica.pt/dr/detalhe/regulamento/756-2026-1134399056). Os prestadores de cuidados de saúde estão incluídos no setor da saúde, mas a qualificação concreta de um hospital e os deveres aplicáveis dependem dos critérios legais, da sua natureza e dimensão e dos regimes transitórios. A notificação de incidentes significativos não se resume a “24 horas”: inclui uma notificação inicial até 24 horas, uma atualização até 72 horas quando necessária, uma notificação até 24 horas após o fim do impacto significativo e um relatório final até 30 dias úteis depois desta última notificação.
- **EEDS/EHDS:** o [Regulamento (UE) 2025/327](https://eur-lex.europa.eu/legal-content/PT/ALL/?uri=CELEX%3A32025R0327) já não é uma proposta. Entrou em vigor em 2025 e tem [aplicação faseada](https://health.ec.europa.eu/ehealth-digital-health-and-care/european-health-data-space-regulation-ehds_en) a partir de 26 de março de 2027, com partes essenciais em 2029 e 2031. Sendo um regulamento da União Europeia, não é transposto como uma diretiva.
- **IEC 80001-1:2021:** é uma [norma técnica internacional](https://webstore.iec.ch/en/publication/34263) sobre gestão do risco antes, durante e depois da ligação de sistemas de TI de saúde a uma infraestrutura de TI. Não é legislação nem constitui certificação automática de conformidade.

Os controlos desta proposta devem ser escolhidos e validados através de uma avaliação de risco e de aplicabilidade própria. TLS 1.3, mTLS, SIEM, cloud híbrida e backups imutáveis não são apresentados como obrigações universais impostas por todos estes instrumentos.

## Metodologia de custos

Os intervalos do relatório original eram um exercício académico assistido por IA, sem inventário dimensionado, consumo medido ou cotações. As somas estavam aritmeticamente coerentes, mas os valores-base não puderam ser validados como preços de mercado em 14 de setembro de 2026. Esta versão pública não os apresenta como orçamento atual.

Uma futura estimativa deve separar implementação e operação recorrente e quantificar, pelo menos:

- na cloud: região, computação, armazenamento DICOM, base de dados, backups, replicação, tráfego, disponibilidade e suporte;
- na identidade: utilizadores, identidades técnicas, aplicações, MFA, governação e integração;
- no logging e SIEM: fontes, GB ingeridos por dia, retenção, nível de análise e cobertura do SOC;
- no TLS: certificados públicos, PKI privada, automação, HSM quando aplicável e número de endpoints e parceiros;
- migração, interoperabilidade, segmentação, formação, auditorias, testes de recuperação e suporte, estimados em horas ou por propostas de fornecedores.

Cada cenário deve registar data, região, moeda, impostos, descontos, duração contratual, pressupostos e fonte. Os custos de cloud e SIEM, por exemplo, dependem diretamente da configuração e do consumo, conforme a [calculadora oficial do Azure](https://azure.microsoft.com/en-us/pricing/calculator/) e a [documentação de custos do Microsoft Sentinel](https://learn.microsoft.com/en-us/azure/sentinel/billing).
