# Plathink — subsistema Arduino da balança inteligente

[← Projetos Académicos](../README.md)

Versão curada do subsistema Arduino desenvolvido no projeto académico
**Plathink**, no contexto da unidade curricular Laboratório de Sistemas
Biomédicos.

**Equipa estudante, pela ordem dos materiais originais:** João Melo, João
Pedro Santos e Rita Portugal. **Orientação académica:** Pedro Guimarães, também
creditado como quarto coautor no relatório, na apresentação e no poster.

## Âmbito desta publicação

O projeto original demonstrou um protótipo integrado de monitorização
alimentar. Esta pasta **não contém o sistema completo**: os únicos ficheiros de
implementação preservados no arquivo atual são os do subsistema Arduino usado
com a célula de carga.

Por isso, esta pasta demonstra apenas:

- aquisição de peso com uma célula de carga e conversor HX711;
- tara e calibração interativas;
- persistência do fator de calibração em EEPROM;
- transmissão de leituras pela porta série;
- controlo dos LEDs verde e vermelho através de comandos recebidos por série.

Não estão aqui publicados o backend, a base de dados, a aplicação Web, o
modelo de visão computacional, a PCB ou os modelos 3D descritos na documentação
académica. A sua existência histórica não deve ser confundida com código-fonte
disponível nesta pasta.

No único repositório público de portefólio, apenas o conteúdo desta exportação
ocupará `Projetos Académicos/plathink/`. `publicacao/` não é uma raiz Git e
nenhum diretório `.git` deve ser criado ou copiado para essa pasta.

## Natureza e limites

Plathink foi um **protótipo académico**, não um dispositivo médico validado.
O firmware foi compilado para Arduino Uno, mas não foi revalidado nesta
preparação em hardware real. Não existem neste arquivo resultados quantitativos
suficientes para declarar precisão, repetibilidade ou adequação clínica.

## Estrutura

```text
plathink/
├── README.md
├── AUTHORS.md
├── ATTRIBUTION.md
├── RIGHTS.md
├── THIRD_PARTY_NOTICES.md
├── PUBLICATION_REVIEW.md
├── firmware/
│   └── plathink_scale/
│       └── plathink_scale.ino
└── tests/
    └── test_publication_contract.py
```

## Firmware de referência

`firmware/plathink_scale/plathink_scale.ino` foi selecionado a partir do sketch
arquivado `PesoCode/Peso/Peso.ino` porque é a versão mais recente que combina
pesagem, tara, calibração persistente e LEDs. Esta escolha baseia-se na estrutura
e data do arquivo; não prova que tenha sido exatamente o binário usado na
demonstração final.

Na cópia curada foi removido um bloco duplicado de leitura de peso e de estado
de tara, e foi normalizada a entrada série. Não foram alteradas as ligações, os
comandos ou o algoritmo de calibração.

## Hardware assumido pelo sketch

| Elemento | Ligação |
|---|---|
| HX711 DOUT | pino digital 7 |
| HX711 SCK | pino digital 6 |
| LED azul | pino digital 12; configurado como saída, mas não acionado nesta versão |
| LED verde | pino digital 11 |
| LED vermelho | pino digital 9 |
| Porta série | 57600 baud |

O arquivo académico refere Arduino Uno. Confirme a alimentação, resistências,
terra comum e especificações dos componentes antes de ligar o circuito.

## Instalação com Arduino IDE

1. Instalar o Arduino IDE 2.x.
2. No Library Manager, instalar `HX711_ADC`, versão 1.2.12.
3. Abrir `firmware/plathink_scale/plathink_scale.ino`.
4. Selecionar **Arduino Uno** e a porta correta.
5. Compilar e carregar o sketch.
6. Abrir o Serial Monitor com `57600 baud` e terminação de linha configurada.

## Instalação com Arduino CLI

```bash
arduino-cli core update-index
arduino-cli core install arduino:avr
arduino-cli lib install "HX711_ADC@1.2.12"
arduino-cli compile --fqbn arduino:avr:uno firmware/plathink_scale
arduino-cli upload --fqbn arduino:avr:uno --port PORTA firmware/plathink_scale
```

Substituir `PORTA` pelo identificador apresentado por `arduino-cli board list`.

## Utilização

Comandos aceites pela porta série:

| Comando | Ação |
|---|---|
| `t` | executar tara |
| `r` | iniciar calibração interativa |
| `w` | iniciar envio de peso |
| `s` | parar envio de peso |
| `g` | acender o LED verde no início da refeição |
| `cN` | definir um intervalo de mastigação de `N` segundos |

Durante a calibração, seguir as instruções no Serial Monitor. O fator só é
guardado na EEPROM se for dada confirmação explícita.

## Validação da preparação

```bash
python3 -m unittest discover -s tests -v
arduino-cli compile --fqbn arduino:avr:uno firmware/plathink_scale
```

O primeiro comando verifica a estrutura e exclusões. O segundo requer Arduino
CLI, o core AVR e `HX711_ADC`; é a validação de compilação recomendada antes da
publicação.

A cópia atual voltou a compilar em 2026-09-14 com Arduino CLI 1.4.1, Arduino
AVR Boards 1.8.8 e HX711_ADC 1.2.12: 9878 bytes de programa e 1168 bytes de
memória global num Arduino Uno. Não foi detetada uma placa ligada ao computador,
pelo que este resultado não substitui o ensaio do circuito real.

Por decisão de João Pedro Santos em 2026-09-14, esta primeira publicação segue
sem uma nova validação física. A compilação confirma apenas a compatibilidade do
firmware com o alvo; não confirma o funcionamento do circuito, a calibração, a
precisão ou a repetibilidade da balança.

## Autoria, dependências e publicação

- [`AUTHORS.md`](AUTHORS.md) preserva a natureza coletiva do trabalho.
- [`ATTRIBUTION.md`](ATTRIBUTION.md) regista a origem da cópia curada.
- [`RIGHTS.md`](RIGHTS.md) regista a autorização coletiva declarada para
  publicar, reserva os direitos e separa-os das licenças de terceiros.
- [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) identifica as dependências.
- [`PUBLICATION_REVIEW.md`](PUBLICATION_REVIEW.md) enumera os materiais excluídos,
  regista as verificações concluídas e identifica os controlos ainda necessários
  antes da integração e do primeiro `push` que inclua `plathink/`.

Segundo declaração de João Pedro Santos em 2026-09-11, os três elementos da
equipa estudante autorizaram a publicação pública do trabalho conjunto. Não foi
atribuída uma licença ao código; até uma decisão separada sobre reutilização,
todos os direitos estão reservados.
