# Proveniência da seleção

**Preparação:** 17 de setembro de 2026.

Esta seleção deriva dos materiais conservados pela equipa no arquivo da
unidade curricular de Informática Médica. Os originais permanecem fora desta
pasta e foram preservados.

## Correspondência dos materiais

| Material original | Localização nesta seleção |
|---|---|
| Pasta `FrontEnd 5` | `FrontEnd/` |
| Pasta `Backend_INFME 4` | `Backend/` |
| Relatório PDF de 30 páginas | `Relatorio.pdf` |

Os nomes das pastas foram simplificados para apresentar as duas componentes.
Segundo João Santos, a versão final do frontend/backend perdeu-se
parcialmente; o código disponível é anterior e incompleto. O relatório
documenta o trabalho realizado, com a ressalva expressa de que o menu de
utente foi um extra não implementado.

## Relatório integral

O relatório foi copiado sem edição, conversão, anonimização ou alteração de
metadados, por decisão expressa de João Santos. A comparação SHA-256 do
original com `Relatorio.pdf` produz o mesmo valor:

```text
a0838bb1c3c2bfe5e35c6953b7aa7ec958a99d451a84bb323a913af65610084c
```

A renomeação do ficheiro não altera o seu conteúdo. A data de entrega inscrita
na capa é 16 de junho de 2025; os metadados do PDF fornecido indicam uma
exportação em setembro de 2026 e não são usados para datar o desenvolvimento.

## Alterações de curadoria

- Adoção da designação «Sistema de Apoio à Decisão para Diagnóstico do Cancro da Próstata» na documentação, nos títulos e nos textos da cópia de código, por instrução expressa de João. O relatório e o arquivo original mantêm-se intactos.
- Documentação nova na raiz, no backend e no frontend sobre autoria, contexto,
  versão preservada, diferenças, limitações e comandos de inspeção.
- Substituição dos valores MongoDB e JWT por configuração de ambiente
  obrigatória no backend, através de `config.ts` e `.env.example`.
- Substituição da chave Syncfusion por um marcador que exige uma chave própria.
- Remoção de logs que expunham tokens, corpos de pedidos ou dados pessoais e
  clínicos. A lógica de negócio e as regras históricas foram preservadas.
- Alinhamento dos metadados do backend com os direitos reservados da seleção:
  o marcador `ISC` passou a `UNLICENSED`, sem atualização de dependências.

Estas alterações são de setembro de 2026 e não são atribuídas à entrega
académica de junho de 2025. Não foram reconstruídas funcionalidades, corrigido
o arranque Angular, alteradas regras clínicas ou criada uma nova base de dados.

## Materiais excluídos

- Dependências instaladas em `node_modules/` e cache `.angular/`.
- Compilados `dist/`, incluindo seis modelos antigos sem fonte atual.
- Configurações do editor, ficheiros `.DS_Store` e outros resíduos locais.
- Credenciais históricas e qualquer configuração real de acesso.
- Documentação privada de análise e preparação, inventário de hashes e
  contexto pessoal do autor.

Não existiam no arquivo analisado exportação da base de dados, seed dos
questionários, coleção Postman ou fonte editável do relatório. A ausência
desses materiais é documentada; não foram inventados substitutos.

Para verificações técnicas e respetivos limites, consultar
[VERIFICACAO.md](VERIFICACAO.md). Para direitos, consultar
[RIGHTS.md](RIGHTS.md).
