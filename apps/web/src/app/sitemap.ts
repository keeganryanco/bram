import type { MetadataRoute } from "next";
import { articles, siteURL } from "@/lib/marketing-content";
import { utilityPages } from "@/lib/utility-content";

export default function sitemap(): MetadataRoute.Sitemap {
  const staticRoutes = ["", "/privacy", "/terms", "/press"].map((path) => ({
    url: `${siteURL}${path}`,
    lastModified: new Date("2026-06-02"),
  }));

  const articleRoutes = articles.map((article) => ({
    url: `${siteURL}/${article.slug}`,
    lastModified: new Date("2026-06-02"),
  }));
  const utilityRoutes = utilityPages.map((utilityPage) => ({
    url: `${siteURL}/${utilityPage.slug}`,
    lastModified: new Date("2026-06-11"),
  }));

  return [...staticRoutes, ...articleRoutes, ...utilityRoutes];
}
