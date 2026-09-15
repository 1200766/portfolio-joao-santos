# Revisão antes de publicação

## Confirmações antes da publicação

- [x] Consentimento de todos os elementos da equipa estudante para publicar o
      firmware e a descrição do projeto, segundo declaração de João Pedro
      Santos em 2026-09-11.
- [x] Identificar a equipa estudante e a respetiva ordem em `AUTHORS.md`:
      João Melo, João Pedro Santos e Rita Portugal; identificar separadamente
      Pedro Guimarães como orientador e quarto coautor dos materiais académicos.
- [x] Rever os direitos da instituição e do docente para o âmbito selecionado.
      Em 2026-09-15, João Pedro Santos confirmou que o Plathink foi um trabalho
      normal da unidade curricular, sem contrato, empresa parceira, bolsa,
      cessão de direitos ou utilização institucional excecional, e que Pedro
      Guimarães não escreveu o firmware. Como os materiais académicos de que o
      docente é coautor estão excluídos, não foi identificado um bloqueio
      adicional para esta exportação curada.
- [x] Manter todos os direitos reservados na primeira publicação, conforme
      `RIGHTS.md`. Uma licença aberta só poderá ser adotada posteriormente por
      acordo separado dos autores.
- [x] Compilar o firmware com Arduino Uno e HX711_ADC 1.2.12. Revalidado em
      2026-09-14 com Arduino CLI 1.4.1 e Arduino AVR Boards 1.8.8: 9878 bytes de
      programa e 1168 bytes de memória global.
- [x] Registar a decisão de publicar sem nova validação física. Em 2026-09-14
      João Pedro Santos decidiu fechar a preparação sem repetir o ensaio da
      tara, calibração, leitura, EEPROM, comandos série e LEDs. Não foi detetada
      qualquer placa Arduino ou porta USB série e não houve carregamento. O
      a pasta pública declara esta limitação e não apresenta resultados de precisão
      ou repetibilidade não verificados.
- [ ] Integrar apenas o conteúdo desta exportação em
      `Projetos Académicos/plathink/`, dentro do único repositório público de
      portefólio, sem `.git` aninhado, e rever o conjunto exato e o historial
      comum antes do primeiro `push` que a inclua.

## Inventário de exclusões

Esta versão não inclui:

- relatório, apresentação e poster originais, por conterem dados pessoais,
  propriedades internas e elementos ainda não sanitizados;
- vídeo da demonstração, por exigir revisão de imagem, voz, ecrãs e direitos,
  e por exceder o limite de tamanho de um ficheiro Git normal;
- backend Python, interface gráfica e integração série, que não foram
  encontrados no arquivo consolidado;
- aplicação Web e esquema MySQL, que não foram encontrados;
- treino, inferência, pesos, conjunto de dados e métricas do modelo de visão
  computacional, que não foram encontrados;
- fontes EasyEDA, Gerbers, BOM, diagramas elétricos, CAD e modelos 3D, que não
  foram encontrados;
- sketches intermédios, testes exploratórios e cópias locais de bibliotecas;
- caches, configuração de editores e ficheiros do sistema operativo.

Se algum material em falta for recuperado, deve passar por revisão própria;
não deve ser acrescentado automaticamente a esta pasta.
