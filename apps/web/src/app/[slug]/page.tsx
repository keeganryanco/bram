import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { ArticleLayout } from "@/components/marketing";
import { articleBySlug, articles, siteURL } from "@/lib/marketing-content";

type PageProps = {
  params: Promise<{
    slug: string;
  }>;
};

export function generateStaticParams() {
  return articles.map((article) => ({
    slug: article.slug,
  }));
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { slug } = await params;
  const article = articleBySlug.get(slug);

  if (!article) {
    return {};
  }

  const canonical = `${siteURL}/${article.slug}`;

  return {
    title: article.title,
    description: article.description,
    keywords: article.keywords,
    alternates: {
      canonical,
    },
    openGraph: {
      title: article.title,
      description: article.description,
      url: canonical,
      siteName: "Bram",
      type: "article",
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

  if (!article) {
    notFound();
  }

  return <ArticleLayout article={article} />;
}
