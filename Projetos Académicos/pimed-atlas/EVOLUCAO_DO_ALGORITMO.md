# Evolução documentada da análise da artéria basilar

## Natureza desta nota

Esta nota foi reconstruída em 2026 a partir do código, dos resultados e dos
dois relatórios preservados no arquivo privado. Não é o relatório entregue na
unidade curricular, não completa retroativamente o rascunho coletivo e não
certifica os resultados originais.

## Partes que não devem ser confundidas

O projeto preservado contém três contextos relacionados:

1. uma primeira parte individual de segmentação manual;
2. a contribuição individual do João para *landmarks* e medidas vasculares,
   mais próxima da árvore `Algorítmos/Projeto2/`;
3. a evolução individual dessa contribuição, dedicada à análise da artéria
   basilar e preservada em `código/JonhyPeters/`.

João confirmou em 2026-09-11 que o código usado nos pontos 2 e 3 foi
desenvolvido exclusivamente por si no âmbito do projeto coletivo. A
reconstrução posterior também é individual, mas não deve ser apresentada como o
programa final originalmente submetido pelo grupo.

## Evolução preservada

### 1. Fatias segundo o eixo z

`BasilarInSlicesAxisZ.py` representa a abordagem inicial preservada. A artéria
basilar era analisada em fatias axiais com um voxel de espessura ao longo de
`z`. O relatório coletivo mostra, para uma fatia selecionada, valores extremos
e incompatíveis com uma interpretação física direta.

Esses valores justificam investigar a geometria e a forma de calcular as
métricas. Contudo, não demonstram uma regra universal segundo a qual qualquer
eixo do `EquivalentEllipsoidDiameter` teria obrigatoriamente de ser inferior ao
Feret. No ITK, o primeiro é derivado do volume e dos momentos principais; o
segundo corresponde à distância máxima entre pontos da fronteira. O elipsoide é
equivalente, não necessariamente inscrito na forma.

A causa mais plausível para os valores extremos é a aplicação de estatísticas
tridimensionais a uma estrutura degenerada com apenas um voxel de espessura,
combinada com as particularidades das métricas usadas.

### 2. Revisão orientada pelo esqueleto

`BasilarInSlicesSkeleton.py` é o último passo documentado desta linha de
desenvolvimento. O fluxo pretendido é:

1. isolar a etiqueta correspondente à artéria basilar;
2. aplicar um filtro de thinning tridimensional para obter um esqueleto;
3. usar pontos desse esqueleto para definir planos de corte;
4. extrair secções e calcular medidas por secção.

Esta revisão procura respeitar melhor a curvatura do vaso do que os planos
axiais fixos. Numa fatia selecionada, produziu valores aparentemente mais
plausíveis. Isso é evidência de uma revisão experimental, não de validação em
todos os conjuntos.

## Limitações confirmadas no código preservado

- `np.argwhere` devolve os pontos por ordem da matriz, não pela conectividade da
  linha central; pontos consecutivos podem não ser vizinhos anatómicos.
- Os planos podem, por isso, ser definidos por pares que não representam a
  direção local do vaso.
- A região extraída é uma caixa delimitadora entre dois pontos e pode não cobrir
  a secção transversal completa. O `vtkCutter` acaba por cortar a grelha dessa
  pequena região, não uma superfície explicitamente extraída do lúmen.
- O Feret é calculado em coordenadas de voxel, enquanto os valores chamados
  elipsoidais usam coordenadas físicas.
- O valor chamado `Ellipsoid Diameter` é calculado como duas vezes o desvio
  padrão; não é o `EquivalentEllipsoidDiameter` do ITK.
- O tratamento dos eixos no centróide não é consistente.
- A tabela nova do rascunho não corresponde à fatia indicada no texto; os
  valores coincidem com outro resultado preservado.
- Existem várias secções com Feret igual a zero.
- Os valores de Feret não nulos observados seguem distâncias discretas da grelha
  de voxels, outro sinal de que o método está a medir a região de amostragem e
  não uma secção vascular validada.
- Os outputs preservados são anteriores à última modificação dos scripts e não
  provam que o estado atual reproduza esses resultados.
- O `main.py` refatorado da árvore B tem uma chamada com número de argumentos
  incompatível com a função e uma via alternativa dependente de variáveis
  globais; não constitui um ponto de entrada executável no estado atual.
- O script autónomo tem datasets, identificadores e caminhos fixos, executa ao
  importar e exige um ambiente gráfico.

## Formulação pública defensável

> A orientação por esqueleto constituiu uma revisão experimental da abordagem
> axial e produziu medidas mais plausíveis numa secção selecionada. Os materiais
> preservados não demonstram validação geral, precisão clínica ou
> reprodutibilidade da implementação atual.

## Reconstrução pública implementada

A implementação em `src/pimed_atlas/` é uma reconstrução individual posterior,
separada em dois módulos: *landmarks*/contactos e análise da basilar. Esta
última seleciona uma componente 26-conexa, ordena a linha central por um caminho
geodésico no grafo do esqueleto, usa planos ortogonais a uma tangente local,
reamostra um campo de distância da máscara num plano 2D e calcula métricas com
unidades e nomes explícitos.

Os testes públicos usam apenas formas sintéticas conhecidas e cobrem
conectividade, unidades físicas, espaçamento anisotrópico, tubos direitos e
oblíquos, elipses, ramos e componentes desligadas. Uma execução posterior sobre
dados médicos autorizados poderá servir de verificação técnica adicional, mas
não de validação clínica.

A explicação consolidada encontra-se em `TECHNICAL_RECONSTRUCTION.md`.
