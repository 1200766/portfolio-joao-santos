import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { access, readFile } from "node:fs/promises";
import test from "node:test";

const projectRoot = new URL("../", import.meta.url);

async function render(path = "/") {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}-${path}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request(`https://joao-santos-biomedica.joaprs.chatgpt.site${path}`, {
      headers: { accept: "text/html" },
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );
}

test("apresenta o portefólio profissional e a evidência principal", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);
  assert.equal(response.headers.get("x-content-type-options"), "nosniff");
  assert.equal(response.headers.get("x-frame-options"), "SAMEORIGIN");
  assert.equal(
    response.headers.get("referrer-policy"),
    "strict-origin-when-cross-origin",
  );
  assert.equal(
    response.headers.get("permissions-policy"),
    "camera=(), microphone=(), geolocation=()",
  );

  const html = await response.text();
  assert.match(html, /<html[^>]+lang=["']pt-PT["']/i);
  assert.match(html, /<title>João Santos \| Engenharia Biomédica, dados e sistemas de saúde<\/title>/i);
  assert.match(html, /Engenharia, dados e tecnologia/);
  assert.match(html, /Comparação de pipelines de pré-processamento de EEG/);
  assert.match(html, /PrediPE/);
  assert.match(html, /Segurança Web e DICOM/);
  assert.match(html, /Platink — prato inteligente/);
  assert.match(html, /SafeHealth/);
  assert.match(html, /PIMED — imagem médica 3D/);
  assert.match(html, /Projetos pessoais/);
  assert.match(html, /Projetos académicos e curriculares/);
  assert.match(html, /Resumo sanitizado/);
  assert.match(html, /href=["']#projetos["']/i);
  assert.match(html, /href=["']mailto:jpsantos222@gmail\.com/i);
  assert.match(
    html,
    /href=["']https:\/\/www\.linkedin\.com\/in\/jo%C3%A3o-santos-3842bb17a["']/i,
  );
  assert.match(
    html,
    /href=["']https:\/\/github\.com\/1200766\/portfolio-joao-santos["']/i,
  );
  assert.match(html, /href=["']\/joao-santos-curriculo\.pdf["']/i);
  assert.match(html, /download=["']Joao_Pedro_Santos_Curriculo\.pdf["']/i);
});

test("respeita a política pública de contactos e afirmações", async () => {
  const response = await render();
  const html = await response.text();

  assert.doesNotMatch(html, /href=["']tel:/i);
  assert.match(html, /Engenheiro Biomédico · Início de carreira/);
  assert.doesNotMatch(html, /2025\s*(?:—|-)\s*presente/i);
  assert.doesNotMatch(html, /2020\s*(?:—|-)\s*2026/i);
  assert.doesNotMatch(html, /data de nascimento/i);
  assert.doesNotMatch(html, /automati[sz](?:ar|o).*e-?mail/i);
});

test("publica metadados de descoberta com a origem canónica", async () => {
  const [robotsResponse, sitemapResponse] = await Promise.all([
    render("/robots.txt"),
    render("/sitemap.xml"),
  ]);

  assert.equal(robotsResponse.status, 200);
  assert.match(await robotsResponse.text(), /User-Agent:\s*\*/i);
  assert.equal(sitemapResponse.status, 200);
  assert.match(
    await sitemapResponse.text(),
    /https:\/\/joao-santos-biomedica\.joaprs\.chatgpt\.site/,
  );

  const layout = await readFile(new URL("../app/layout.tsx", import.meta.url), "utf8");
  assert.match(layout, /alternates:\s*\{/);
  assert.match(layout, /application\/ld\+json/);
  assert.doesNotMatch(layout, /x-forwarded-host|x-forwarded-proto/i);
  assert.doesNotMatch(layout, /PostalAddress|addressRegion|addressCountry/);
});

test("mantém disponíveis os ativos visuais e o currículo selecionado", async () => {
  const [, , curriculum] = await Promise.all([
    access(new URL("public/joao-santos.jpg", projectRoot)),
    access(new URL("public/og.png", projectRoot)),
    readFile(new URL("public/joao-santos-curriculo.pdf", projectRoot)),
  ]);

  assert.equal(
    createHash("sha256").update(curriculum).digest("hex"),
    "71d7565ec21b6b55c71834051e89a514db2e5f938ef6627eb84dda6d0f0141e3",
  );
});
