# PIMED/ATLAS — reconstrução técnica individual

[← Projetos Académicos](../README.md)

Esta pasta contém uma reconstrução pública e executável da contribuição de
código que João Santos desenvolveu individualmente dentro do projeto académico
coletivo ATLAS.

O código histórico tinha erros de implementação e problemas de
reprodutibilidade. Em vez de os esconder ou publicar as duas árvores como se
fossem uma versão final, João decidiu corrigi-los posteriormente. A proveniência,
os problemas confirmados e cada decisão técnica estão explicados em
`TECHNICAL_RECONSTRUCTION.md`.

Esta reconstrução de 2026 é trabalho individual do João. Não é apresentada como
a submissão original do grupo.

## O que está implementado

- `core`: volumes, geometria física, transformação entre índices `zyx` e
  coordenadas físicas `xyz`, leitura NPZ e leitura opcional de VTK legado;
- `landmarks`: componentes 26-conexas, centróides, lateralidade apenas com uma
  convenção explícita, distâncias, ângulos e proximidade entre superfícies;
- `basilar`: seleção da componente, esqueleto, grafo físico, percurso ordenado,
  tangentes locais, secções ortogonais e métricas 2D em milímetros;
- `pipelines` e `pimed-atlas`: execução de alto nível, validação das entradas e
  resultados JSON sem acrescentar caminhos, identificadores de casos ou voxels
  brutos;
- `tests`: testes automáticos exclusivamente com volumes sintéticos.

Não foram copiados em bloco os scripts históricos. Foram preservadas a intenção
e a evolução técnica da contribuição individual, substituindo as operações que
produziam resultados incorretos ou ambíguos.

## Instalação rápida

É necessário Python 3.11 ou superior. O ambiente limpo de referência usa Python
3.12.3.

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install .
```

Para também ler os volumes `.vtk` legados:

```bash
python -m pip install '.[vtk]'
```

Em Windows PowerShell, a ativação do ambiente é
`.venv\Scripts\Activate.ps1`.

## Experimentar sem dados médicos

O exemplo incluído gera uma geometria vascular e labels inteiramente sintéticas:

```bash
mkdir -p output

pimed-atlas generate-synthetic \
  --volume-output output/example-volume.npz \
  --schema-output output/example-landmarks.json

pimed-atlas analyse-landmarks \
  --input output/example-volume.npz \
  --schema output/example-landmarks.json \
  --output output/landmarks-result.json

pimed-atlas analyse-basilar \
  --input output/example-volume.npz \
  --label 8 \
  --allow-automatic-exploratory \
  --output output/basilar-result.json
```

Os comandos não substituem ficheiros existentes por omissão. Para repetir um
exemplo usando os mesmos nomes de saída, acrescente `--overwrite` ao comando
correspondente.

`output/` é ignorada pelo Git. Volumes autorizados e resultados derivados de
dados reais devem permanecer numa pasta privada fora desta árvore pública; não
os mova para o repositório depois da análise.

O modo automático dos extremos exige uma aceitação explícita e é apenas
exploratório; o exemplo sintético é o único uso recomendado. Em volumes reais
ou autorizados, a linha central deve receber duas âncoras físicas; consultar
`COMO_REPRODUZIR.md`.

Os nomes das labels e o sistema de coordenadas escritos pelo utilizador no
esquema são repetidos no resultado. Devem, por isso, ser revistos antes de
partilhar um JSON obtido com dados reais. Num VTK legado, a orientação não vem
codificada e é assumida como identidade; uma interpretação LPS/RAS tem de ser
confirmada externamente.

## Testes

```bash
python -m unittest discover -s tests -p 'test*.py' -v
```

Os testes verificam a geometria e serialização, os landmarks, os contactos, a
linha central, tubos sintéticos direitos, oblíquos e curvos em 3D, os cortes
ortogonais, as métricas, os pipelines, a CLI e, quando a dependência opcional
está instalada, o adaptador VTK.

## Estrutura

```text
publicacao/
├── src/pimed_atlas/
│   ├── core/
│   ├── landmarks/
│   ├── basilar/
│   ├── pipelines.py
│   └── cli.py
├── examples/
├── tests/
├── pyproject.toml
├── requirements.txt
├── requirements-vtk.txt
├── TECHNICAL_RECONSTRUCTION.md
├── EVOLUCAO_DO_ALGORITMO.md
├── ARVORES_DE_CODIGO.md
├── CONTRIBUTIONS.md
├── INVENTARIO_EXCLUIDO.md
└── RIGHTS.md
```

## O que ficou fora

Por decisão expressa do João, os dois relatórios académicos não são publicados.
Também ficam fora todos os volumes médicos, segmentações, sessões ITK-SNAP,
resultados derivados, capturas, enunciados, identificadores e árvores históricas
completas. O inventário encontra-se em `INVENTARIO_EXCLUIDO.md`.

## Limites conhecidos

Esta é uma prova de conceito académica validada apenas com dados sintéticos. Não
é um dispositivo médico e não deve ser usada para diagnóstico, tratamento ou
decisões clínicas.

A esqueletização ainda depende da grelha de voxels; volumes muito anisotrópicos
devem ser reamostrados ou analisados com cautela. As coordenadas `uv` dos
centróides são locais a cada plano e não devem ser comparadas como uma orientação
contínua ao longo do vaso. O Feret é estimado a partir do casco dos píxeis da
secção e a sua incerteza depende da resolução de amostragem.

A ausência de uma licença aberta significa que os direitos permanecem
reservados. Consultar `RIGHTS.md`.
