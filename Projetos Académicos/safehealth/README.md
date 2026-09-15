# SafeHealth

[← Projetos Académicos](../README.md)

Protótipo académico de monitorização remota que liga um ESP32, sensores MAX30102 e DS18B20, um endpoint PHP/MySQL e um portal com perfis de administrador, médico e paciente.

> **Demonstração não clínica.** O sistema não é um dispositivo médico, não foi validado para medir sinais vitais e não deve ser usado com pacientes, dados reais ou decisões de saúde.

## Estado

Esta pasta foi construída apenas a partir do pacote académico final. Configurações reais foram substituídas por placeholders, os dados SQL foram reduzidos a registos inequivocamente fictícios e os ficheiros de ambiente local foram excluídos. Em 14 de setembro de 2026, a integração entre o portal, o endpoint e uma base de dados descartável foi verificada com sucesso; consulte [`docs/RESULTADOS_TESTES_2026-09-14.md`](docs/RESULTADOS_TESTES_2026-09-14.md).

Em 14 de setembro de 2026, João confirmou que a rede Wi-Fi original e o backend com a respetiva base de dados já tinham sido eliminados. As credenciais históricas deixaram, por isso, de ter um sistema ativo onde pudessem ser aceites, e o bloqueio de segurança associado ficou encerrado. Segundo declaração de João Santos em 2026-09-11, ambos os autores já autorizaram a publicação pública do trabalho conjunto. Esta autorização não concede uma licença aberta. Consulte `SECURITY.md`, `AUTHORS.md` e `RIGHTS.md`.

## Arquitetura

```text
MAX30102 + DS18B20
          |
         ESP32
          |
  HTTP/JSON em rede local
          |
    PHP + MySQL
          |
portal administrador / médico / paciente
```

O firmware recolhe valores, calcula estatísticas da sessão e envia JSON associado a uma chave de dispositivo. O backend valida a associação, regista a medição e aplica limiares demonstrativos para selecionar um alerta.

## Estrutura

- `firmware/` — sketch Arduino e configuração de exemplo;
- `portal/` — portal PHP e endpoints;
- `database/` — esquema e dados fictícios mínimos;
- `docs/` — protocolo, arquitetura, limitações e inventário;
- `scripts/` — verificações estáticas da exportação.

## Requisitos

- PHP 8 com extensões `mysqli` e `pdo_mysql`;
- MySQL ou MariaDB;
- Arduino IDE ou `arduino-cli`;
- placa ESP32;
- bibliotecas SparkFun MAX3010x, OneWire e DallasTemperature.

## Configurar a base de dados

```bash
mysql -u root -p < database/criartabelas.sql
mysql -u root -p < database/inserts.sql
cp database/passwords.example.sql database/passwords.local.sql
php -r 'echo password_hash("escolha-uma-password-local", PASSWORD_DEFAULT), PHP_EOL;'
```

Substitua `YOUR_PASSWORD_HASH` em `passwords.local.sql` pelo hash acabado de gerar e execute o ficheiro local. Não publique a palavra-passe escolhida.

Configure as variáveis do portal:

```bash
cp .env.example .env
set -a
source .env
set +a
php -S 127.0.0.1:8080 -t portal
```

O ficheiro `.env` fica ignorado por Git. Este comando serve para testar apenas o
portal na própria máquina: um ESP32 não consegue alcançar `127.0.0.1` noutro
equipamento.

## Configurar o ESP32

```bash
cp firmware/config.example.h firmware/config.h
```

Preencha `config.h` com uma rede laboratorial e uma chave criada apenas para a
demonstração. O exemplo inclui a porta `8080`. `YOUR_BACKEND_HOST` deve ser o
endereço local da máquina PHP visto pelo ESP32; `localhost` apontaria para o
próprio microcontrolador.

Para um ensaio fim a fim, inicie o servidor PHP no endereço dessa interface de
rede (por exemplo, `php -S 0.0.0.0:8080 -t portal`) apenas numa LAN laboratorial
isolada e protegida por firewall. Esse comando torna o protótipo alcançável na
rede; nunca o exponha à Internet nem o utilize com pessoas ou dados reais.

## Verificação

Siga [`docs/VERIFICACAO.md`](docs/VERIFICACAO.md). Os resultados da execução
de 14 de setembro de 2026 estão em
[`docs/RESULTADOS_TESTES_2026-09-14.md`](docs/RESULTADOS_TESTES_2026-09-14.md).
Para repetir as verificações que não exigem hardware:

```bash
python3 scripts/check_publication.py
python3 -m unittest discover -s tests -v
find portal -name '*.php' -print0 | xargs -0 -n1 php -l
```

## Limitações essenciais

- comunicação ESP32–backend por HTTP sem TLS;
- chave de dispositivo partilhada, sem mTLS nem rotação automática;
- limiares de alerta demonstrativos e não validados;
- medições dependentes de sensores e algoritmos sem validação clínica;
- o portal inclui uma barreira mínima de sessão, perfis, pertença e CSRF, mas não
  recebeu auditoria de segurança e não constitui uma arquitetura de produção;
- o endpoint do ESP32 continua a depender de uma chave partilhada por HTTP e não
  tem proteção contra repetição nem limitação de pedidos;
- nenhuma demonstração de conformidade regulamentar ou de disponibilidade clínica.

O endpoint legado `add_paciente.php` permanece apenas para devolver HTTP 410. A
criação e edição usam `save_paciente.php`, com sessão de administrador, CSRF e
consultas preparadas.

Use apenas uma rede isolada, serviços descartáveis e os dados fictícios fornecidos.

## Autoria e direitos

Consulte `AUTHORS.md`, `CONTRIBUTIONS.md` e `RIGHTS.md`.
