/* eslint-disable @next/next/no-img-element -- The curated catalogue uses original static image paths. */

import Link from "next/link";
import seedItems from "../data/clothes.json";

const coverPhotos = [
  seedItems[7].photos[0],
  seedItems[21].photos[1],
  seedItems[5].photos[0],
  seedItems[27].photos[0],
  seedItems[8].photos[1],
];

const photoCount = seedItems.reduce(
  (total, item) => total + item.photos.length,
  0,
);

export default function Home() {
  return (
    <main className="home-page">
      <nav className="site-nav" aria-label="Navegação principal">
        <Link className="brand-mark" href="/">
          <span className="brand-dot" aria-hidden="true" />
          Segunda Volta
        </Link>
        <Link className="nav-link" href="/catalogo">
          Ver inventário <span aria-hidden="true">↗</span>
        </Link>
      </nav>

      <section className="hero">
        <div className="hero-copy">
          <p className="eyebrow">O teu armário, pronto para vender</p>
          <h1>
            Dar uma segunda vida começa por{" "}
            <span className="headline-highlight">organizar.</span>
          </h1>
          <p className="hero-lede">
            Todas as tuas peças, fotografias e detalhes num só lugar. Revê,
            completa e prepara o inventário ao teu ritmo.
          </p>
          <Link className="primary-cta" href="/catalogo">
            Começar a ver a roupa
            <span className="cta-arrow" aria-hidden="true">
              →
            </span>
          </Link>
          <div className="hero-stats" aria-label="Resumo do inventário">
            <div>
              <strong>{seedItems.length}</strong>
              <span>peças organizadas</span>
            </div>
            <div>
              <strong>{photoCount}</strong>
              <span>fotografias</span>
            </div>
            <div>
              <strong>5</strong>
              <span>detalhes por peça</span>
            </div>
          </div>
        </div>

        <div className="hero-gallery" aria-label="Amostra da coleção">
          {coverPhotos.map((photo, index) => (
            <figure className={`hero-card hero-card-${index + 1}`} key={photo}>
              <img
                src={photo}
                alt=""
                loading={index > 1 ? "lazy" : "eager"}
              />
              {index === 0 ? (
                <figcaption>
                  <span>Pronta para catalogar</span>
                  <span aria-hidden="true">↗</span>
                </figcaption>
              ) : null}
            </figure>
          ))}
          <div className="gallery-sticker" aria-hidden="true">
            <span>{photoCount}</span>
            fotografias
          </div>
        </div>
      </section>

      <section className="home-footer">
        <p>Organiza hoje. Publica amanhã.</p>
        <span>Demonstração de portefólio · 2026</span>
      </section>
    </main>
  );
}
