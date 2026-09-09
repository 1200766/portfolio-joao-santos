import type { MetadataRoute } from "next";

const siteUrl = "https://joao-santos-biomedica.joaprs.chatgpt.site";

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: siteUrl,
      changeFrequency: "monthly",
      priority: 1,
    },
  ];
}
