# Direitos, licenças e atribuições

## Código deste projeto

**Todos os direitos reservados.**

Não foi escolhida nem concedida uma licença para o código em `src/` ou para a
documentação desta pasta. Segundo declaração de João Santos em 2026-09-11, a
Clínica MediBrain e o ISEP autorizaram a partilha pública de todo o trabalho
realizado e utilizado durante o estágio sob a sua supervisão.

João Santos declara ter construído todo o código deste projeto. A publicação
fica deliberadamente sob todos os direitos reservados: a autorização
institucional permite publicar o trabalho, mas não concede a terceiros direitos
de reutilização, modificação ou redistribuição. As decisões e os limites estão
registados em [`PUBLICATION_REVIEW.md`](PUBLICATION_REVIEW.md).

## Conjunto de dados

Nenhum sinal EEG em bruto é distribuído neste repositório. O relatório original
incluído na versão pública contém figuras e resultados derivados dos exemplos
EEG públicos nele descritos. A revisão realizada não identificou no PDF
resultados derivados dos dados privados excluídos da exportação.

O script de descarga aponta para a **Siena Scalp EEG Database v1.0.0**, um
recurso externo do PhysioNet disponibilizado sob
[Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/).
Quem descarregar os dados deve cumprir a licença e todas as citações indicadas
na [página oficial](https://physionet.org/content/siena-scalp-eeg/1.0.0/).

A CC BY 4.0 aplica-se aos ficheiros da base de dados; não licencia o código
deste projeto.

## Dependências de software

As dependências declaradas em `requirements.txt` são instaladas separadamente e
não são redistribuídas nesta pasta:

- MNE-Python: <https://github.com/mne-tools/mne-python>
- MNE-ICALabel: <https://github.com/mne-tools/mne-icalabel>
- AutoReject: <https://github.com/autoreject/autoreject>
- NumPy: <https://github.com/numpy/numpy>
- SciPy: <https://github.com/scipy/scipy>
- Matplotlib: <https://github.com/matplotlib/matplotlib>
- ReportLab: <https://www.reportlab.com/>

Cada componente conserva os seus próprios direitos, licenças, avisos e
obrigações de atribuição. A utilização de uma dependência não transfere a sua
licença para o código deste projeto. As referências científicas da base de
dados, do ICLabel e do MNE-ICALabel estão reunidas no `README.md`.

## Relatório e apresentação

O relatório académico original está incluído como cópia byte-for-byte do PDF
preservado no arquivo privado. Não foi sanitizado, corrigido, recompilado nem
reexportado. João Santos decidiu conscientemente manter no documento o seu nome
e email institucional, assim como as figuras e resultados derivados de
exemplos EEG públicos. O texto histórico do relatório não é atualizado pelas
explicações posteriores desta exportação.

A apresentação académica original permanece excluída. A decisão de incluir o
relatório não autoriza a publicação da apresentação nem de outros materiais,
logótipos, imagens ou conteúdo de terceiros.
