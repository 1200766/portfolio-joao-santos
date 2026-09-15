# Resultados da verificação de software — 14 de setembro de 2026

Esta verificação incidiu sobre a exportação pública do SafeHealth e foi
executada exclusivamente com dados fictícios, credenciais efémeras e serviços
locais descartáveis. Nenhum valor usado durante o ensaio foi guardado no
projeto.

## Ambiente

- Python 3.12;
- PHP 8.2.4, com `mysqli`, `PDO` e `pdo_mysql`;
- MariaDB 10.4.28;
- servidor PHP e base de dados acessíveis apenas em `127.0.0.1` durante o
  ensaio.

## Resultados

- pesquisa estática de segredos e artefactos excluídos: **aprovada, sem
  ocorrências**;
- testes Python de segurança da publicação: **4/4 aprovados**;
- verificação de sintaxe PHP: **29/29 ficheiros aprovados**;
- esquema e dados fictícios carregados numa base de dados descartável;
- estado inicial confirmado: um médico, um paciente, um administrador, um
  dispositivo, 17 alertas e uma medição;
- endpoint de ingestão: **11 verificações HTTP aprovadas**, cobrindo método
  incorreto, JSON inválido, campo obrigatório em falta, chave desconhecida,
  limites numéricos, sucesso, dispositivo inativo e rotação da chave;
- portal: **17 verificações aprovadas**, cobrindo autenticação dos três
  perfis, rejeição de token de autenticação inválido, separação de
  páginas e dados, pedidos sem sessão e proteção CSRF;
- a rotação da chave do dispositivo foi repetida duas vezes: em ambos os
  casos a chave anterior passou a ser rejeitada com HTTP 404 e a nova foi
  aceite com HTTP 200;
- as respostas verificadas não devolveram a chave do dispositivo nem o
  identificador ou nome do paciente;
- no fim, as quatro medições existentes estavam completas e associadas a um
  alerta.

O servidor, a base de dados, as credenciais efémeras e os restantes ficheiros
temporários foram encerrados e removidos no final do ensaio.

## Limites desta verificação

- o firmware não foi compilado e não houve ensaio físico com ESP32 ou sensores;
- a palavra-passe da rede Wi-Fi original não foi alterada neste ensaio;
- a rotação foi demonstrada numa base de dados descartável e não prova a
  invalidação da chave num eventual backend antigo ainda existente.

No momento em que o ensaio terminou, a integração de software estava verificada,
mas ainda faltava confirmar externamente o estado da rede e de qualquer
instalação antiga do backend.

## Confirmação externa posterior

Depois da execução destes testes, em 14 de setembro de 2026, João confirmou que
a rede Wi-Fi original e o backend com a respetiva base de dados já tinham sido
eliminados. Essa declaração encerra o bloqueio externo: as credenciais
históricas já não têm um sistema ativo onde possam ser validadas.
