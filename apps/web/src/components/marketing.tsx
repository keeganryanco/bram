import Link from "next/link";
import { appStoreURL, bramReviews, siteURL, type Article } from "@/lib/marketing-content";

export function JsonLd({ data }: { data: Record<string, unknown> }) {
  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(data) }}
    />
  );
}

export function SectionHeader({
  title,
  eyebrow,
  description,
}: {
  title: string;
  eyebrow?: string;
  description?: string;
}) {
  return (
    <div className="mx-auto max-w-3xl text-center">
      {eyebrow ? (
        <p className="text-sm font-semibold uppercase tracking-[0.12em] text-[var(--violet)]">
          {eyebrow}
        </p>
      ) : null}
      <h2 className="mt-3 text-balance text-4xl font-semibold leading-[1.02] tracking-normal text-[var(--foreground)] sm:text-5xl">
        {title}
      </h2>
      {description ? (
        <p className="mt-5 text-pretty text-lg leading-8 text-[var(--muted)]">
          {description}
        </p>
      ) : null}
    </div>
  );
}

export function ScreenshotPlaceholder({ label }: { label: string }) {
  return (
    <div className="flex aspect-[4/5] min-h-[220px] items-center justify-center rounded-lg border border-dashed border-[rgba(93,90,247,0.34)] bg-[linear-gradient(145deg,#fffdf8,#eee8dc)] p-6 text-center shadow-inner">
      <div>
        <div className="mx-auto mb-4 h-16 w-16 rounded-[22px] bg-[var(--charcoal)] shadow-[0_14px_34px_rgba(35,38,44,0.18)]" />
        <p className="text-sm font-semibold leading-5 text-[var(--muted)]">
          {label}
        </p>
      </div>
    </div>
  );
}

export function ReviewCard({
  title,
  author,
  date,
  quote,
}: {
  title: string;
  author: string;
  date: string;
  quote: string;
}) {
  return (
    <figure className="rounded-lg bg-[var(--charcoal)] p-6 text-white shadow-[0_20px_60px_rgba(35,38,44,0.16)]">
      <div className="flex items-start justify-between gap-4">
        <div>
          <figcaption className="text-lg font-semibold">{title}</figcaption>
          <p className="mt-1 text-base tracking-[0.08em] text-[#ffac2f]">
            ★★★★★
          </p>
        </div>
        <p className="text-right text-sm font-medium leading-5 text-white/55">
          {date}
          <br />
          {author}
        </p>
      </div>
      <blockquote className="mt-8 text-lg leading-8 text-white/82">
        “{quote}”
      </blockquote>
    </figure>
  );
}

export function FAQList({
  faqs,
}: {
  faqs: Array<{ question: string; answer: string }>;
}) {
  return (
    <div className="mx-auto grid max-w-4xl gap-4">
      {faqs.map((faq) => (
        <details
          key={faq.question}
          className="group rounded-lg border border-[var(--border)] bg-[var(--cream-panel)] p-5 shadow-[0_14px_44px_rgba(35,38,44,0.05)]"
        >
          <summary className="flex cursor-pointer list-none items-center justify-between gap-4 text-lg font-semibold text-[var(--foreground)]">
            {faq.question}
            <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-[rgba(93,90,247,0.1)] text-[var(--violet)] transition group-open:rotate-45">
              +
            </span>
          </summary>
          <p className="mt-4 max-w-3xl text-base leading-7 text-[var(--muted)]">
            {faq.answer}
          </p>
        </details>
      ))}
    </div>
  );
}

export function CTASection() {
  return (
    <section className="rounded-lg bg-[var(--charcoal)] px-6 py-10 text-center text-white shadow-[0_24px_80px_rgba(35,38,44,0.16)] sm:px-10">
      <p className="brand-wordmark text-4xl text-[var(--violet)]">Bram</p>
      <h2 className="mx-auto mt-5 max-w-2xl text-balance text-4xl font-semibold leading-tight tracking-normal">
        Start simple. Get stronger.
      </h2>
      <p className="mx-auto mt-4 max-w-2xl text-lg leading-8 text-white/70">
        Write your workout. Bram tracks the rest.
      </p>
      <Link
        href={appStoreURL}
        target="_blank"
        rel="noopener noreferrer"
        className="mt-7 inline-flex min-h-13 items-center justify-center rounded-full bg-white px-7 text-base font-semibold text-[var(--charcoal)] transition hover:-translate-y-0.5 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-white"
      >
        Download from App Store
      </Link>
    </section>
  );
}

