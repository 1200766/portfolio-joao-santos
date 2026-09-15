# Arquitetura e fluxo

1. O MAX30102 fornece sinais óticos usados pelo protótipo para estimar frequência cardíaca e SpO2.
2. O DS18B20 fornece temperatura.
3. O ESP32 agrega amostras, calcula estatísticas e envia JSON por HTTP.
4. O endpoint associa a chave do dispositivo a um paciente fictício.
5. A medição é guardada em MySQL e comparada com limiares académicos.
6. O portal apresenta medições e alertas por perfil.

Esta cadeia prova apenas integração técnica em laboratório. Não demonstra exatidão metrológica, eficácia clínica, segurança funcional, interoperabilidade normalizada, disponibilidade ou conformidade como dispositivo médico.

## Fronteiras de confiança

- sensor–firmware;
- ESP32–rede Wi-Fi;
- rede–endpoint PHP;
- endpoint–base de dados;
- sessão web–dados por perfil.

A exportação conserva as limitações do protótipo, nomeadamente HTTP sem TLS e autenticação de dispositivo por chave partilhada. Deve ser executada apenas num ambiente isolado.
