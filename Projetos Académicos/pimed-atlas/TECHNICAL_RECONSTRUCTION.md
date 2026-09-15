# Reconstrução técnica individual

## Contexto e autoria

O ATLAS nasceu como um projeto académico coletivo. A análise e o código
selecionados para esta versão pública correspondem, contudo, à contribuição
individual de João Santos dentro desse projeto: o fluxo de *landmarks* guardado
na Árvore A e a evolução da análise da artéria basilar guardada na Árvore B
foram desenvolvidos exclusivamente por João.

Em 2026, João voltou a analisar essa contribuição, identificou problemas no
protótipo preservado e decidiu reconstruí-lo individualmente. A versão em
`src/` é essa reconstrução posterior: reaproveita objetivos, conceitos e
algumas operações justificáveis, mas não é apresentada como a submissão
académica original.

## Fontes preservadas

As fontes privadas usadas para estabelecer a proveniência são:

| Origem | Papel | SHA-256 |
|---|---|---|
| Árvore A — `Projeto2/main.py` | Encadeamento de *landmarks*, bifurcações, AICAs e contactos | `dc3a32377aed2bf194038dd5f866388d52a116f093ac618c4e0972c0061137c5` |
| Árvore A — `Projeto2/my_functions.py` | Funções usadas pelo fluxo de *landmarks* e bloco experimental da basilar | `4614dc987a4860d6b24facc571e0b1547cb26d994c85166fe9cda29966097e6a` |
| Árvore B — `BasilarInSlicesAxisZ.py` | Abordagem inicial por fatias axiais | `5de292c03bb0150454daa682a37251706f5f9b7b8eded2b50ef12968473ccb4a` |
| Árvore B — `BasilarInSlices.py` | Experiência intermédia | `d2b8a2687c6aceaede9bf719241007ddee8caaf2c1231be03b4222aee45d07b0` |
| Árvore B — `BasilarInSlicesSkeleton.py` | Revisão experimental orientada pelo esqueleto | `cae70fba4c58ce15decc82433a672cc9548fc00f828e8f7f6200470e6ec2ca62` |
| Árvore B — `main.py` | Tentativa de separar a execução da basilar | `0df21f6db0f6bb795e50440fb41e81bcabbe53133794142db65d34c891c28257` |
| Árvore B — `my_Functions.py` | Funções da tentativa de refatoração | `ec0c4e88cc017652e1944a5657afad43f2d582c581aa37bccf0b2436babbb1f6` |

Os hashes identificam exatamente o material analisado sem copiar os ficheiros
privados para o repositório público.

## Problemas identificados na revisão posterior

### Landmarks e contactos

- uma função relia as coordenadas a partir das colunas erradas do ficheiro
  intermédio;
- a classificação refinada de B3/B4 era posteriormente recalculada e ignorada;
- a ausência de contacto devolvia um número de valores incompatível com o
  chamador;
- P1 e P2 eram cantos da caixa delimitadora conjunta, não pontos demonstrados
  de contacto entre cada AICA e a basilar;
- alguns cálculos misturavam índices de voxel com coordenadas em milímetros;
- as transformações ignoravam a matriz de direção da imagem;
- regras anatómicas dependentes dos eixos eram aplicadas sem declarar o sistema
  de coordenadas.

### Linha central e secções da basilar

- `np.argwhere` ordenava os voxels do esqueleto pela posição na matriz, não pela
  conectividade ao longo da artéria;
- pares que não eram vizinhos podiam definir a direção do plano de corte;
- a região de corte era apenas a caixa mínima entre dois pontos;
- `vtkCutter` cortava a geometria da grelha do volume, sem isolar o lúmen
  representado pela máscara binária;
- a conversão posterior para índices inteiros fazia pontos distintos colapsar;
- o Feret era calculado em voxels, enquanto outras grandezas usavam coordenadas
  físicas;
- `2 × desvio-padrão` era apresentado como diâmetro elipsoidal;
- os centroides eram reordenados por `z`, o que não preserva o comprimento de
  arco de uma estrutura curva.

Estes problemas explicam as secções nulas e as distâncias discretas observadas
nos resultados históricos. Esses resultados são evidência do processo de
desenvolvimento, não valores esperados para os testes da reconstrução.

## Correção científica da justificação original

Não é universalmente verdade que o eixo maior de uma elipse equivalente tenha
de ser inferior ao diâmetro de Feret. Uma elipse equivalente representa os
momentos da forma e não tem de estar inscrita nela.

