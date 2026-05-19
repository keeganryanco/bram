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
          Last updated May 19, 2026.
        </p>

        <div className="mt-10 space-y-8 text-base leading-7 text-[var(--muted)]">
          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              Use of Bram
            </h2>
            <p className="mt-3">
              Bram: Workout Notes is a workout notes, training history, and
              progress-tracking app. Bram helps you write workouts naturally,
              parse training data, view progress, and receive lightweight
              suggestions. You are responsible for your own training decisions
              and should use judgment before acting on any suggestion, insight,
              chart, generated summary, or interpreted workout result.
            </p>
            <p className="mt-3">
              Bram is not medical advice, healthcare advice, physical therapy,
              personal training, or an emergency service. Stop exercising and
              seek qualified professional help if you feel pain, dizziness,
              injury symptoms, or anything medically concerning.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              Accounts and Subscriptions
            </h2>
            <p className="mt-3">
              Bram requires an account for synced app access. Paid access is
              offered through Apple in-app purchase subscriptions. Subscriptions
              may include a free trial when shown in the app or App Store.
              Purchases, trials, renewals, cancellations, refunds, and billing
              are handled by Apple and the App Store terms that apply to your
              Apple account.
            </p>
            <p className="mt-3">
              Bram uses RevenueCat to read purchase status and Supabase to store
              entitlement state. Restore Purchases attempts to restore eligible
              Apple purchases and then refresh Bram access. Promo codes, founder
              grants, TestFlight access, Product Hunt access, friends access,
              and developer access may be granted, changed, limited, or removed
              by Bram when appropriate.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              Apple Health and Notifications
            </h2>
            <p className="mt-3">
              Apple Health integration is optional. If you connect Apple Health,
              Bram uses authorized Health data only to provide app features such
              as energy, heart rate, duration, distance, bodyweight context, and
              workout matching. You can change Health permissions in iOS
              Settings. Workout reminder notifications are optional and can be
              changed in Bram or iOS Settings.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              Acceptable Use
            </h2>
            <p className="mt-3">
              Do not misuse Bram, interfere with the service, attempt to access
              another user&apos;s data, reverse engineer private systems, or use
              the product for unlawful activity. Do not attempt to bypass
              entitlements, payment systems, rate limits, AI usage limits, or
              admin-only systems. Do not submit support messages or workout
              notes that are unlawful, abusive, or intended to disrupt the
              service.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              Data, Sync, and Availability
            </h2>
            <p className="mt-3">
              Bram is local-first, but account sync, subscriptions, AI features,
              support, and some account features rely on network services such
              as Supabase, Vercel, RevenueCat, Apple, PostHog, Linear, Resend,
              and selected AI providers. Bram may be unavailable, delayed, or
              incomplete during maintenance, outages, review, beta testing,
              network issues, or provider failures.
            </p>
            <p className="mt-3">
              Bram tries to preserve and sync your account-owned data, but you
              should not treat Bram as the only permanent copy of important
              records. Workout interpretation may be incomplete or incorrect,
              especially for ambiguous natural language.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              AI Features and Suggestions
            </h2>
            <p className="mt-3">
              Bram may use AI-assisted interpretation or suggestions. These
              features are designed to support your own judgment, not replace
              it. Suggestions may be wrong, incomplete, too aggressive, too
              conservative, or unsuitable for your situation. Bram may apply
              usage limits, model downgrades, or blocking for free, promo,
              founder, developer, or abusive usage.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              Beta, TestFlight, and Launch Promos
            </h2>
            <p className="mt-3">
              TestFlight and prelaunch versions may contain bugs, incomplete
              features, changed pricing, changed promo rules, or reset test
              data. TestFlight and Product Hunt promos are promotional access,
              not cash value. Bram may revoke or adjust promotional grants if
              they are misused, duplicated, technically incorrect, or no longer
              available.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              Privacy
            </h2>
            <p className="mt-3">
              Bram&apos;s Privacy Policy explains how Bram collects, uses,
              stores, syncs, analyzes, and deletes data. By using Bram, you also
              agree to the data practices described in the{" "}
              <Link className="font-semibold text-[var(--violet)]" href="/privacy">
                Privacy Policy
              </Link>
              .
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              Disclaimers and Limitation of Liability
            </h2>
            <p className="mt-3">
              Bram is provided as is and as available. To the maximum extent
              permitted by law, Bram disclaims warranties of merchantability,
              fitness for a particular purpose, accuracy, uninterrupted
              availability, and non-infringement. To the maximum extent
              permitted by law, Bram will not be liable for indirect,
              incidental, special, consequential, punitive, or lost-profit
              damages, or for injuries or losses arising from training decisions
              you make.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              Changes to These Terms
            </h2>
            <p className="mt-3">
              Bram may update these terms as the app changes. If changes are
              material, Bram will update this page and, when appropriate,
              provide additional notice in the app or by email. Continued use of
              Bram after changes means you accept the updated terms.
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
