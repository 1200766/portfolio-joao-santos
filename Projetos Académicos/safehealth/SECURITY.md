# Segurança e credenciais

## Estado das credenciais históricas

Os valores reais presentes no arquivo local e nas cópias ZIP foram substituídos
por placeholders. Em 14 de setembro de 2026, João confirmou também que a rede
Wi-Fi original e o backend com a respetiva base de dados tinham sido eliminados.
Não existe, portanto, um sistema ativo que possa continuar a aceitar a
palavra-passe ou a chave históricas, e este bloqueio de publicação está
encerrado.

Na mesma data, a pesquisa de segredos passou sem ocorrências e a rotação da
chave foi validada duas vezes numa base de dados descartável: a chave anterior
foi rejeitada e a nova foi aceite. Consulte
[`docs/RESULTADOS_TESTES_2026-09-14.md`](docs/RESULTADOS_TESTES_2026-09-14.md).

Se uma cópia antiga do backend ou da rede for algum dia restaurada, as
credenciais históricas devem continuar a ser tratadas como comprometidas e
substituídas antes de qualquer utilização. A pesquisa de segredos deve ser
repetida sobre o conteúdo exato copiado desta exportação para
`Projetos Académicos/safehealth/` no único repositório público de portefólio,
antes do primeiro `push` que a inclua. A exportação não é uma raiz Git e não
deve transportar um `.git` aninhado.

`firmware/config.h`, `.env` e `database/passwords.local.sql` estão ignorados por Git.

## Proteções incluídas nesta exportação

- cookies de sessão `HttpOnly` e `SameSite=Strict`, regeneração do identificador
  após autenticação e verificação de perfil nas páginas e endpoints;
- verificação de pertença antes de um médico ou paciente consultar medições;
- token CSRF nas mutações do portal e consultas parametrizadas nos handlers;
- chaves de dispositivo ocultadas nas respostas e na interface;
- firmware sem impressão da chave ou do conteúdo JSON no monitor série;
- limites básicos de tamanho e intervalo numérico no endpoint de ingestão.

Estas medidas tornam a demonstração menos perigosa, mas não equivalem a uma
auditoria ou a uma implementação pronta para produção.

## Modelo de ameaça reduzido

A chave do dispositivo identifica a origem, mas não oferece confidencialidade e não é uma prova forte de identidade. Em HTTP, qualquer participante com visibilidade sobre a rede pode observar ou alterar medições e a chave. Uma evolução segura exigiria TLS, gestão de certificados/chaves, proteção contra repetição, limites de pedidos e autenticação de dispositivos.

O endpoint do dispositivo não tem proteção contra repetição, rate limiting nem
TLS, e a chave partilhada não deve ser tratada como autenticação forte. O portal
também não foi sujeito a auditoria completa. Todo o conjunto deve permanecer
inacessível a partir da Internet e ser usado apenas com dados fictícios numa rede
laboratorial isolada.
