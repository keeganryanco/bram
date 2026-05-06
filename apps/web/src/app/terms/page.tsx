import Link from "next/link";

export const metadata = {
  title: "Terms and Conditions",
};

export default function TermsPage() {
  return (
    <main className="min-h-screen bg-[var(--background)] px-5 py-8 text-[var(--foreground)] sm:px-8">
      <article className="mx-auto max-w-3xl">
        <Link
          href="/"
          className="brand-wordmark text-2xl text-[var(--violet)]"
        >
          Bram
        </Link>
        <h1 className="mt-12 text-4xl font-semibold tracking-normal">
          Terms and Conditions
        </h1>
        <p className="mt-3 text-sm font-medium text-[var(--muted)]">
          Draft for app submission review. Last updated May 6, 2026.
        </p>

        <div className="mt-10 space-y-8 text-base leading-7 text-[var(--muted)]">
          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              Use of Bram
            </h2>
            <p className="mt-3">
              Bram is a workout notes and strength-tracking product. You are
              responsible for your own training decisions and should use
              judgment before acting on any suggestion, insight, or generated
              summary.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              Accounts and Subscriptions
            </h2>
            <p className="mt-3">
              Bram may offer free and paid features through App Store
              subscriptions. Purchases, trials, renewals, refunds, and
              cancellations are handled through Apple and the App Store terms
              that apply to your account.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              Acceptable Use
            </h2>
            <p className="mt-3">
              Do not misuse Bram, interfere with the service, attempt to access
              another user&apos;s data, reverse engineer private systems, or use
              the product for unlawful activity.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              Contact
            </h2>
            <p className="mt-3">
              Questions about these terms can be sent to{" "}
              <a
                className="font-semibold text-[var(--violet)]"
                href="mailto:support@trybram.app"
              >
                support@trybram.app
              </a>
              .
            </p>
          </section>
        </div>
      </article>
    </main>
  );
}
