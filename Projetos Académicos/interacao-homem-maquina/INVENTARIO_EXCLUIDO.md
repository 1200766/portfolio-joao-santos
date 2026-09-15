# Inventário do material excluído

Esta exportação preserva os originais no diretório `Projeto/`, mas não os copia
para a área de publicação.

## Meios e resultados

- vídeo original de marcha: mantido no arquivo privado e excluído por dimensão
  e privacidade;
- vídeo anotado em `Projeto/output/`: mantido no arquivo privado pelos mesmos
  motivos e por ser um resultado gerado;
- folhas de cálculo e relatórios PDF gerados: não foram incluídos porque podem
  conter medições derivadas de pessoas e podem ser reproduzidos pelo programa.

## Documentação académica

- relatório em DOCX e PDF: excluído por conter identificação académica, imagens
  e possíveis elementos de terceiros;
- apresentação em PPTX: mantida no arquivo privado e fora desta seleção.

## Código não promovido

- `Projeto/analise_marcha.py`;
- `Projeto/app_gui.py`;
- `Projeto/app_gui_tk.py`.

Estes ficheiros são protótipos anteriores. João Pedro Santos indicou como versão
final o script existente em `Projeto/Documentos/`. Na cópia colocada em
`src/analise_marcha_protese.py`, a única alteração de conteúdo é a linha de
autoria, para remover números de estudante e distinguir os autores homónimos;
o original permanece intacto.

## Ficheiros técnicos

- `.DS_Store` e `__pycache__/`: metadados locais e bytecode gerado;
- futuros ambientes virtuais, caches, vídeos e resultados: abrangidos por
  `.gitignore`;
- apenas o conteúdo curado de `publicacao/` deve ser copiado para
  `Projetos Académicos/interacao-homem-maquina/` no único repositório público
  de portefólio; não deve ser criado um `.git` nesta exportação nem na raiz da
  cadeira, mantendo todo o conteúdo de `Projeto/` fora do repositório.
