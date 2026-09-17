# Identidade visual — Sobe e Desce

Logótipo original criado em 8 de setembro de 2026 com a ferramenta integrada de geração de imagens do Codex, usando a skill `imagegen`. Não foi utilizada a CLI nem uma chave de API externa.

A carta de copas associa a marca ao jogo; as duas setas representam subir e descer. Bordô, creme e verde acompanham a paleta da aplicação. O símbolo não contém texto para manter a leitura em tamanho pequeno.

- `sobe-e-desce-logo-source.png`: imagem original gerada, preservada sem alterações.
- `../SobeEDesce/Assets.xcassets/AppIcon.appiconset/AppIcon.png`: ícone 1024 × 1024, RGB opaco, redimensionado com `sips`. Os cantos são aplicados pelo iOS.
- `../SobeEDesce/Assets.xcassets/AppLogo.imageset/AppLogo.png`: versão 384 × 384 para apresentação dentro da aplicação.

Foi verificada visualmente a composição, incluindo a direção das setas e a ausência de texto. As dimensões e ausência de transparência dos PNG de produção foram confirmadas com `sips`.

## Prompt final

```text
Use case: logo-brand
Asset type: production-ready square iOS app icon and in-app logo for the Portuguese card-score app Sobe e Desce.
Primary request: create one original, polished, instantly recognizable symbol combining a heart-suit playing card and the idea of going up and down.
Scene/backdrop: completely opaque deep burgundy background (#731421), extending all the way to every pixel of the square canvas.
Subject: one bold warm-ivory playing card, subtly tilted, bearing a single large burgundy heart in its center. A thick upward arrow and a thick downward arrow form a balanced paired motif alongside the card; use the same warm ivory for the arrows, with a restrained dark felt-green detail or card edge.
Style/medium: beautifully clean, flat graphic illustration, simple solid shapes, crisply defined edges, premium traditional card-game character with modern restraint.
Composition/framing: centered compact mark, generous outer safety margins, silhouette readable at 40 pixels. The card and two arrows are clearly separated, no fine lines.
Color palette: burgundy #731421, warm ivory #FAF5E6, felt green #144736. Strong ivory/burgundy contrast.
Constraints: a full-bleed square image, ideally 1024 by 1024. NO text, letters, numbers or ranks. NO mockup, NO device, NO outer border. Do not draw rounded corners of the app icon; iOS applies its own mask. No shadows, gradients, lighting, texture, watermark, or extra decorative symbols. Only the one heart card and two opposite-direction arrows.
```
