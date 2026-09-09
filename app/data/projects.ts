export type PortfolioProject = {
  id: string;
  number: string;
  context: string;
  title: string;
  summary: string;
  contribution: string;
  evidence: string;
  topics: string[];
  boundary: string;
  publication: "Publicação preparada" | "Código público" | "Resumo sanitizado";
  repositoryUrl?: string;
};

export const personalProjects: PortfolioProject[] = [
  {
    id: "projeto-portfolio",
    number: "P01",
    context: "Projeto pessoal · autoria individual",
    title: "Portefólio profissional",
    summary:
      "Site público para reunir evidência profissional, projetos e limites de publicação numa apresentação coerente para recrutadores.",
    contribution:
      "Estruturei o conteúdo e as salvaguardas de privacidade, com desenvolvimento assistido pelo OpenAI Codex e revisão factual antes de cada publicação.",
    evidence:
      "Aplicação TypeScript testada, histórico Git auditado, integração contínua e publicação em Cloudflare Workers através de OpenAI Sites.",
    topics: ["TypeScript", "React", "Next.js", "Vinext", "Node.js", "GitHub Actions"],
    boundary:
      "O repositório documenta o processo real: a assistência de IA é declarada e não substitui a revisão, os testes nem a responsabilidade pela publicação.",
    publication: "Código público",
    repositoryUrl: "https://github.com/1200766/portfolio-joao-santos",
  },
];

export const academicProjects: PortfolioProject[] = [
  {
    id: "projeto-medibrain",
    number: "A01",
    context: "Estágio curricular · trabalho individual",
    title: "MediBrain — pré-processamento de EEG",
    summary:
      "Comparação quantitativa e qualitativa de quatro estratégias automáticas de pré-processamento de sinais EEG.",
    contribution:
      "Implementei AutoReject, ICA com ICLabel e duas pipelines híbridas; comparei artefactos, espectros, Brain Symmetry Index e tempo de execução.",
    evidence:
      "Estágio de quatro meses, seis registos EEG analisados e classificação final de 15 valores.",
    topics: ["Python", "MNE", "EEG", "ICA + ICLabel", "AutoReject"],
    boundary:
      "Estudo exploratório sem ground truth nem validação clínica externa. Código e relatório exigem revisão; os sinais não são publicáveis por omissão.",
    publication: "Resumo sanitizado",
  },
  {
    id: "projeto-predipe",
    number: "A02",
    context: "Projeto académico · autoria coletiva",
    title: "PrediPE",
    summary:
      "Protótipo de apoio à decisão clínica para previsão e estratificação longitudinal do risco de pré-eclâmpsia.",
    contribution:
      "Desenvolvimento conjunto de preparação de dados, modelo explicável, API, autenticação, base de dados e entrada de recursos HL7 FHIR.",
    evidence:
      "Avaliação experimental sobre 10 000 registos inteiramente sintéticos, com ROC AUC de 0,8813 no conjunto de teste.",
    topics: ["XGBoost", "SHAP", "FastAPI", "JWT", "PostgreSQL", "HL7 FHIR"],
    boundary:
      "Evidência académica coletiva, sem dados clínicos reais, integração bidirecional com um sistema clínico, validação clínica ou produção.",
    publication: "Resumo sanitizado",
  },
  {
    id: "projeto-seguranca-dicom",
    number: "A03",
    context: "Projeto académico · contributos individuais documentados",
    title: "Segurança Web e DICOM",
    summary:
      "Análise de tráfego e segurança num ambiente distribuído com serviços Web e imagiologia médica.",
    contribution:
      "Recolhi e analisei ficheiros PCAP, construí filtros e estatísticas e colaborei em fluxos DICOM C-STORE, C-FIND e C-MOVE.",
    evidence:
      "Contributos individuais registados em Wireshark, HTTP/TCP e dcm4che; classificação de 13 valores no projeto coletivo.",
    topics: ["Wireshark", "DICOM", "Orthanc", "dcm4che", "HTTP/TCP", "TLS"],
    boundary:
      "A integração completa pertence à equipa. No ensaio com DCMQRscp, apenas o C-MOVE funcionou corretamente; ataques foram analisados, não executados.",
    publication: "Resumo sanitizado",
  },
  {
    id: "projeto-platink",
    number: "A04",
    context: "Projeto académico · autoria coletiva",
    title: "Platink — prato inteligente",
    summary:
      "Protótipo integrado para monitorização alimentar, combinando instrumentação, desenho físico, software e visão computacional.",
    contribution:
      "A equipa trabalhou conjuntamente em todas as etapas: célula de carga e Arduino, PCB, impressão 3D, backend, base de dados e classificação de imagem.",
    evidence:
      "Protótipo multidisciplinar concluído; um trabalho posterior aplicou classificação, risco, rotulagem e documentação de dispositivo médico.",
    topics: ["Arduino", "EasyEDA", "SolidWorks", "MySQL", "PyTorch", "EfficientNet"],
    boundary:
      "Os resultados de classificação não demonstram generalização. O plano de manutenção e calibração foi documental, sem testes físicos.",
    publication: "Resumo sanitizado",
  },
  {
    id: "projeto-safehealth",
    number: "A05",
    context: "Projeto académico · autoria coletiva",
    title: "SafeHealth",
    summary:
      "Protótipo de telemonitorização domiciliária para recolher e apresentar frequência cardíaca, SpO₂ e temperatura.",
    contribution:
      "A equipa integrou sensores e ESP32, processamento local, envio HTTP/JSON, backend PHP, MySQL e portais Web por perfil.",
    evidence:
      "Demonstração integrada da aquisição, processamento, transmissão, armazenamento e apresentação de medições.",
    topics: ["ESP32", "MAX30102", "DS18B20", "PHP", "MySQL", "HTTP/JSON"],
    boundary:
      "O relatório não individualiza tarefas. Protótipo local, sem TLS, validação clínica ou metrológica, testes formais ou adequação a produção.",
    publication: "Resumo sanitizado",
  },
  {
    id: "projeto-pimed",
    number: "A06",
    context: "Projeto académico · autoria coletiva",
    title: "PIMED — imagem médica 3D",
    summary:
      "Segmentação e análise geométrica de vasculatura cerebral em imagens TOF-MRA 3D da base BraVa.",
    contribution:
      "Todos os elementos participaram na segmentação, código, extração de landmarks, métricas geométricas, análise e reformulação por esqueletização 3D.",
    evidence:
      "Pipeline exploratória em Python com ITK, VTK, NumPy, SciPy e PyQt, apoiada por segmentação manual em ITK-SNAP.",
    topics: ["Python", "ITK", "VTK", "ITK-SNAP", "Imagem 3D", "Esqueletização"],
    boundary:
      "Trabalho coletivo e exploratório, sem IA implementada, ground truth, validação clínica ou demonstração de melhoria diagnóstica.",
    publication: "Resumo sanitizado",
  },
];
