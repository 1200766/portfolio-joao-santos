# Sistema Automatizado de Análise de Marcha

[← Projetos Académicos](../README.md)

## Estado e âmbito

Esta pasta é uma exportação limpa do projeto académico desenvolvido na unidade
curricular de Interação Homem-Máquina no ano letivo de 2025/2026. Contém o
script final indicado por João Pedro Santos e a documentação mínima para o
compreender e instalar.

**Autores:** João Amaral Santos, João Pedro Santos e Joel Pereira.

**Este software é uma prova de conceito académica e não clínica.** Não é um
dispositivo médico, não foi validado para diagnóstico, tratamento, ajuste de
próteses ou tomada de decisões clínicas e não substitui avaliação por
profissionais qualificados. As medições dependem, entre outros fatores, da
posição da câmara, perspetiva, iluminação, oclusões, qualidade dos landmarks e
calibração manual.

## O que o script faz

O programa permite selecionar um vídeo ou uma webcam através de uma interface
gráfica. Depois de uma calibração manual com dois pontos separados por 25 cm,
processa os frames com MediaPipe Pose e Face Mesh, desenha anotações, regista a
série temporal do ângulo implementado e estima comprimentos funcionais. No fim,
pode gerar:

- um vídeo anotado em MP4;
- uma folha de cálculo XLSX com tempo e ângulo;
- um relatório PDF com resumo e gráfico.

A descrição e a implementação científica da métrica foram preservadas tal como
constam do script final do trabalho académico. Esta exportação não acrescenta
uma alegação de validade clínica.

## Estrutura

```text
publicacao/
├── .gitignore
├── src/
│   └── analise_marcha_protese.py
├── AUTHORS.md
├── CONTRIBUTIONS.md
├── INVENTARIO_EXCLUIDO.md
├── README.md
├── RIGHTS.md
└── requirements.txt
```

## Origem do código

O ficheiro `src/analise_marcha_protese.py` deriva do script final identificado
em `Projeto/Documentos/`. A única alteração de conteúdo foi a linha de autoria,
para remover números de estudante e distinguir os autores homónimos; a
implementação e a descrição da métrica não foram alteradas. O SHA-256 do
original preservado é:

```text
381e4fb5204e9394bd6cb19b4cc9ed8923e033512870dc18bd72518eecf3aa24
```

O SHA-256 da cópia preparada é:

```text
af11630ef22fa2d506638de7f89aa19fe49e61b8c17635e35c4d09345c802c2e
```

Este segundo hash deve ser atualizado no registo de publicação sempre que for
feita uma alteração futura. Os protótipos existentes na raiz de `Projeto/` não
foram promovidos para esta exportação.

## Instalação

A versão exata de Python e as versões das bibliotecas usadas no desenvolvimento
não ficaram registadas. Deve ser usada uma versão de Python 3 compatível com as
versões instaladas das dependências e a compatibilidade deve ser confirmada no
sistema onde o programa será usado.

Em macOS ou Linux:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

Em Windows PowerShell:

```powershell
py -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

`tkinter` faz parte da distribuição padrão de muitas instalações de Python,
mas pode exigir um pacote de sistema separado, por exemplo `python3-tk` em
algumas distribuições Linux.

## Execução

Na raiz desta pasta:

```bash
python src/analise_marcha_protese.py
```

1. Escolher um vídeo compatível ou a opção de webcam.
2. Na janela de calibração, marcar dois pontos cuja distância real seja 25 cm.
3. Premir `c` para confirmar a calibração, `r` para repetir ou `q`/`Esc` para
   sair.
4. Durante a análise, premir `q`/`Esc` para terminar antecipadamente.

Com vídeo, os resultados são escritos numa pasta `output/` junto do vídeo de
entrada. Com webcam, são escritos em `src/output/`. Estes resultados estão
ignorados por Git.

## Compatibilidade conhecida

O caminho de webcam usa os backends DirectShow e Media Foundation do OpenCV e
foi escrito com uma Canon EOS em Windows em mente. A opção de vídeo pode ser
mais portátil, mas requer um ambiente gráfico e codecs compatíveis. Não existe
ainda uma matriz de versões ou sistemas operativos testados.

## Dados e meios excluídos

Esta exportação não contém vídeos, imagens de pessoas, relatórios, apresentações
nem resultados gerados. Segundo declaração de João Pedro Santos, houve
autorização clínica para a captação e utilização dos vídeos no contexto do
trabalho académico. Por decisão de publicação, essa autorização não é utilizada
como fundamento para redistribuição pública: os vídeos, fotogramas e dados
derivados identificáveis permanecem no arquivo privado.

Consultar `INVENTARIO_EXCLUIDO.md` e `RIGHTS.md` antes de publicar.

## Limitações de reprodução

- As dependências foram inferidas dos imports e não estão fixadas a versões.
- Não existem testes automatizados nem um vídeo público de exemplo.
- A calibração é manual e pressupõe uma referência de 25 cm no plano adequado.
- A deteção e as medições podem degradar-se com perspetiva, oclusões, roupa,
  iluminação e enquadramento.
- A inferência apresentada pelo programa sobre o lado da prótese é uma
  heurística académica, não uma conclusão clínica validada.

João Pedro Santos confirmou em 15 de setembro de 2026 que o projeto funcionou
corretamente durante o seu desenvolvimento. Por sua decisão expressa, essa
validação histórica é suficiente para a primeira publicação e não será feita
uma nova execução com os vídeos privados nem criado artificialmente um teste de
demonstração. A sintaxe do script foi verificada; a ausência de um teste
reproduzível atual permanece documentada como limitação, não como bloqueio.

## Publicação

Segundo declaração de João Pedro Santos em 2026-09-11, os três coautores
autorizaram a publicação pública do trabalho conjunto. A identificação pública
está resolvida em `AUTHORS.md`. Não foi concedida uma licença de software; esta
pasta mantém todos os direitos reservados e não constitui software aberto.

No único repositório público de portefólio, uma cópia exclusiva do conteúdo
desta exportação deve ocupar
`Projetos Académicos/interacao-homem-maquina/`. A única raiz Git fica na raiz do
repositório, acima de `Projetos Académicos/` e `Projetos Pessoais/`; não deve
existir um `.git` nesta exportação. Assim, o arquivo privado em `Projeto/` e os
respetivos vídeos permanecem fora do repositório.
