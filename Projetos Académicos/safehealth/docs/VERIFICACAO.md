# Protocolo de verificação reproduzível

Uma execução completa da componente de software, realizada em 14 de setembro
de 2026, está registada em
[`RESULTADOS_TESTES_2026-09-14.md`](RESULTADOS_TESTES_2026-09-14.md). O ensaio
físico do firmware continua fora do âmbito dessa verificação.

## 1. Verificações estáticas

```bash
python3 scripts/check_publication.py
python3 -m unittest discover -s tests -v
find portal -name '*.php' -print0 | xargs -0 -n1 php -l
```

Resultado esperado: nenhum segredo ou artefacto excluído detetado e todos os ficheiros PHP sem erros de sintaxe.

## 2. Base de dados

Num MySQL descartável:

1. executar `database/criartabelas.sql`;
2. executar `database/inserts.sql`;
3. criar `database/passwords.local.sql` como descrito no README;
4. confirmar que existem exatamente um médico, um paciente, um administrador e um dispositivo fictícios.

## 3. Portal

1. carregar as variáveis de `.env`;
2. iniciar `php -S 127.0.0.1:8080 -t portal`;
3. autenticar os três perfis com a palavra-passe local;
4. confirmar que cada perfil só apresenta a interface prevista;
5. confirmar que um pedido sem sessão é rejeitado;
6. confirmar que mutações sem token CSRF, ou com token inválido, são rejeitadas;
7. confirmar que um médico não consegue consultar um paciente de outro médico e
   que um paciente não consegue trocar o seu identificador na URL;
8. testar criação, edição e remoção apenas sobre os dados descartáveis.

## 4. Endpoint de medição

Associar em `firmware/config.h` uma chave criada para a demonstração. O servidor
do portal deve ouvir no endereço da interface da LAN isolada e na mesma porta de
`SAFEHEALTH_SERVER_URL` (o exemplo usa `8080`). Enviar uma medição fictícia e
confirmar:

- resposta JSON de sucesso;
- nova linha em `medicoes`;
- seleção do alerta correspondente ao limiar;
- rejeição de uma chave desconhecida;
- rejeição de pedidos sem campos obrigatórios.

Confirmar também que a resposta não devolve a chave, o identificador ou o nome do
paciente e que o monitor série não imprime a chave nem o JSON enviado.

## 5. Firmware

1. compilar para a placa ESP32 escolhida;
2. testar primeiro sem pessoa, usando apenas diagnóstico de inicialização;
3. numa bancada e sem finalidade clínica, confirmar deteção dos sensores e ligação à rede isolada;
4. confirmar no monitor série o envio de uma sessão;
5. desligar a rede e confirmar que a falha é tratada sem bloquear indefinidamente.

Não testar em pacientes nem comparar estes valores com equipamento clínico como se constituíssem validação.
