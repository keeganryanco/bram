import Link from "next/link";

export const metadata = {
  title: "Privacy Policy",
};

export default function PrivacyPage() {
  return (
    <main className="min-h-screen bg-[var(--background)] px-5 py-8 text-[var(--foreground)] sm:px-8">
      <article className="mx-auto max-w-3xl">
        <Link
          href="/"
          className="font-serif text-2xl font-semibold text-[var(--violet)]"
        >
          Bram
        </Link>
        <h1 className="mt-12 text-4xl font-semibold tracking-normal">
          Privacy Policy
        </h1>
        <p className="mt-3 text-sm font-medium text-[var(--muted)]">
          Draft for app submission review. Last updated May 6, 2026.
        </p>

        <div className="mt-10 space-y-8 text-base leading-7 text-[var(--muted)]">
          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              What Bram Collects
            </h2>
            <p className="mt-3">
              Bram may collect your email address, account information,
              subscription status, product interaction analytics, workout notes,
              parsed workout history, settings, and support messages. If
              HealthKit or similar integrations are added later, Bram will ask
              for permission before accessing that data.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              How Bram Uses Data
            </h2>
            <p className="mt-3">
              Bram uses your workout notes to structure training history,
              generate progress insights, provide suggestions, sync your account,
              manage purchases, operate the waitlist, send product emails, fix
              bugs, and understand aggregate product usage. Bram does not sell
              workout data or use workout notes for advertising.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              Third-Party Services
            </h2>
            <p className="mt-3">
              Bram plans to use Supabase for authentication and storage, Resend
              for email, RevenueCat for subscription status, PostHog for product
              analytics, Vercel for website hosting, and OpenAI Platform for
              note interpretation and training insights. Analytics events must
              not include raw workout note bodies.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              Deletion and Export
            </h2>
            <p className="mt-3">
              Bram will provide account deletion and workout-history export
              paths before App Store launch. You can request deletion, export,
              or privacy help at{" "}
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
