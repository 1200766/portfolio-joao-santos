# Árvores de código avaliadas

## Árvore A

**Localização:**
`Segunda Parte do Projeto/joao/Algorítmos/Projeto2/`

**Ficheiros principais:**

- `main.py`;
- `my_functions.py`.

Segundo confirmação expressa de João Santos em 2026-09-11, o código selecionado
das duas árvores foi desenvolvido exclusivamente por si como contribuição
individual para o projeto coletivo.

O `main.py` abre seletores PyQt para dois volumes VTK e encadeia funções de
landmarks, bifurcações, distâncias, contactos, AICAs e medidas. É a árvore mais
próxima de um fluxo integrado, mas contém:

- um identificador fixo pertencente a outro elemento do grupo;
- nomes de ficheiros de saída que ainda incluem marcas de teste;
- saídas relativas a `../output/`, cuja estrutura tem de existir previamente;
- bytecode de versões diferentes de Python, que não serve como fonte nem como
  prova da versão final;
- ausência de README, testes, versões de dependências e registo de execução.

Esta árvore não é uma alternativa completa à árvore B. O seu `main.py` executa
o fluxo de landmarks, contactos e medidas, mas não chama o bloco de funções da
basilar acrescentado no final de `my_functions.py`.

## Árvore B

**Localização:**
`Segunda Parte do Projeto/joao/código/JonhyPeters/`

**Ficheiros principais:**

- `main.py`;
- `my_Functions.py`;
- vários scripts auxiliares para landmarks, artéria basilar, bifurcação,
  regiões/pontos de contacto, skeletonização, dimensões, demonstração e testes.

O `main.py` executa uma análise da artéria basilar a partir de caminhos relativos
a `../input/` e escreve em `../output/results/` e `../output/vtk/`. Esta árvore
tem ficheiros modificados ligeiramente mais tarde, mas contém:

- um identificador e um dataset fixos que não correspondem à identificação do
  João, com alternativas apenas comentadas;
- vários scripts exploratórios, de demonstração ou de teste sem indicação dos
  que integraram a entrega;
- caminhos e diretórios de saída assumidos;
- ausência de README, testes, versões de dependências e registo de execução.

O `main.py` desta árvore também não funciona no estado preservado: a chamada da
via de uma única basilar fornece menos argumentos do que a respetiva função
exige, e a via alternativa depende de variáveis globais que não são definidas no
módulo. O script autónomo `BasilarInSlicesSkeleton.py` repõe essas variáveis e
chamadas, mas executa imediatamente ao importar, depende de diretórios e volumes
privados e abre componentes gráficos.

## Decisão de promoção

As árvores não são copiadas integralmente para `publicacao/`. A revisão permite
distinguir duas funções dentro da contribuição individual do João:

- a árvore A é a referência preservada mais próxima do fluxo de *landmarks*;
- na árvore B, a sequência `BasilarInSlicesAxisZ.py` →
  `BasilarInSlices.py` → `BasilarInSlicesSkeleton.py` documenta a evolução da
  subcomponente da artéria basilar na área do João.

O último ficheiro dessa sequência é o culminar documentado dessa subcomponente,
mas não o ponto de entrada final demonstrado para todo o projeto. A árvore B
também contém demonstrações, testes e experiências que não devem ser promovidos
em bloco.

A decisão é, por isso, adaptar apenas as partes relevantes numa reconstrução
pública individual, em vez de declarar uma destas pastas como submissão final
original. A proveniência, os erros identificados e as alterações estão
centralizados em `TECHNICAL_RECONSTRUCTION.md`.

## Como estas condições foram resolvidas

1. o escopo foi limitado a geometria comum, *landmarks*/contactos e análise da
   basilar;
2. os hashes das fontes estão registados em
   `TECHNICAL_RECONSTRUCTION.md`;
3. os problemas técnicos identificados foram substituídos por algoritmos novos,
   sem copiar em bloco os scripts históricos;
4. as métricas são exercitadas com geometrias sintéticas e unidades físicas;
5. dados, identificadores e caminhos fixos foram substituídos por entradas
   explícitas e um caso sintético;
6. toda a documentação distingue a reconstrução individual posterior da
   submissão académica original.

Isto torna a reconstrução tecnicamente publicável, sem transformar os dados,
relatórios ou código histórico excluídos em material público.
