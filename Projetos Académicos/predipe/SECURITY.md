# Segurança e gestão de credenciais

## Rotação concluída antes da primeira publicação

Em 2026-09-11:

- os segredos do arquivo foram substituídos por placeholders;
- as chaves de API legadas `anon` e `service_role` foram desativadas;
- a chave de assinatura anterior Legacy HS256 foi revogada;
- a palavra-passe da base de dados foi substituída por um valor forte gerado
  pelo Supabase;
- foi confirmada a existência das chaves atuais `publishable` e `secret`;
- a pesquisa de segredos da exportação foi repetida com sucesso.

Nenhum valor novo foi guardado nesta exportação. Uma futura implantação deve
colocar a chave `secret` atual apenas no ambiente do backend, na variável
`SUPABASE_SECRET_KEY`. A chave `publishable` deve ser configurada em
`SUPABASE_PUBLISHABLE_KEY`. O código já não usa os nomes das chaves JWT legadas.

A antiga chave local do adaptador FHIR já foi eliminada. Não correspondia a uma
credencial emitida por um serviço externo: era um segredo partilhado definido no
próprio protótipo. A versão corrigida não tem fallback, fica desativada por
omissão e exige uma nova `FHIR_API_KEY` forte no ambiente quando a integração é
explicitamente ativada.

Nunca coloque valores reais em `.env.example`. O ficheiro `backend/.env` está ignorado por Git.
Os rótulos das chaves podem ser descritivos; os valores secretos e a
palavra-passe da base de dados devem ser aleatórios e únicos.

## Limites do protótipo

- uma chave `secret` privilegiada contorna RLS e exige um backend devidamente
  isolado;
- as rotas humanas verificam a pertença do paciente/gravidez, mas estes controlos ainda precisam de testes de integração contra Supabase;
- o SQL fornecido bloqueia acesso direto às novas tabelas para `anon` e
  `authenticated`; uma alternativa sem chave privilegiada exige políticas
  ligadas a `auth.uid()`;
- o adaptador FHIR usa uma chave partilhada e não implementa OAuth, mTLS ou validação FHIR;
- não existem evidências de gestão de incidentes, auditoria, encriptação operacional ou implantação endurecida.

Use apenas serviços descartáveis e dados sintéticos.
