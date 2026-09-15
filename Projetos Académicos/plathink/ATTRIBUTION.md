# Atribuição e proveniência

## Projeto

O firmware foi desenvolvido no âmbito do projeto académico coletivo Plathink,
na unidade curricular Laboratório de Sistemas Biomédicos.

## Origem da versão curada

O sketch publicado deriva do ficheiro de arquivo
`Código/Arduino/PesoCode/Peso/Peso.ino`. Foi escolhido por ser a variante mais
recente do arquivo que reúne leitura da célula de carga, tara, calibração,
persistência em EEPROM e controlo de LEDs.

Alteração efetuada na preparação pública:

- remoção de um segundo bloco idêntico de leitura de peso e notificação de
  conclusão da tara dentro de `loop()`;
- normalização de espaços e terminações de linha nos comandos recebidos pela
  porta série.

Não foram copiadas bibliotecas de terceiros para esta pasta. São instaladas
separadamente conforme o README.
