import { academicProjects, personalProjects } from "./data/projects";

const contributionPillars = [
  {
    number: "01",
    title: "Analisar com rigor",
    description:
      "Comparo abordagens, defino critérios e cruzo métricas com inspeção crítica antes de concluir.",
  },
  {
    number: "02",
    title: "Integrar tecnologias",
    description:
      "Ligo dados, software e componentes físicos para transformar um problema num protótipo funcional.",
  },
  {
    number: "03",
    title: "Comunicar com clareza",
    description:
      "A experiência com clientes e equipas ensinou-me a escutar, explicar e manter qualidade sob pressão.",
  },
  {
    number: "04",
    title: "Aprender e entregar",
    description:
      "Exploro de forma autónoma, decomponho o problema e organizo o trabalho até existir um resultado utilizável.",
  },
];

const technicalAreas = [
  {
    label: "Sinais biomédicos e dados",
    title: "Do sinal à interpretação",
    description:
      "Pré-processamento de EEG, comparação experimental e análise temporal, espectral e quantitativa.",
    technologies: ["Python", "MNE", "EEG", "ICA + ICLabel", "AutoReject"],
  },
  {
    label: "Software e IA aplicada",
    title: "Modelos integrados em sistemas",
    description:
      "Desenvolvimento de protótipos que ligam modelos de aprendizagem automática a APIs e dados estruturados.",
    technologies: ["XGBoost", "SHAP", "PyTorch", "FastAPI", "PostgreSQL"],
  },
  {
    label: "Sistemas clínicos e segurança",
    title: "Dados de saúde em circulação",
    description:
      "Interoperabilidade e análise de fluxos clínicos, com atenção à comunicação, segurança e rastreabilidade.",
    technologies: ["DICOM", "HL7 FHIR", "Orthanc", "dcm4che", "Wireshark"],
  },
  {
    label: "Dispositivos e prototipagem",
    title: "Do componente ao protótipo",
    description:
      "Integração de sensores, eletrónica, desenho de PCB, modelação 3D e software num sistema biomédico.",
    technologies: ["Arduino", "HX711", "EasyEDA", "SolidWorks", "Impressão 3D"],
  },
];

const eegBars = [
  18, 30, 22, 46, 28, 62, 38, 52, 30, 72, 42, 56, 26, 48, 34, 66, 38, 52,
  24, 44, 32, 58, 28, 40,
];