export function ComparisonTable({
  comparison,
}: {
  comparison: NonNullable<Article["comparison"]>;
}) {
  return (
    <div className="overflow-hidden rounded-lg border border-[var(--border)] bg-[var(--cream-panel)]">
      <div className="grid gap-0 sm:hidden">
        {comparison.rows.map((row) => (
          <div
            key={row.join("|")}
            className="grid gap-4 border-b border-[var(--border)] p-4 last:border-0"
          >
            {row.map((cell, index) => (
              <div key={`${comparison.columns[index]}-${cell}`}>
                <p className="text-xs font-semibold uppercase tracking-[0.1em] text-[var(--muted)]">
                  {comparison.columns[index]}
                </p>
                <p
                  className={`mt-1 text-base leading-7 ${
                    index === row.length - 1
                      ? "font-semibold text-[var(--foreground)]"
                      : "text-[var(--muted)]"
                  }`}
                >
                  {cell}
                </p>
              </div>
            ))}
          </div>
        ))}
      </div>
      <table className="hidden w-full border-collapse text-left text-base sm:table">
        <thead className="bg-white/60">
          <tr>
            {comparison.columns.map((column) => (
              <th
                key={column}
                className="border-b border-[var(--border)] px-4 py-4 font-semibold text-[var(--foreground)] sm:px-5"
              >
                {column}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {comparison.rows.map((row) => (
            <tr key={row.join("|")} className="border-b border-[var(--border)] last:border-0">
              {row.map((cell, index) => (
                <td
                  key={cell}
                  className={`px-4 py-4 align-top leading-7 sm:px-5 ${
                    index === row.length - 1
                      ? "font-medium text-[var(--foreground)]"
                      : "text-[var(--muted)]"
                  }`}
                >
                  {cell}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function ArticleLayout({ article }: { article: Article }) {
  const relatedArticles = article.related;
  const canonical = `${siteURL}/${article.slug}`;
  const faqSchema = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: article.faqs.map((faq) => ({
      "@type": "Question",
      name: faq.question,
      acceptedAnswer: {
        "@type": "Answer",
        text: faq.answer,
      },
    })),
  };

  const articleSchema = {
    "@context": "https://schema.org",
    "@type": "Article",
    headline: article.title,
    description: article.description,
    dateModified: "2026-06-02",
    datePublished: "2026-06-02",
    author: {
      "@type": "Organization",
      name: "Bram",
    },
    publisher: {
      "@type": "Organization",
      name: "Bram",
      url: siteURL,
    },
    mainEntityOfPage: canonical,
  };

  const breadcrumbSchema = {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: [
      {
        "@type": "ListItem",
        position: 1,
        name: "Bram",
        item: siteURL,
      },
      {
        "@type": "ListItem",
        position: 2,
        name: article.title,
        item: canonical,
      },
    ],
  };

  return (
    <main className="min-h-screen bg-[var(--background)] px-5 py-8 text-[var(--foreground)] sm:px-8">
      <JsonLd data={articleSchema} />
      <JsonLd data={faqSchema} />
      <JsonLd data={breadcrumbSchema} />

      <article className="mx-auto max-w-5xl">
        <header>
          <Link
            href="/"
            className="brand-wordmark text-2xl text-[var(--violet)]"
            aria-label="Bram home"
          >
            Bram
          </Link>
          <div className="mt-14 max-w-3xl">
            <p className="text-sm font-semibold uppercase tracking-[0.12em] text-[var(--violet)]">
              Workout Notes
            </p>
            <h1 className="mt-4 text-balance text-5xl font-semibold leading-[0.98] tracking-normal sm:text-6xl">
              {article.title}
            </h1>
            <p className="mt-6 text-xl leading-9 text-[var(--muted)]">
              {article.intro}
            </p>
            <p className="mt-5 text-sm font-medium text-[var(--muted)]">
              Updated {article.updated}
            </p>
          </div>
        </header>

        <section className="mt-12 rounded-lg border border-[var(--border)] bg-[var(--cream-panel)] p-6 shadow-[0_16px_54px_rgba(35,38,44,0.07)] sm:p-8">
          <p className="text-sm font-semibold uppercase tracking-[0.12em] text-[var(--muted)]">
            Quick verdict
          </p>
          <p className="mt-4 text-2xl font-semibold leading-snug tracking-normal text-[var(--foreground)]">
            {article.verdict}
          </p>
        </section>

        <div className="mt-12 grid gap-12 lg:grid-cols-[1fr_280px] lg:items-start">
          <div className="space-y-12">
            {article.sections.map((section) => (
              <section key={section.heading}>
                <h2 className="text-3xl font-semibold tracking-normal text-[var(--foreground)]">
                  {section.heading}
                </h2>
                <div className="mt-5 space-y-5 text-lg leading-8 text-[var(--muted)]">
                  {section.body.map((paragraph) => (
                    <p key={paragraph}>{paragraph}</p>
                  ))}
                </div>
              </section>
            ))}

            {article.comparison ? (
              <section>
                <h2 className="text-3xl font-semibold tracking-normal text-[var(--foreground)]">
                  Side-by-side comparison
                </h2>
                <div className="mt-6">
                  <ComparisonTable comparison={article.comparison} />
                </div>
              </section>
            ) : null}

            <section>
              <h2 className="text-3xl font-semibold tracking-normal text-[var(--foreground)]">
                FAQ
              </h2>
              <div className="mt-6">
                <FAQList faqs={article.faqs} />
              </div>
            </section>

            <section>
              <h2 className="text-3xl font-semibold tracking-normal text-[var(--foreground)]">
                Sources and context
              </h2>
              <div className="mt-5 space-y-4 text-base leading-7 text-[var(--muted)]">
                <p>
                  Competitor context is based on public product pages from{" "}
                  <a className="font-semibold text-[var(--violet)]" href="https://hevy.com/pricing">
                    Hevy
                  </a>
                  ,{" "}
                  <a className="font-semibold text-[var(--violet)]" href="https://www.strong.app/?lang=en">
                    Strong
                  </a>
                  , and{" "}
                  <a className="font-semibold text-[var(--violet)]" href="https://www.gymnoteplus.com/">
                    Gym Note Plus
                  </a>
                  . Bram positioning is intentionally focused on notes-style logging rather than copying traditional tracker workflows.
                </p>
              </div>
            </section>
          </div>

          <aside className="sticky top-8 hidden rounded-lg border border-[var(--border)] bg-[var(--cream-panel)] p-5 lg:block">
            <p className="text-sm font-semibold uppercase tracking-[0.12em] text-[var(--muted)]">
              Related
            </p>
            <nav className="mt-4 grid gap-3 text-sm font-semibold leading-5">
              {relatedArticles.map((slug) => (
                <Link
                  key={slug}
                  href={`/${slug}`}
                  className="text-[var(--foreground)] transition hover:text-[var(--violet)]"
                >
                  {slug
                    .split("-")
                    .map((word) => word[0].toUpperCase() + word.slice(1))
                    .join(" ")}
                </Link>
              ))}
            </nav>
            <Link
              href={appStoreURL}
              target="_blank"
              rel="noopener noreferrer"
              className="mt-6 inline-flex w-full items-center justify-center rounded-full bg-[var(--foreground)] px-4 py-3 text-sm font-semibold text-[var(--background)] transition hover:-translate-y-0.5"
            >
              Try Bram
            </Link>
          </aside>
        </div>

        <div className="mt-16">
          <CTASection />
        </div>

        <section className="mt-14">
          <SectionHeader
            eyebrow="App Store reviews"
            title="Lifters are already noticing the simplicity."
            description="Bram is 5.0 out of 5 on the App Store from its first 2 ratings."
          />
          <div className="mt-8 grid gap-4 md:grid-cols-2">
            {bramReviews.map((review) => (
              <ReviewCard key={review.title} {...review} />
            ))}
          </div>
        </section>
      </article>
    </main>
  );
}
