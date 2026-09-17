# Sistema de Apoio à Decisão para Diagnóstico do Cancro da Próstata

Protótipo académico de gestão de informação de saúde e apoio à decisão por
questionários e alertas relacionados com o cancro da próstata.

**O código nas pastas `FrontEnd/` e `Backend/` não corresponde à versão final
desenvolvida na unidade curricular.** Foram preservadas versões anteriores e
incompletas. Segundo confirmação de João Santos, parte dos ficheiros da versão
final perdeu-se ao longo do tempo. Esta seleção apresenta o código recuperado
e o relatório do trabalho; as diferenças e limitações de cada componente estão
descritas nos respetivos README.

## Contexto e autoria

- **Unidade curricular:** Informática Médica.
- **Curso e instituição:** Licenciatura em Engenharia Biomédica, Instituto
  Superior de Engenharia do Porto (ISEP).
- **Ano letivo:** 2024/2025.
- **Entrega indicada no relatório:** 16 de junho de 2025.
- **Autores:** Beatriz Ribeiro, João Santos e Marta Tedim.
- **Docentes indicados no relatório:** Constantino Martins e Júlio Souza.

Trabalho coletivo. Não é atribuída uma divisão individual de tarefas que não
esteja documentada. Consultar [AUTHORS.md](AUTHORS.md).

## Trabalho desenvolvido

Segundo o relatório e a confirmação de João Santos, o projeto reuniu:

- gestão de utentes, médicos e administradores;
- registo e consulta de consultas previamente marcadas;
- organização de dados pessoais, informação de saúde e histórico;
- questionários de perfil e anamnese;
- interpretação de respostas por regras e apresentação de alertas;
- interface de administração e interface de consulta de informação pelo médico;
- levantamento de requisitos, modelação do domínio e diagramas de arquitetura.

O registo de consultas no sistema servia para representar consultas já
marcadas por outros meios. Não se apresenta como um serviço de marcação
autónoma pelo utente.

**Clarificação sobre o menu de utente:** foi um extra que a equipa decidiu não
implementar, mas mencionar na apresentação do projeto. As descrições e
capturas dessa área no relatório devem ser lidas com esta clarificação. Esse
menu não integra as funcionalidades implementadas e não é classificado como
código final perdido.

## Conteúdo desta seleção

```text
.
├── README.md
├── FrontEnd/
│   ├── README.md
│   ├── src/
│   └── configuração e dependências declaradas
├── Backend/
│   ├── README.md
│   ├── auth/
│   ├── models/
│   ├── routes/
│   └── server.ts e configuração
├── Relatorio.pdf
├── AUTHORS.md
├── RIGHTS.md
├── PROVENIENCIA.md
└── VERIFICACAO.md
```

| Componente | Tecnologia | Estado preservado |
|---|---|---|
| [FrontEnd](FrontEnd/README.md) | Angular, TypeScript, HTML/CSS, RxJS e calendário Syncfusion | Interfaces de administrador e médico; versão não final, com erro de compilação documentado |
| [Backend](Backend/README.md) | Node.js, Express, TypeScript, MongoDB/Mongoose e JWT | API, modelos e parte das regras; versão não final, sem a base de dados original |
| [Relatório](Relatorio.pdf) | Documento académico de 30 páginas | Original incluído integralmente, sem alterações de conteúdo ou metadados |

## Relatório e código histórico

O título original do relatório é **“Sistema de Apoio à Decisão no Diagnóstico
do Cancro da Próstata”**. João Santos confirmou que o documento descreve o
trabalho realizado, com a ressalva explícita do menu de utente acima indicada.
Por sua decisão, o PDF é incluído exatamente como foi fornecido.

O relatório constitui documentação histórica da entrega. A seleção de código
atual tem um alcance menor: a ausência de uma função nesta cópia não demonstra
que ela estivesse ausente da versão final. Do mesmo modo, o relato histórico
não equivale a uma nova verificação funcional do código recuperado.

## Instalação, utilização e resultados

Os README de [FrontEnd](FrontEnd/README.md) e [Backend](Backend/README.md)
explicam as dependências, comandos de inspeção e requisitos de configuração.
Esta seleção destina-se principalmente à leitura e apreciação do trabalho
académico. **Não existe uma demonstração integral reproduzível nesta versão.**

Faltam os dados de inicialização dos questionários e a base de dados original;
o frontend depende de identificadores desses registos. Além disso, foram
preservadas as falhas funcionais e de compilação identificadas na versão
recuperada. A preparação para publicação remove valores sensíveis e acrescenta
documentação, sem reconstruir funcionalidades ou apresentar correções como
trabalho original da UC.

Os resultados recuperados são o código, a modelação e a documentação das
interfaces e regras. Não são apresentadas métricas de eficácia clínica,
desempenho, usabilidade ou segurança que não tenham sido demonstradas.
Consultar os resultados efetivos das verificações em
[VERIFICACAO.md](VERIFICACAO.md).

## Âmbito académico e dados

O sistema implementa regras de apoio à decisão; não foi identificado um modelo
de aprendizagem automática ou uma avaliação clínica do protótipo. A sua
apresentação no portefólio não o torna adequado para diagnóstico, tratamento
ou utilização com dados reais de utentes.

Não são distribuídos registos da base de dados, contas de demonstração,
credenciais, dependências instaladas, caches ou compilados antigos. O relatório
original conserva as capturas e elementos da entrega académica; a sua inclusão
não constitui uma declaração de anonimização dos exemplos nem uma licença
para reutilização dos dados ou imagens representados.

## Direitos e proveniência

Os direitos dos autores e de terceiros são descritos em [RIGHTS.md](RIGHTS.md).
Não é concedida uma licença aberta de reutilização desta seleção. As
bibliotecas mantêm as suas próprias licenças.

[PROVENIENCIA.md](PROVENIENCIA.md) identifica a origem das componentes, as
alterações de curadoria e a verificação de identidade do PDF. Os arquivos
originais permanecem preservados fora da seleção pública.
