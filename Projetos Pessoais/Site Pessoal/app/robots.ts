import type { MetadataRoute } from "next";

const siteUrl = "https://joao-santos-biomedica.joaprs.chatgpt.site";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: "*",
      allow: "/",
    },
    sitemap: `${siteUrl}/sitemap.xml`,
  };
}
