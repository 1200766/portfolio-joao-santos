# Inventário do material excluído

## Dados e materiais da universidade

Foram excluídos da exportação:

- todos os volumes `*_matched.vtk` e `*_MAN_labels.vtk`;
- meshes, skeletons, mapas de espessura e outros volumes VTK derivados;
- ficheiros de sessão ITK-SNAP;
- a descrição ou enunciado do projeto em PDF;
- diretórios de datasets e cópias colocadas nas pastas individuais.

O motivo é a ausência de autorização documentada para redistribuir os dados e
materiais fornecidos pela universidade, além da dimensão dos volumes.

## Relatórios preservados apenas no arquivo privado

Foram localizados dois PDFs. Por decisão do João em 2026-09-11, ambos ficam
definitivamente excluídos do futuro repositório público:

- o relatório individual da primeira parte está visualmente completo, mas não
  corresponde integralmente às fontes LaTeX e estatísticas hoje preservadas;
- o relatório coletivo da segunda parte é um rascunho incompleto com
  identificadores, lacunas editoriais e referências por corrigir.

Os documentos incluem imagens médicas, resultados derivados e identificadores
académicos. A exportação contém apenas uma reconstrução técnica sanitizada em
`EVOLUCAO_DO_ALGORITMO.md`; não tenta completar os PDFs retroativamente.

## Templates e artefactos incompletos

- `Primeira Parte do Projeto/<ID>_<CASO_A>/python/Welcome.py` é um template com
  valores de exemplo e marcações `TODO`, não código final;
- `Primeira Parte do Projeto/<ID>_<CASO_A>/results/Welcome.dat` é o respetivo
  resultado-modelo;
- `Segunda Parte do Projeto/joao/código/output/results/<ID>_SBasilar_Measures.dat`
  tem zero bytes e não constitui evidência de execução concluída;
- caches `__pycache__/`, bytecode e `.DS_Store` são artefactos locais gerados.

## Duplicados identificados

As igualdades abaixo foram confirmadas por SHA-256. Os caminhos são relativos à
raiz privada do projeto.

- `<CASO_A>_matched.vtk` é idêntico em seis locais:
  `Primeira Parte do Projeto/<ID>_<CASO_A>/brain/`,
  `Segunda Parte do Projeto/datasets/`, `<COLEGA_A>/input/`,
  `<COLEGA_B>/Algorítmos/input/`, `<AUTOR>/Algorítmos/input/` e
  `<AUTOR>/código/input/`;
- `<CASO_A>_MAN_labels.vtk` é idêntico em seis locais:
  `Primeira Parte do Projeto/<ID>_<CASO_A>/itksnap/`,
  `Segunda Parte do Projeto/datasets/`, `<COLEGA_A>/input/`,
  `<COLEGA_B>/Algorítmos/input/`, `<AUTOR>/Algorítmos/input/` e
  `<AUTOR>/código/input/`;
- `<CASO_B>_matched.vtk` e `<CASO_B>_MAN_labels.vtk` têm, cada um, três cópias
  idênticas em `Segunda Parte do Projeto/datasets/`, `<COLEGA_A>/input/` e
  `<AUTOR>/código/input/`;
- `<CASO_C>_matched.vtk` e `<CASO_C>_MAN_labels.vtk` têm, cada um, três cópias
  idênticas nesses mesmos diretórios;
- `Segunda Parte do Projeto/<AUTOR>/código/output/results/<CASO_A>_etiqueta_8_skeleton.vtk`
  é idêntico a
  `Segunda Parte do Projeto/<AUTOR>/código/output/vtk/<ID>_BasilarSkeleton.vtk`;
- `Segunda Parte do Projeto/<COLEGA_B>/Algorítmos/output/results/<ID>_<CASO_A>_All_Landmarks.dat`
  é idêntico a
  `Segunda Parte do Projeto/<AUTOR>/Algorítmos/output/results/<ID>_<CASO_A>_All_Landmarks.dat`;
- em `Segunda Parte do Projeto/<AUTOR>/código/output/results/`, os pares
  `<ID_A>_Slice8Statistics.dat`/`<ID_B>_Slice8Statistics.dat`,
  `<ID_A>_Slice8Tortuosidade.dat`/`<ID_B>_Slice8Tortuosidade.dat` e
  `<ID_A>_Slice8Centroids.dat`/`<ID_B>_Slice8Centroids.dat` têm conteúdo
  idêntico apesar dos identificadores académicos diferentes;
- `<COLEGA_B>/Algorítmos/Projeto2/__pycache__/my_functions.cpython-312.pyc` e
  `<AUTOR>/Algorítmos/Projeto2/__pycache__/my_functions.cpython-312.pyc` são o
  mesmo bytecode; os respetivos `.DS_Store` também são idênticos.

Estes duplicados foram mantidos no arquivo original. A exportação não escolhe um
exemplar porque, sem proveniência e versão final confirmadas, a igualdade de
conteúdo não demonstra qual é o original nem quem o produziu.

## Código histórico não promovido

Os ficheiros originais das duas árvores descritas em
`ARVORES_DE_CODIGO.md` ficaram fora da exportação. Segundo confirmação do João,
esse código era a sua contribuição individual para o projeto coletivo, mas o
estado preservado não forma um programa final reprodutível e contém os problemas
técnicos documentados em `TECHNICAL_RECONSTRUCTION.md`.

Em vez de copiar esses ficheiros, a exportação inclui uma implementação nova em
`src/pimed_atlas/`, igualmente individual, que conserva a intenção técnica das
duas componentes e torna explícitas as correções. Os scripts auxiliares, demos,
interfaces gráficas e testes históricos continuam excluídos por não existir um
manifesto que demonstre quais integraram a entrega final.
