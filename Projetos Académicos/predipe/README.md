# PrediPE

[← Projetos Académicos](../README.md)

Protótipo académico de um sistema de apoio à decisão clínica para estimar e acompanhar o risco de pré-eclâmpsia. Combina um modelo XGBoost explicável por SHAP, regras de apresentação clínica, uma API FastAPI, uma interface web estática e um adaptador FHIR simplificado.

> **Uso exclusivamente académico.** O PrediPE não é um dispositivo médico, não está clinicamente validado e não deve ser usado para diagnosticar, tratar ou apoiar decisões sobre pessoas reais.

## Estado

Esta é a exportação final e sanitizada preparada para publicação. Os valores de
configuração foram substituídos por placeholders e os materiais intermédios
ficaram fora desta pasta. As credenciais externas anteriormente expostas foram
desativadas ou revogadas e a palavra-passe da base de dados foi alterada em
2026-09-11; nenhum valor novo foi copiado para a exportação.

Segundo declaração de João Santos em 2026-09-11, ambos os autores já autorizaram
a publicação pública do trabalho conjunto. Esta autorização não concede uma
licença aberta. Consulte `SECURITY.md`, `AUTHORS.md`, `RIGHTS.md` e
`docs/INVENTARIO_EXCLUIDO.md`.

## O que demonstra

- geração determinística de um conjunto de dados inteiramente sintético;
- treino e serialização de um classificador XGBoost;
- limiar de decisão configurado a 0,35;
- explicações globais e individuais com SHAP;
- reavaliação longitudinal e camada de alertas;
- API REST com perfis de médico e administrador;
- entrada laboratorial inspirada em FHIR.

O endpoint FHIR aceita um objeto já normalizado com alguns campos de uma observação. **Não é uma implementação nem uma validação de conformidade FHIR R4.**

## Fases do projeto

- **M1 — revisão de âmbito e arquitetura conceptual:** enquadramento clínico, fatores multimodais, requisitos, explicabilidade, interoperabilidade e proposta de arquitetura. Consulte `docs/m1-revisao-arquitetura.md`.
- **M2 — protótipo funcional:** dados sintéticos, treino XGBoost, explicações SHAP, camada clínica, backend, frontend e adaptador FHIR simplificado. Consulte `docs/resultados-e-limitacoes.md`.

## Estrutura

- `modelo/` — gerador sintético, treino, dados e imagens de explicabilidade;
- `backend/` — API FastAPI, modelo serializado e migrações SQL;
- `frontend/` — páginas HTML/CSS;
- `tests/` — verificações de reprodutibilidade e métricas;
- `docs/` — resultados, limitações, correções e inventário da exportação.

## Preparação do ambiente

Requer Python 3.12 ou posterior.

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
cp backend/.env.example backend/.env
```

Preencha `backend/.env` com um projeto Supabase descartável. Nunca use dados pessoais ou clínicos. Use a chave `publishable` em `SUPABASE_PUBLISHABLE_KEY` e a chave `secret` em `SUPABASE_SECRET_KEY`. A chave `secret` é necessária para as operações clínicas, só pode existir no backend e nunca deve ser enviada para o browser.

Execute, por esta ordem, `backend/sql/001_clinical_data_model.sql` e `backend/sql/002_rls_clinical_tables.sql`. O segundo ativa RLS e retira acesso direto aos papéis `anon` e `authenticated`; a chave `secret` autentica o backend como `service_role`, contorna RLS e exige verificações de pertença antes das rotas humanas. Uma implantação real continua a exigir uma auditoria e testes de autorização.

O adaptador FHIR está desativado por omissão. Para uma demonstração isolada com dados sintéticos, defina uma chave exclusiva em `FHIR_API_KEY` e `FHIR_INGEST_ENABLED=true`. A chave partilhada concede acesso de integração a todas as gravidezes do ambiente descartável e não deve ser reutilizada.

## Execução local

Na raiz deste projeto:

```bash
uvicorn main:app --app-dir backend --reload
python -m http.server 5500 --directory frontend
```

A API fica por omissão em `http://127.0.0.1:8000` e a interface em `http://127.0.0.1:5500`.

## Reproduzir o modelo

```bash
cd modelo
python GerarDados.py
python TreinarModelo.py
```

O treino substitui os artefactos no diretório corrente. Copie-os para `backend/ml/` apenas depois de validar os resultados.

## Testes

```bash
python -m unittest discover -s tests -v
```

Os testes verificam que o gerador é determinístico e que o modelo publicado reproduz, sobre a divisão sintética documentada, as métricas indicadas em `docs/resultados-e-limitacoes.md`.

## Limitações de segurança

Esta exportação restringe CORS por configuração, desativa FHIR por omissão, não persiste a chave FHIR no browser, usa um cliente isolado no login e verifica a pertença nas rotas humanas por paciente ou gravidez. Isto **não equivale a uma auditoria completa**. Os fluxos de autenticação e autorização ainda precisam de testes de integração, e a abrangência das políticas RLS, a gestão de segredos, a monitorização e a proteção operacional continuam por demonstrar.

## Autoria e direitos

Consulte `AUTHORS.md`, `CONTRIBUTIONS.md` e `RIGHTS.md`.