export default function Home() {
  return (
    <>
      <a className="skip-link" href="#conteudo">
        Saltar para o conteúdo
      </a>

      <header className="site-header">
        <a
          className="brand"
          href="#inicio"
          aria-label="João Pedro Ribeiro dos Santos — início"
        >
          <span className="brand-mark">JP</span>
          <span className="brand-copy">
            <strong>João Pedro Ribeiro dos Santos</strong>
            <small>Engenharia Biomédica</small>
          </span>
        </a>

        <nav className="site-nav" aria-label="Navegação principal">
          <a href="#perfil">Perfil</a>
          <a href="#experiencia">Experiência</a>
          <a href="#projetos">Projetos</a>
          <a href="#formacao">Formação</a>
          <a href="#competencias">Competências</a>
        </nav>

        <a className="header-contact" href="#contacto">
          Contacto <span aria-hidden="true">↗</span>
        </a>
      </header>

      <main id="conteudo">
        <section className="hero" id="inicio" aria-labelledby="hero-title">
          <div className="hero-copy">
            <p className="eyebrow">
              <span /> Engenheiro Biomédico · Início de carreira
            </p>
            <h1 id="hero-title">
              Engenharia, dados e tecnologia <em>aplicados à saúde.</em>
            </h1>

            <div className="hero-intro">
              <p className="hero-name">
                João Pedro
                <br />
                Ribeiro dos Santos
              </p>
              <div>
                <p className="hero-lead">
                  Licenciado em Engenharia Biomédica, com experiência curricular em
                  sinais EEG e projetos aplicados a sistemas clínicos, inteligência
                  artificial e dispositivos médicos. Procuro a primeira oportunidade
                  profissional na área para aprender, contribuir e crescer com uma equipa
                  experiente.
                </p>
                <div className="hero-actions">
                  <a
                    className="button button-primary"
                    href="#projetos"
                  >
                    Explorar projetos <span aria-hidden="true">↓</span>
                  </a>
                  <a
                    className="button button-secondary"
                    href="/joao-santos-curriculo.pdf"
                    download="Joao_Pedro_Santos_Curriculo.pdf"
                  >
                    Descarregar currículo <span aria-hidden="true">↓</span>
                  </a>
                </div>
              </div>
            </div>
          </div>

          <div className="portrait-column">
            <div className="portrait-frame">
              {/* A imagem nativa evita uma incompatibilidade do otimizador Next com Vinext. */}
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src="/joao-santos.jpg"
                alt="Retrato de João Pedro Ribeiro dos Santos"
                width="1380"
                height="2058"
                decoding="async"
                fetchPriority="high"
              />
            </div>
            <p className="portrait-ribbon">Aprender. Questionar. Melhorar.</p>
            <div className="portrait-orbit" aria-hidden="true" />
          </div>

          <div className="hero-note">
            <span className="availability-dot" aria-hidden="true" />
            <strong>Disponível para novas oportunidades</strong>
            <span>Sinais biomédicos · Software e dados · Dispositivos médicos</span>
          </div>
        </section>

        <section className="profile section" id="perfil" aria-labelledby="profile-title">
          <div className="section-label">
            <span>01</span> Perfil
          </div>
          <div className="profile-grid">
            <h2 id="profile-title">
              Pensamento analítico.
              <br />
              <em>Execução prática.</em>
            </h2>
            <div className="profile-copy">
              <p className="large-copy">
                Gosto de transformar problemas pouco claros em trabalho estruturado,
                testável e útil — sobretudo quando tecnologia e saúde se encontram.
              </p>
              <p>
                O estágio curricular e os projetos multidisciplinares deram-me contacto
                com análise de sinais, software, aprendizagem automática, sistemas
                clínicos e prototipagem. A experiência profissional fora da área
                acrescentou comunicação com clientes, responsabilidade e capacidade de
                manter qualidade sob pressão.
              </p>
            </div>
            <aside className="profile-facts" aria-label="Resumo profissional">
              <div>
                <span>Formação</span>
                <strong>Licenciatura concluída · 1.º ano de mestrado concluído</strong>
              </div>
              <div>
                <span>Foco</span>
                <strong>Dados, sistemas e tecnologia aplicada à saúde</strong>
              </div>
              <div>
                <span>Objetivo</span>
                <strong>Primeira função profissional em Engenharia Biomédica</strong>
              </div>
            </aside>
          </div>
        </section>

        <section className="work-method section" id="contributo" aria-labelledby="contribution-title">
          <div className="section-label">
            <span>02</span> Como contribuo
          </div>
          <div className="method-heading">
            <h2 id="contribution-title">
              Aprender depressa.
              <br />
              <em>Entregar com critério.</em>
            </h2>
            <p>
              A minha forma de trabalhar junta curiosidade, análise crítica e sentido de
              responsabilidade. Procuro perceber o problema, escolher o método adequado e
              tornar o resultado claro para outras pessoas.
            </p>
          </div>
          <div className="method-grid">
            {contributionPillars.map((pillar) => (
              <article key={pillar.number}>
                <span>{pillar.number}</span>
                <h3>{pillar.title}</h3>
                <p>{pillar.description}</p>
              </article>
            ))}
          </div>
        </section>

        <section
          className="experience section-dark"
          id="experiencia"
          aria-labelledby="experience-title"
        >
          <div className="section-label section-label-light">
            <span>03</span> Experiência em destaque
          </div>
          <div className="experience-heading">
            <div>
              <p className="eyebrow eyebrow-light">
                <span /> MediBrain · Estágio curricular · 2025
              </p>
              <h2 id="experience-title">
                Comparar métodos.
                <br />
                <em>Produzir evidência.</em>
              </h2>
            </div>
            <p>
              Estágio individual de quatro meses na Clínica MediBrain, em Vila do Conde,
              dedicado à comparação de estratégias automáticas de pré-processamento de
              sinais EEG. Classificação final de 15 valores.
            </p>
          </div>

          <div className="project-card">
            <div className="project-copy">
              <p className="project-kicker">Python · MNE · análise experimental</p>
              <h3>Comparação de pipelines de pré-processamento de EEG</h3>
              <ul>
                <li>
                  Implementei e comparei AutoReject, ICA com ICLabel e duas pipelines
                  híbridas.
                </li>
                <li>
                  Avaliei seis sinais EEG através de métricas de artefactos, inspeção
                  temporal e espectral, Brain Symmetry Index e tempo de execução.
                </li>
                <li>
                  No contexto analisado, ICA com ICLabel apresentou o melhor comportamento
                  global; AutoReject mostrou maior utilidade como refinamento local.
                </li>
              </ul>
            </div>
            <div className="eeg-panel" aria-label="Resumo visual da comparação de EEG">
              <div className="eeg-topline">
                <span>Avaliação comparativa</span>
                <span>EEG · 2025</span>
              </div>
              <div className="eeg-bars" aria-hidden="true">
                {eegBars.map((height, index) => (
                  <i key={`${height}-${index}`} style={{ height: `${height}%` }} />
                ))}
              </div>
              <div className="eeg-metrics">
                <span>
                  <strong>4</strong> estratégias
                </span>
                <span>
                  <strong>6</strong> sinais
                </span>
                <span>
                  <strong>15</strong> valores
                </span>
              </div>
              <div className="eeg-bands" aria-hidden="true">
                <span>AutoReject</span>
                <span>ICA + ICLabel</span>
                <span>Híbridas</span>
              </div>
            </div>
          </div>

          <div className="transferable-experience">
            <p className="transfer-number">Clientes</p>
            <div>
              <h3>Comunicação e execução sob pressão</h3>
              <p>
                A experiência profissional prolongada em contacto direto com clientes,
                conciliada com a formação académica, reforçou consistência, priorização e
                responsabilidade no trabalho diário.
              </p>
            </div>
            <p className="transfer-detail">
              Esta experiência complementa a base técnica com escuta, adaptação e atenção
              à qualidade do serviço.
            </p>
          </div>
        </section>

        <section className="projects section" id="projetos" aria-labelledby="projects-title">
          <div className="section-label">
            <span>04</span> Projetos
          </div>
          <div className="projects-heading">
            <h2 id="projects-title">
              Autoria clara.
              <br />
              <em>Evidência com contexto.</em>
            </h2>
            <p>
              Separo o trabalho pessoal dos projetos académicos e identifico o que foi
              realizado individualmente ou em equipa. Cada caso inclui a evidência que
              existe e os limites do que pode ser concluído.
            </p>
          </div>

          <nav className="project-index" aria-label="Tipos de projeto e política de publicação">
            <a href="#projetos-pessoais">
              <span>01</span>
              <strong>Projetos pessoais</strong>
              <small>Autoria individual e código próprio</small>
            </a>
            <a href="#projetos-academicos">
              <span>02</span>
              <strong>Académicos e coletivos</strong>
              <small>Contributos, resultados e limites</small>
            </a>
            <a href="#politica-publicacao">
              <span>03</span>
              <strong>Publicação responsável</strong>
              <small>Resumos antes de artefactos</small>
            </a>
          </nav>

          <div className="project-collection" id="projetos-pessoais">
            <div className="collection-heading">
              <div>
                <p>Projetos pessoais</p>
                <h3>Autoria individual</h3>
              </div>
              <p>
                Trabalho em que assumo a decisão, a revisão e a responsabilidade pelo
                que é publicado.
              </p>
            </div>

            <div className="projects-grid projects-grid-personal">
              {personalProjects.map((project) => (
                <article className="curricular-project" id={project.id} key={project.title}>
                  <div className="project-meta">
                    <span>{project.number}</span>
                    <p>{project.context}</p>
                  </div>
                  <p className="publication-status">{project.publication}</p>
                  <h3>{project.title}</h3>
                  <p className="project-summary">{project.summary}</p>
                  <p className="project-contribution">{project.contribution}</p>
                  <div className="project-evidence">
                    <span>Evidência verificável</span>
                    <p>{project.evidence}</p>
                  </div>
                  <ul className="technology-tags" aria-label={`Áreas e tecnologias de ${project.title}`}>
                    {project.topics.map((topic) => (
                      <li key={topic}>{topic}</li>
                    ))}
                  </ul>
                  <p className="project-note">
                    <strong>Limite:</strong> {project.boundary}
                  </p>
                  {project.repositoryUrl ? (
                    <a
                      className="project-link"
                      href={project.repositoryUrl}
                      rel="noreferrer"
                      target="_blank"
                    >
                      Ver repositório <span aria-hidden="true">↗</span>
                    </a>
                  ) : null}
                </article>
              ))}
            </div>
          </div>

          <div className="project-collection" id="projetos-academicos">
            <div className="collection-heading">
              <div>
                <p>Projetos académicos e curriculares</p>
                <h3>Trabalho individual e em equipa</h3>
              </div>
              <p>
                Os resumos distinguem o meu contributo documentado do resultado coletivo
                e não apresentam protótipos académicos como sistemas clínicos validados.
              </p>
            </div>

            <div className="projects-grid">
              {academicProjects.map((project) => (
                <article className="curricular-project" id={project.id} key={project.title}>
                  <div className="project-meta">
                    <span>{project.number}</span>
                    <p>{project.context}</p>
                  </div>
                  <p className="publication-status">{project.publication}</p>
                  <h3>{project.title}</h3>
                  <p className="project-summary">{project.summary}</p>
                  <p className="project-contribution">{project.contribution}</p>
                  <div className="project-evidence">
                    <span>Evidência disponível</span>
                    <p>{project.evidence}</p>
                  </div>
                  <ul className="technology-tags" aria-label={`Áreas e tecnologias de ${project.title}`}>
                    {project.topics.map((topic) => (
                      <li key={topic}>{topic}</li>
                    ))}
                  </ul>
                  <p className="project-note">
                    <strong>Limite:</strong> {project.boundary}
                  </p>
                </article>
              ))}
            </div>
          </div>

          <aside className="publication-policy" id="politica-publicacao">
            <p className="publication-policy-label">Política de publicação</p>
            <h3>Um resumo público não autoriza os artefactos originais.</h3>
            <p>
              Código, relatórios, dados e materiais de equipa só serão ligados depois de
              uma revisão individual de confidencialidade, dados pessoais, metadados,
              licenças e direitos dos colegas e das instituições. Projetos ainda privados
              ou sem decisão de publicação não aparecem nesta seleção.
            </p>
          </aside>
        </section>

        <section className="education section" id="formacao" aria-labelledby="education-title">
          <div className="section-label">
            <span>05</span> Formação
          </div>
          <div className="education-layout">
            <div>
              <h2 id="education-title">
                Base sólida,
                <br />
                <em>evolução contínua.</em>
              </h2>
              <p className="education-summary">
                A formação prática no ISEP habituou-me a cruzar engenharia, programação e
                ciências da saúde, aprendendo através de projetos e problemas concretos.
              </p>
            </div>
            <ol className="timeline">
              <li>
                <div className="timeline-date">1.º ano concluído</div>
                <div>
                  <h3>Mestrado em Engenharia Biomédica</h3>
                  <p>Instituto Superior de Engenharia do Porto</p>
                  <small>
                    Projetos em sistemas clínicos, segurança e apoio à decisão.
                  </small>
                </div>
              </li>
              <li>
                <div className="timeline-date">Concluída em 2026</div>
                <div>
                  <h3>Licenciatura em Engenharia Biomédica</h3>
                  <p>Instituto Superior de Engenharia do Porto</p>
                  <small>
                    Formação multidisciplinar em engenharia, programação e ciências da saúde.
                  </small>
                </div>
              </li>
            </ol>
          </div>
        </section>

        <section
          className="technical-section section-dark"
          id="competencias"
          aria-labelledby="technical-title"
        >
          <div className="section-label section-label-light">
            <span>06</span> Competências demonstradas
          </div>
          <div className="technical-layout">
            <div>
              <p className="eyebrow eyebrow-light">
                <span /> Tecnologia ao serviço do problema
              </p>
              <h2 id="technical-title">
                Capacidade técnica
                <br />
                <em>com contexto.</em>
              </h2>
            </div>
            <div className="technical-intro">
              <p>
                As competências abaixo não são palavras-chave isoladas. Foram aplicadas
                no estágio curricular ou em projetos académicos, com níveis de autonomia
                e responsabilidade proporcionais a cada contexto.
              </p>
            </div>
          </div>

          <div className="technical-grid">
            {technicalAreas.map((area) => (
              <article key={area.label}>
                <span>{area.label}</span>
                <h3>{area.title}</h3>
                <p>{area.description}</p>
                <ul className="technology-tags technology-tags-dark">
                  {area.technologies.map((technology) => (
                    <li key={technology}>{technology}</li>
                  ))}
                </ul>
              </article>
            ))}
          </div>

          <blockquote className="technical-statement">
            A ferramenta muda consoante o problema; o critério mantém-se: compreender,
            testar, documentar e comunicar o resultado com rigor.
          </blockquote>
        </section>

        <section className="contact" id="contacto" aria-labelledby="contact-title">
          <div className="contact-copy">
            <p className="eyebrow eyebrow-light">
              <span /> Vamos conversar
            </p>
            <h2 id="contact-title">
              Procuro uma equipa onde possa <em>aprender e contribuir.</em>
            </h2>
            <p>
              Estou disponível para uma primeira oportunidade em Engenharia Biomédica e
              aberto a funções que liguem tecnologia, dados, dispositivos e saúde.
            </p>
          </div>
          <div className="contact-links">
            <a href="mailto:jpsantos222@gmail.com">
              <span>E-mail</span>
              <strong>jpsantos222@gmail.com</strong>
              <i aria-hidden="true">↗</i>
            </a>
            <a
              href="https://www.linkedin.com/in/jo%C3%A3o-santos-3842bb17a"
              rel="me"
            >
              <span>LinkedIn</span>
              <strong>joão-santos-3842bb17a</strong>
              <i aria-hidden="true">↗</i>
            </a>
            <a
              href="/joao-santos-curriculo.pdf"
              download="Joao_Pedro_Santos_Curriculo.pdf"
            >
              <span>Currículo</span>
              <strong>Descarregar PDF</strong>
              <i aria-hidden="true">↓</i>
            </a>
          </div>
        </section>
      </main>

      <footer>
        <p>João Pedro Ribeiro dos Santos · Engenharia Biomédica</p>
        <p>Portefólio profissional · 2026</p>
        <a href="#inicio">Voltar ao início ↑</a>
      </footer>
    </>
  );
}