A razão correta para abandonar fatias axiais fixas é outra: quando a artéria é
curva ou oblíqua, um plano axial não representa necessariamente uma secção
transversal. A reconstrução mantém, por isso, a orientação pela linha central,
mas redefine o modo de extrair e medir cada secção.

## Arquitetura da reconstrução

```text
volume de labels
      │
      ▼
core: geometria, coordenadas e validação
      │
      ├── landmarks: componentes, B3/B4, AICAs e contactos
      │                         │
      │                         └── coordenadas candidatas
      │                                      │
      │                         seleção e revisão pelo utilizador
      │                                      │
      └── basilar: âncoras físicas → máscara → esqueleto → grafo → caminho
                                             │
                                             ▼
                                  secções 2D ortogonais
                                             │
                                             ▼
                                      métricas em mm
```

O módulo `landmarks` mantém a identificação anatómica configurável e não
transforma heurísticas históricas em regras universais. Não existe uma ligação
automática entre os dois módulos: o utilizador pode rever coordenadas B4/B3
obtidas no primeiro e fornecê-las como âncoras físicas ao módulo `basilar`. O
modo automático destina-se apenas a casos sintéticos ou exploratórios e emite
um aviso.

## Alterações introduzidas individualmente

- separação entre dados, geometria, análise e escrita de resultados;
- remoção de números de estudante, datasets e caminhos fixos;
- eliminação de variáveis e ficheiros globais;
- execução sem interface gráfica obrigatória;
- conectividade 26 explícita e distâncias ponderadas pelo espaçamento físico;
- percurso da linha central obtido num grafo, em vez da ordem de memória;
- reamostragem da máscara num plano 2D real, em vez de cortar a grelha VTK;
- métricas bidimensionais com nomes e unidades explícitos;
- resultados estruturados e avisos de qualidade;
- testes exclusivamente com geometrias sintéticas conhecidas.

Os resultados omitem automaticamente o caminho de origem, o identificador do
caso e os voxels, mas não prometem anonimização total: campos textuais definidos
pelo utilizador no esquema são preservados e têm de ser revistos antes de uma
publicação.

A análise chamada de contacto conserva uma métrica discreta e explicitamente
nomeada: distância entre centros de voxels de superfície. É útil como
proximidade dependente da resolução, mas não equivale à distância entre duas
superfícies contínuas nem a uma área de contacto.

## Validação implementada

A suite pública usa apenas dados sintéticos. Neste estado, testa:

- transformação entre índices e coordenadas físicas com origem, espaçamento e
  rotação;
- leitura e escrita NPZ e, quando instalada a dependência opcional, leitura de
  VTK legado;
- componentes 26-conexas, *landmarks*, lateralidade declarada, contactos,
  distâncias e ângulos;
- ordenação geodésica da linha central, ramos, componentes desligadas e rejeição
  do modo automático perante ciclos;
- secções de tubos direitos, oblíquos e curvos em 3D, espaçamento anisotrópico e
  elipses com eixos distintos;
- execução integrada dos pipelines e da interface de linha de comandos;
- rejeição de máscaras truncadas pelo limite do volume e de âncoras inválidas.

O VTK legado não transporta a matriz de orientação. O adaptador assume direção
identidade e regista essa suposição no resumo de entrada; uma convenção LPS/RAS
tem de ser confirmada fora do ficheiro.

Ainda não existe validação clínica nem um estudo formal de erro em toda a gama
de resoluções e anatomias possíveis. Casos sintéticos adicionais, incluindo
anisotropia extrema e estudos multirresolução do Feret, continuam a ser
melhorias futuras e não são apresentados aqui como testes já realizados.

Os volumes médicos, segmentações, relatórios e resultados derivados preservados
no arquivo privado não fazem parte do repositório nem são usados como *fixtures*
públicas. Uma eventual execução privada serve apenas como verificação técnica;
não constitui validação clínica.

## Limites

Este é um projeto académico e uma reconstrução posterior. Não é um dispositivo
médico, não foi validado clinicamente e não deve ser usado em diagnóstico,
tratamento ou tomada de decisões sobre pessoas.

A esqueletização continua dependente da grelha discreta e deve ser recusada ou
preparada por reamostragem quando a anisotropia for excessiva. As bases `u/v` dos
planos são locais: as áreas e os diâmetros são comparáveis, mas a orientação do
centróide em `u/v` não representa ainda um referencial contínuo de Bishop. O
Feret é estimado no casco dos píxeis da secção, pelo que a resolução de
reamostragem limita a precisão. O campo de distância usa memória proporcional
ao volume e exige fundo em redor da componente para detetar máscaras truncadas.
