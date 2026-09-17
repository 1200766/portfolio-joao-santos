# Política dos dados e das imagens

## Materiais incluídos

A exportação pública contém:

- 46 registos de peças em `data/clothes.json`;
- tipo, marca, tamanho, estado e preço quando estes dados estavam disponíveis;
- 135 fotografias em `public/roupa/`;
- a imagem de apresentação `public/og.png`.

Não se trata de um inventário fictício. O autor escolheu e autorizou
explicitamente a inclusão destes registos e destas imagens na versão pública
do seu portefólio.

## Persistência das edições

O ficheiro JSON incluído no repositório é apenas de leitura durante a
utilização do site. A aplicação não envia alterações para uma API nem escreve
numa base de dados remota.

Os cinco campos editáveis são guardados exclusivamente no `localStorage` do
navegador. A ação **Repor dados originais** elimina essa cópia local e volta a
mostrar o inventário versionado.

## Auditoria de metadados

Na preparação desta exportação foram analisadas as 135 fotografias:

- não foram detetadas coordenadas GPS;
- permanecem metadados técnicos com a marca e o modelo do dispositivo
  (`Apple`, `iPhone 16 Pro`), a versão de software (`26.5`) e datas de criação
  entre 25 e 26 de julho de 2026;
- `public/og.png` não apresentou estes campos técnicos.

As fotografias foram preservadas sem reprocessamento por decisão expressa do
autor. Quem publicar uma versão derivada deve repetir esta análise, porque um
novo conjunto de imagens pode conter metadados diferentes.

## Reutilização

Os dados e as fotografias destinam-se à demonstração do projeto. A sua
publicação não os coloca no domínio público nem autoriza a reutilização. As
condições aplicáveis estão em [RIGHTS.md](RIGHTS.md).
