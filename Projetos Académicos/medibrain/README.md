# Estratégias automáticas de remoção de artefactos em EEG

[← Projetos Académicos](../README.md)

Versão curada do código desenvolvido num estágio curricular para comparar
estratégias automáticas de pré-processamento de EEG com Python e MNE.

Segundo declaração final de João Santos, todo o código deste projeto foi
construído por si. As bibliotecas, os modelos, os dados e os artigos de
terceiros continuam identificados separadamente e mantêm os seus próprios
direitos.

Esta pasta de projeto é um artefacto académico e de portefólio. Não é software
clínico, não produz diagnósticos e não foi validada para utilização assistencial.

## Objetivo e resultado

Foram analisadas quatro estratégias:

1. AutoReject;
2. ICA com ICLabel;
3. ICA com ICLabel, seguida de AutoReject;
4. AutoReject, seguido de ICA com ICLabel.

A avaliação original conjugou métricas associadas a artefactos oculares,
musculares e ruído de linha, inspeção temporal e espectral, Brain Symmetry
Index e tempo de execução. No conjunto reduzido estudado, ICA com ICLabel
apresentou o comportamento global mais consistente. AutoReject mostrou maior
utilidade como refinamento seletivo e as combinações híbridas produziram
resultados variáveis.

Estas conclusões descrevem apenas os registos analisados. Não existiu
*ground truth*, conjunto de teste independente ou validação clínica.

## Conteúdo

```text
.
├── README.md
├── AUTHORS.md
├── RIGHTS.md
├── PUBLICATION_REVIEW.md
├── relatório académico original (PDF)
├── requirements.txt
├── data/
│   └── README.md
├── scripts/
│   └── download_siena_pn00.py
├── src/
│   ├── AutoReject.py
│   ├── ICA_ICLabel.py
│   ├── ICA_ICLabel_AutoReject.py
│   └── AutoReject_ICA_ICLabel.py
└── tests/
    └── test_publication_contract.py
```

Os scripts são cópias curadas das experiências originais, mantidas separadas
para preservar a correspondência com as quatro abordagens. Ainda têm a forma
de scripts de investigação, e não de uma biblioteca ou aplicação de produção.
Foi concluída uma limpeza final limitada a duplicações literais, código morto,
comentários informais, variáveis sem utilização e formatação. Por decisão do
autor, a arquitetura e o comportamento histórico das pipelines foram
preservados, sem uma refatoração funcional.

## Código e EEG estão separados

Esta exportação destina-se a `Projetos Académicos/medibrain/`, dentro do único
repositório público de portefólio, e não deve conter uma raiz `.git` própria. O
historial Git conjunto guarda código e documentação; `data/` e `outputs/` são
ignorados.

- Nenhum registo de contexto clínico ou cuja autorização seja desconhecida
  integra esta versão.
- Os exemplos usam apenas ficheiros PN00 da Siena Scalp EEG Database, que podem
  ser descarregados diretamente da fonte pública.
- Os sinais, mesmo quando publicamente acessíveis, não devem ser adicionados ao
  historial Git. O script de descarga mantém a fonte e a licença explícitas.
- Resultados gerados localmente também não são versionados.
- A única exceção documental é o relatório académico original: esta exportação
  inclui uma cópia byte-for-byte, sem qualquer alteração. Esse
  PDF contém o nome do autor, o seu email institucional e figuras e resultados
  derivados dos exemplos EEG públicos descritos no próprio relatório. A
  inclusão consciente destes elementos foi decidida pelo próprio autor. Não são
  incluídos sinais EEG em bruto, e a revisão realizada não identificou no PDF
  resultados derivados dos dados privados excluídos da exportação.

## Dados públicos e citação

Os ficheiros PN00 pertencem à **Siena Scalp EEG Database**, versão 1.0.0,
disponível no PhysioNet sob a licença
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

Fonte: <https://physionet.org/content/siena-scalp-eeg/1.0.0/>

### Citações

- **Base de dados Siena:** Detti, P. (2020). *Siena Scalp EEG Database*
  (version 1.0.0). PhysioNet. <https://doi.org/10.13026/5d4a-j060>
- **Artigo original da base de dados:** Detti, P., Vatti, G., & Zabalo
  Manrique de Lara, G. (2020). EEG Synchronization Analysis for Seizure
  Prediction: A Study on Data of Noninvasive Recordings. *Processes, 8*(7),
  846. <https://doi.org/10.3390/pr8070846>
- **PhysioNet:** Pollard, T., Moody, B. E., Lehman, L., Gow, B., Fernandes, C.,
  Xie, C., Johnson, A., Mark, R. G., & Heldt, T. (2026). PhysioNet as a global
  platform for biomedical research. *Nature Health, 1*, 792–795.
  <https://doi.org/10.1038/s44360-026-00096-z>
