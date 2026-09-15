# Resultados e limitações

## Protocolo documentado

- conjunto gerado: 10 000 registos inteiramente sintéticos;
- divisão de teste: 20%, ou 2 000 registos, com `random_state=42` e estratificação;
- algoritmo: XGBoost;
- limiar de decisão: 0,35;
- ROC AUC: 0,8813;
- recall da classe positiva: 0,82;
- F1 da classe positiva: 0,69.

Os testes automatizados reproduzem estas métricas a partir do CSV e do modelo serializado incluídos.

## Interpretação correta

O desfecho sintético é gerado por uma função de risco escrita à mão que usa os mesmos fatores disponíveis ao modelo, acrescida de ruído aleatório. Assim, os resultados medem a capacidade do classificador para recuperar essa lógica sintética. **Não medem desempenho diagnóstico ou prognóstico em população clínica.**

Não existem neste projeto dados reais, validação externa, calibração clínica, análise de subgrupos, estudo prospetivo, comparação com prática clínica nem avaliação por profissionais de saúde.

## FHIR

A integração aceita campos laboratoriais previamente normalizados num objeto inspirado em `Observation`. Não processa um recurso FHIR R4 completo, não valida perfis, terminologias ou bundles e não demonstra interoperabilidade com um LIS/EHR real.

## Segurança

Foram aplicadas correções pontuais na exportação, mas os controlos de segurança não estão integralmente demonstrados. Em particular, não foi concluída uma auditoria de autorização de todas as rotas nem uma implementação verificada de RLS, segregação de funções, logging de auditoria ou gestão de chaves.
