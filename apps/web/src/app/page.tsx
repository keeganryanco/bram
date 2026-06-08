import Image from "next/image";
import Link from "next/link";
import {
  FAQList,
  JsonLd,
  ReviewCard,
  SectionHeader,
} from "@/components/marketing";
import {
  appStoreURL,
  bramReviews,
  homeFaq,
  homeFeatures,
  siteURL,
} from "@/lib/marketing-content";

const footerLinks = [
  { href: "/privacy", label: "Privacy Policy" },
  { href: "/terms", label: "Terms" },
  { href: "mailto:support@trybram.app", label: "Contact" },
];

export default function Home() {
  const softwareSchema = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: "Bram: Workout Notes",
    applicationCategory: "HealthApplication",
    operatingSystem: "iOS",
    url: siteURL,
    downloadUrl: appStoreURL,
    description:
      "Bram is a notes-style workout tracker for iPhone. Write your workout naturally and Bram tracks sets, reps, weights, PRs, volume, and progress.",
  };

  const faqSchema = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: homeFaq.map((faq) => ({
      "@type": "Question",
      name: faq.question,
      acceptedAnswer: {
        "@type": "Answer",
        text: faq.answer,
      },
    })),
  };

  return (
    <main className="relative bg-[var(--background)] text-[var(--foreground)]">
      <JsonLd data={softwareSchema} />
      <JsonLd data={faqSchema} />

      <div className="mx-auto grid min-h-[100svh] w-full max-w-6xl grid-rows-[auto_1fr] px-6 py-7 sm:px-8 lg:px-12">
        <header className="flex items-center justify-between">
          <Link
            href="/"
            className="brand-wordmark text-[34px] leading-none text-[var(--violet)] sm:text-[28px]"
            aria-label="Bram home"
          >
            Bram
          </Link>
        </header>

        <section className="grid min-h-0 content-start gap-10 pt-12 pb-8 md:content-center md:grid-cols-[1.05fr_0.95fr] md:items-center md:gap-12 md:py-4 lg:gap-20">
          <div className="max-w-xl">
            <h1 className="max-w-[12ch] text-balance text-[3.45rem] font-semibold leading-[0.94] tracking-normal text-[var(--foreground)] sm:max-w-[11ch] sm:text-[clamp(2.45rem,6vw,5.8rem)]">
              Get stronger without tracking harder.
            </h1>
            <p className="mt-6 max-w-[29rem] text-pretty text-[1.08rem] leading-7 text-[var(--muted)] sm:text-lg sm:leading-8">
              As easy as writing in Notes. Bram is smart enough to remember
              every lift, track your progress, and surface insights like a
              personal trainer.
            </p>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row sm:items-center">
              <Link
                href={appStoreURL}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex min-h-14 items-center justify-center rounded-full bg-[var(--foreground)] px-7 text-base font-semibold text-[var(--background)] shadow-[0_18px_44px_rgba(35,38,44,0.18)] transition hover:-translate-y-0.5 hover:bg-[var(--charcoal)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-[var(--violet)]"
                aria-label="Download Bram from the App Store"
              >
                Download from App Store
              </Link>
              <p className="text-sm font-medium text-[var(--muted)] sm:text-base">
                Get Bram for iOS.
              </p>
            </div>
          </div>

          <div className="flex justify-center md:justify-end">
            <div className="relative w-[min(72vw,245px)] max-w-[245px] overflow-hidden rounded-[32px] bg-[var(--charcoal)] shadow-[0_28px_80px_rgba(35,38,44,0.22)] ring-1 ring-black/10 sm:w-[min(54vw,275px)] md:w-[min(28vw,310px)] md:max-w-[310px]">
              <Image
                src="https://trybram.app/screenshots/hero_screenshot.png"
                alt="Bram iPhone workout notes screen"
                width={383}
                height={706}
                priority
                sizes="(max-width: 640px) 72vw, (max-width: 768px) 54vw, 310px"
                className="h-auto w-full"
              />
            </div>
          </div>
        </section>
      </div>

      <section className="px-6 py-16 sm:px-8 lg:px-12">
        <div className="mx-auto max-w-6xl">
          <SectionHeader
            eyebrow="Workout notes"
            title="As easy as Notes. Built for progress."
            description="Bram keeps the workout note fast, then turns it into the training history you actually wanted."
          />
          <div className="mt-12 grid gap-4 md:grid-cols-2 lg:grid-cols-4">
            {homeFeatures.map((feature) => (
              <article
                key={feature.title}
                className="rounded-lg border border-[var(--border)] bg-[var(--cream-panel)] p-4 shadow-[0_16px_54px_rgba(35,38,44,0.06)]"
              >
                <div className="relative aspect-[3/4] overflow-hidden rounded-md bg-[var(--background)]">
                  <Image
                    src={feature.image}
                    alt={feature.title}
                    fill
                    sizes="(max-width: 768px) calc(100vw - 64px), (max-width: 1024px) 44vw, 260px"
                    className="object-cover"
                  />
                </div>
                <h3 className="mt-5 text-xl font-semibold tracking-normal text-[var(--foreground)]">
                  {feature.title}
                </h3>
                <p className="mt-3 text-base leading-7 text-[var(--muted)]">
                  {feature.description}
                </p>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="px-6 py-16 sm:px-8 lg:px-12">
        <div className="mx-auto grid max-w-6xl gap-10 lg:grid-cols-[0.82fr_1.18fr] lg:items-center">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.12em] text-[var(--violet)]">
              App Store reviews
            </p>
            <h2 className="mt-4 text-balance text-4xl font-semibold leading-[1.02] tracking-normal sm:text-5xl">
              5.0 out of 5 on the App Store.
            </h2>
            <p className="mt-5 text-lg leading-8 text-[var(--muted)]">
              Bram is early, focused, and already highly rated by lifters who
              want workout tracking to feel simple.
            </p>
            <p className="mt-5 text-xl font-semibold text-[var(--foreground)]">
              ★★★★★
            </p>
          </div>
          <div className="grid gap-4 md:grid-cols-2">
            {bramReviews.map((review) => (
              <ReviewCard key={review.title} {...review} />
            ))}
          </div>
        </div>
      </section>

      <section className="px-6 py-16 sm:px-8 lg:px-12">
        <SectionHeader
          eyebrow="FAQ"
          title="Simple answers for a simple workout tracker."
          description="Bram is for lifters who want Apple Notes speed with progress tracking underneath."
        />
        <div className="mt-10">
          <FAQList faqs={homeFaq} />
        </div>
      </section>

      <footer className="flex items-center justify-center gap-7 px-6 py-8 text-sm font-medium text-[var(--muted)]">
          {footerLinks.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className="transition hover:text-[var(--foreground)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-[var(--violet)]"
            >
              {link.label}
            </Link>
          ))}
      </footer>
    </main>
  );
}
