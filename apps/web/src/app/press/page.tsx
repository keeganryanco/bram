import Link from "next/link";

export const metadata = {
  title: "Press",
  description:
    "Bram is a notes-first workout tracker for lifters who want the ease of Apple Notes with real progress tracking.",
};

const facts = [
  ["Product", "Bram - Workout Notes"],
  ["Category", "Health & Fitness"],
  ["Launch Date", "May 22, 2026"],
  ["Founder", "Keegan Ryan"],
  ["Website", "trybram.app"],
  ["Contact", "support@trybram.app"],
];

export default function PressPage() {
  return (
    <main className="min-h-screen bg-[var(--background)] px-5 py-8 text-[var(--foreground)] sm:px-8">
      <article className="mx-auto grid max-w-5xl gap-10 lg:grid-cols-[1fr_320px] lg:gap-16">
        <section>
          <Link
            href="/"
            className="brand-wordmark text-2xl text-[var(--violet)]"
            aria-label="Bram home"
          >
            Bram
          </Link>

          <p className="mt-14 text-sm font-semibold uppercase tracking-[0.12em] text-[var(--violet)]">
            Press
          </p>
          <h1 className="mt-4 max-w-3xl text-balance text-5xl font-semibold leading-[0.98] tracking-normal sm:text-6xl">
            Bram is a notes-first workout tracker for lifters.
          </h1>

          <div className="mt-10 space-y-7 text-lg leading-8 text-[var(--muted)]">
            <p>
              Bram is a notes-first workout tracker for lifters who want the
              ease of Apple Notes with real progress tracking.
            </p>
            <p>
              Built by solo founder Keegan Ryan, Bram was created around one
              simple question: what if the easiest workout tracker was also the
              one that remembered your progress?
            </p>
            <p>
              Instead of forcing users into complex routines, social feeds, or
              spreadsheet-style logging, Bram lets lifters write naturally —
              “bench 185 for 5, incline 70s for 8, shoulders felt tired” — and
              turns those notes into structured training history, PRs, weekly
              progress, set volume, streaks, and simple insights.
            </p>
            <p>
              Bram launches as a calm, premium iPhone app with a dark minimal
              interface, Apple Health context, and a distinctive black bear
              companion. It is built for self-directed lifters who already know
              how they train, but want their workouts remembered without adding
              friction.
            </p>
          </div>

          <section className="mt-12 rounded-[28px] border border-[var(--border)] bg-[var(--cream-panel)] p-7 shadow-[0_20px_70px_rgba(35,38,44,0.08)]">
            <p className="text-sm font-semibold uppercase tracking-[0.12em] text-[var(--muted)]">
              Core idea
            </p>
            <p className="mt-4 text-3xl font-semibold leading-tight tracking-normal text-[var(--foreground)]">
              Write your workout. Bram tracks the rest.
            </p>
          </section>
        </section>

        <aside className="lg:pt-32">
          <div className="rounded-[28px] border border-[var(--border)] bg-[var(--charcoal)] p-6 text-white shadow-[0_22px_80px_rgba(35,38,44,0.18)]">
            <h2 className="text-xl font-semibold tracking-normal">
              Press facts
            </h2>
            <dl className="mt-6 space-y-5">
              {facts.map(([label, value]) => (
                <div key={label}>
                  <dt className="text-xs font-semibold uppercase tracking-[0.12em] text-white/45">
                    {label}
                  </dt>
                  <dd className="mt-1 text-base font-medium text-white">
                    {label === "Website" ? (
                      <a
                        href="https://trybram.app"
                        className="transition hover:text-white/75"
                      >
                        {value}
                      </a>
                    ) : label === "Contact" ? (
                      <a
                        href="mailto:support@trybram.app"
                        className="transition hover:text-white/75"
                      >
                        {value}
                      </a>
                    ) : (
                      value
                    )}
                  </dd>
                </div>
              ))}
            </dl>
          </div>
        </aside>
      </article>
    </main>
  );
}
