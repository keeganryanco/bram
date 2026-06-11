import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { ArticleLayout } from "@/components/marketing";
import { WorkoutUtilityPage } from "@/components/workout-utility";
import { articleBySlug, articles, siteURL } from "@/lib/marketing-content";
import {
  utilityPageBySlug,
  utilityPages,
} from "@/lib/utility-content";

type PageProps = {
  params: Promise<{
    slug: string;
  }>;
};

export function generateStaticParams() {
  return [...articles, ...utilityPages].map((page) => ({
    slug: page.slug,
  }));
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { slug } = await params;
  const article = articleBySlug.get(slug);
  const utilityPage = utilityPageBySlug.get(slug);

  if (!article && !utilityPage) {
    return {};
  }

  const page = article ?? utilityPage;

  if (!page) {
    return {};
  }

  const canonical = `${siteURL}/${page.slug}`;

  return {
    title: page.title,
    description: page.description,
    keywords: page.keywords,
    alternates: {
      canonical,
    },
    openGraph: {
      title: page.title,
      description: page.description,
      url: canonical,
      siteName: "Bram",
      type: article ? "article" : "website",
      images: [
        {
          url: "/bram-icon.png",
          width: 1024,
          height: 1024,
          alt: "Bram app icon",
        },
      ],
    },
  };
}

export default async function MarketingArticlePage({ params }: PageProps) {
  const { slug } = await params;
  const article = articleBySlug.get(slug);
  const utilityPage = utilityPageBySlug.get(slug);

  if (utilityPage) {
    return <WorkoutUtilityPage utility={utilityPage} />;
  }

  if (!article) {
    notFound();
  }

  return <ArticleLayout article={article} />;
}
