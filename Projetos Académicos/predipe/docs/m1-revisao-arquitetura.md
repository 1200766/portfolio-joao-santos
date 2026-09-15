# M1 — Revisão de âmbito e arquitetura conceptual

## Enquadramento

A primeira fase do PrediPE analisou modelos preditivos e sistemas de apoio à decisão para pré-eclâmpsia. A revisão identificou três barreiras recorrentes à adoção:

1. fragmentação de dados clínicos, laboratoriais e de imagem;
2. modelos estáticos que não acompanham a evolução longitudinal da gravidez;
3. modelos opacos cuja previsão é difícil de transformar numa ação clínica justificável.

## Dados e requisitos considerados

A proposta combina fatores maternos e clínicos — idade, IMC, paridade, pré-eclâmpsia prévia, diabetes, hipertensão crónica e doença renal — com pressão arterial média, Doppler das artérias uterinas e biomarcadores angiogénicos, incluindo PlGF e a razão sFlt-1/PlGF.

Da revisão resultaram requisitos conceptuais:

- integrar fontes multimodais num fluxo coerente;
- recalcular risco em várias janelas gestacionais;
- apresentar probabilidade, categoria, fatores contribuintes e ação sugerida;
- separar contexto da paciente, gravidez, observações e avaliações;
- registar proveniência e histórico;
- preparar uma camada de interoperabilidade;
- limitar acessos por perfil e considerar governação, privacidade e responsabilidade.

## XAI e interoperabilidade

Foi escolhido XGBoost como compromisso académico entre desempenho e interpretabilidade, com SHAP para explicar contribuições globais e por avaliação. Uma explicação não prova validade clínica: a utilidade das explicações teria de ser avaliada com profissionais e dados reais.

FHIR foi adotado como direção arquitetural para reduzir acoplamento entre o protótipo e sistemas laboratoriais ou clínicos. A fase M1 propôs essa camada; a fase M2 implementou apenas um endpoint simplificado com campos previamente normalizados, não um servidor ou cliente FHIR R4 conforme.

## Arquitetura conceptual

```text
História materna ─┐
MAP / pressão ────┼─> normalização e validação ─> modelo XGBoost
Doppler UtA-PI ───┤                              │
PlGF / sFlt-1 ────┘                              ├─> probabilidade e estrato
                                                  ├─> fatores SHAP
FHIR/LIS simplificado ─> camada de integração ────└─> alerta e seguimento
                                                           │
                           histórico longitudinal <────────┘
```

## Relação com M2

M2 transformou esta proposta num protótipo executável. Como os dados finais são sintéticos e o adaptador FHIR é parcial, as conclusões da revisão continuam a ser enquadramento e direção de desenho, não evidência de eficácia clínica ou interoperabilidade real.
