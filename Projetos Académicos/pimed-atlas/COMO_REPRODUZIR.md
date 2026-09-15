# Instalação e reprodução

## 1. Criar o ambiente

A reconstrução requer Python 3.11 ou superior. Foi verificada num ambiente limpo
com Python 3.12.3.

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install .
```

Para reproduzir exatamente as versões diretas usadas na verificação:

```bash
python -m pip install -r requirements.txt
python -m pip install . --no-deps
```

A leitura de `.vtk` é opcional porque o pacote público usa `.npz` nos exemplos:

```bash
python -m pip install -r requirements-vtk.txt
python -m pip install . --no-deps
```

No Windows PowerShell, a ativação é `.venv\Scripts\Activate.ps1`.

## 2. Confirmar a instalação

```bash
pimed-atlas --help
python -m unittest discover -s tests -p 'test*.py' -v
```

Sem VTK instalado, o teste exclusivo desse adaptador é ignorado; os restantes
testes continuam disponíveis.

## 3. Executar o exemplo público

O exemplo é totalmente sintético e pode ser criado sem qualquer material do
arquivo académico:

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

Os dois últimos comandos escrevem JSON estruturado. Não incluem o caminho do
volume, o identificador interno do caso nem os voxels originais. Os resultados
derivados de um exame real podem, mesmo assim, ser sensíveis e não devem ser
publicados automaticamente. Os nomes das labels e o sistema de coordenadas
fornecidos no esquema são reproduzidos no JSON e também exigem revisão.

Por segurança, nenhum comando substitui uma saída existente. Ao repetir uma
execução com os mesmos nomes, use `--overwrite` apenas depois de confirmar que
pretende substituir esses ficheiros.

A pasta `output/` e os volumes `.npz` são ignorados pelo Git. Num caso real,
prefira ainda uma pasta privada fora desta árvore: um NPZ contém os voxels e o
identificador interno do volume, e os JSON contêm resultados derivados que
podem continuar a ser sensíveis.

## 4. Formato do volume

São aceites:

- `.npz`, no formato explícito criado por `save_npz_volume`;
- `.vtk` legado, quando a dependência opcional VTK está instalada.

Os arrays usam a ordem `z, y, x`. A origem e os pontos físicos usam
`x, y, z`, em milímetros. A geometria inclui espaçamento e uma matriz de
direção ortonormal.

O formato VTK legado não guarda uma matriz de direção. O adaptador assume a
identidade e assinala essa proveniência no resumo da entrada. Antes de atribuir
lateralidade LPS/RAS, a orientação tem de ser confirmada por uma fonte externa.

O volume deve ser uma imagem de labels inteiras. O utilizador escolhe
explicitamente o significado de cada label; o programa não presume que um
número tem sempre a mesma anatomia.

## 5. Configurar landmarks

`analyse-landmarks` exige um esquema JSON. O exemplo completo encontra-se em
`examples/landmark_schema.synthetic.json`. A estrutura mínima é:

```json
{
  "schema_version": 1,
  "labels": [
    {
      "value": 1,
      "name": "nome_definido_pelo_utilizador",
      "expected_components": 2,
      "min_voxels": 5
    }
  ],
  "laterality": [],
  "contacts": []
}
```

A lateralidade só é calculada quando o esquema declara o sistema de coordenadas,
o eixo, o sentido positivo, a linha média e a tolerância. Os contactos usam uma
distância-limite em milímetros entre centros de voxels da superfície. Trata-se
de uma medida discreta de proximidade: voxels adjacentes continuam separados
por um espaçamento e a contagem de pares não representa área de contacto.

`min_voxels` também depende da resolução. Ao comparar volumes com espaçamentos
diferentes, o limite deve ser recalculado a partir do volume físico pretendido.

## 6. Analisar a basilar num volume autorizado

Pela política deste projeto, fora do exemplo sintético devem ser usadas duas
âncoras físicas distintas, normalmente obtidas a partir de B4 e B3. A ordem dos
argumentos é sempre `X Y Z`, em milímetros:

```bash
pimed-atlas analyse-basilar \
  --input volume-autorizado.vtk \
  --label 8 \
  --start-anchor-mm X_INICIAL Y_INICIAL Z_INICIAL \
  --end-anchor-mm X_FINAL Y_FINAL Z_FINAL \
  --maximum-anchor-distance-mm 5 \
  --output /caminho/privado/resultado-privado.json
```

A pipeline converte as âncoras para índices contínuos, associa cada uma ao nó
mais próximo do esqueleto, regista a distância dessa associação e termina com
erro se ultrapassar o limite ou se ambas convergirem para o mesmo nó.

A CLI não consegue provar a origem sintética de um ficheiro e, por isso, aceita
tecnicamente `--allow-automatic-exploratory` quando o utilizador o declara. Esse
modo escolhe extremos automaticamente, emite avisos e não deve ser usado como
substituto das âncoras num volume real.

Se a mesma label tiver várias componentes desligadas, pode selecionar
explicitamente uma delas com `--component-seed Z Y X`. Esta opção usa índices
inteiros e não coordenadas físicas.

Por omissão, a execução recusa uma razão de anisotropia de voxel superior a
3:1. `--allow-high-anisotropy` permite uma execução exploratória e regista um
aviso no resultado, mas não corrige a dependência da esqueletização em relação à
grelha. A opção deve ser usada apenas depois de rever ou reamostrar o volume.

Use `--sampling-mm` para controlar a resolução das secções,
`--half-extent-mm` para o campo de visão e `--section-stride` para o intervalo
entre nós analisados. O programa recusa uma máscara que toque no limite do
volume, porque isso indicaria uma secção truncada; deve ser acrescentado fundo
em redor da componente antes da análise.

As opções avançadas `--endpoint-margin` e `--tangent-window` controlam,
respetivamente, quantos nós das extremidades são omitidos e a vizinhança usada
para estimar cada tangente. `--maximum-anisotropy-ratio` permite tornar o limite
de anisotropia mais restritivo; aumentar esse limite não corrige a dependência
da esqueletização em relação à grelha.

## 7. O que é e não é reproduzido

A execução acima reproduz a reconstrução individual posterior de 2026. Não
reproduz a entrega académica original nem os resultados dos scripts históricos.

As árvores antigas continuam apenas no arquivo privado. Tinham interfaces
gráficas, caminhos e identificadores fixos, dependências incompatíveis e os
erros descritos em `TECHNICAL_RECONSTRUCTION.md`. Os relatórios, volumes,
segmentações e resultados médicos também permanecem fora deste pacote.