- **ICLabel:** Pion-Tonachini, L., Kreutz-Delgado, K., & Makeig, S. (2019).
  ICLabel: An automated electroencephalographic independent component
  classifier, dataset, and website. *NeuroImage, 198*, 181–197.
  <https://doi.org/10.1016/j.neuroimage.2019.05.026>
- **MNE-ICALabel:** Li, A., Feitelberg, J., Saini, A. P., Höchenberger, R., &
  Scheltienne, M. (2022). MNE-ICALabel: Automatically annotating ICA
  components with ICLabel in Python. *Journal of Open Source Software, 7*(76),
  4484. <https://doi.org/10.21105/joss.04484>

A licença da base de dados não determina a licença deste código.

## Instalação

Ambiente validado para verificação estrutural: Python 3.12. Os processamentos
de EEG podem exigir bastante memória e tempo de CPU.

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

No Windows PowerShell, a ativação do ambiente é
`.venv\Scripts\Activate.ps1`.

## Obter os exemplos públicos

A partir de `Projetos Académicos/medibrain/` no repositório de portefólio:

```bash
python scripts/download_siena_pn00.py PN00-1 PN00-2 PN00-4
```

Os ficheiros são guardados em `data/`, fora do controlo de versões. A descarga
total ronda algumas centenas de megabytes.

## Execução

Executar sempre a partir da raiz da pasta deste projeto, porque os scripts usam
os caminhos relativos `data/` e `outputs/`:

```bash
python src/AutoReject.py
python src/ICA_ICLabel.py
python src/ICA_ICLabel_AutoReject.py
python src/AutoReject_ICA_ICLabel.py
```

Correspondência dos exemplos:

| Script | Registo público | Intervalo BSI utilizado |
|---|---|---|
| `AutoReject.py` | PN00-1 | pré-ictal 0–1142 s; ictal 1143–1213 s |
| `ICA_ICLabel.py` | PN00-4 | BSI desativado nesta cópia |
| `ICA_ICLabel_AutoReject.py` | PN00-4 | pré-ictal 0–1005 s; ictal 1006–1080 s |
| `AutoReject_ICA_ICLabel.py` | PN00-2 | pré-ictal 0–1219 s; ictal 1220–1274 s |

Os três scripts com ICA ou pipeline híbrida abrem janelas interativas do MNE
e aguardam `Enter` antes de gravar o sinal processado. As saídas são colocadas
em `outputs/` e permanecem locais.

## Correções aplicadas nesta cópia

- `AutoReject.py` deixou de combinar o *sample* MNE com intervalos PN00 e usa
  agora, de forma coerente, PN00-1.
- `ICA_ICLabel_AutoReject.py` usa os intervalos documentados para PN00-4.
- `AutoReject_ICA_ICLabel.py` guarda o resultado com o identificador PN00-2,
  correspondente ao ficheiro processado.
- O protótipo vazio `app.py`, variantes experimentais, caches, dados e resultados
  originais foram excluídos.

## Verificação local

```bash
python -m compileall -q src scripts tests
python -m unittest discover -s tests -v
```

Estes comandos verificam sintaxe e o contrato de sanitização. Não substituem
a reprodução integral das pipelines nem validação científica.

João Santos declara que as quatro abordagens foram testadas durante o estágio e
funcionavam no ambiente de desenvolvimento usado nessa altura. A execução
integral não foi repetida durante a preparação desta exportação pública. Por
isso, esta declaração é um registo histórico de funcionamento e não uma nova
validação dos resultados, uma garantia de compatibilidade atual ou uma promessa
de reprodução numérica idêntica.

## Relatório e apresentação

O relatório académico original está incluído como cópia byte-for-byte do PDF
preservado no arquivo privado. Não foi corrigido, sanitizado, recompilado nem
reexportado. O nome e o email institucional do autor, bem como as figuras e os
resultados derivados de exemplos EEG públicos que contém, permanecem no
documento por decisão explícita de João Santos.

A apresentação académica original permanece excluída da publicação.

## Publicação e direitos

Segundo declaração de João Santos em 2026-09-11, a Clínica MediBrain e o ISEP
autorizaram a partilha pública de todo o trabalho realizado e utilizado no
estágio sob a sua supervisão. João decidiu manter todos os direitos reservados;
não existe uma licença aberta. As decisões concluídas e os últimos passos
operacionais encontram-se em
[`PUBLICATION_REVIEW.md`](PUBLICATION_REVIEW.md). Aplicam-se os termos descritos
em [`RIGHTS.md`](RIGHTS.md); a autoria está registada separadamente em
[`AUTHORS.md`](AUTHORS.md).
