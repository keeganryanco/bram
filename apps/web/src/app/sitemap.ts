import type { MetadataRoute } from "next";
import { articles, siteURL } from "@/lib/marketing-content";

export default function sitemap(): MetadataRoute.Sitemap {
  const staticRoutes = ["", "/privacy", "/terms", "/press"].map((path) => ({
    url: `${siteURL}${path}`,
    lastModified: new Date("2026-06-02"),
  }));

  const articleRoutes = articles.map((article) => ({
    url: `${siteURL}/${article.slug}`,
    lastModified: new Date("2026-06-02"),
  }));

  return [...staticRoutes, ...articleRoutes];
}
