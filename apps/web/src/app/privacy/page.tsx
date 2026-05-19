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
          className="brand-wordmark text-2xl text-[var(--violet)]"
        >
          Bram
        </Link>
        <h1 className="mt-12 text-4xl font-semibold tracking-normal">
          Privacy Policy
        </h1>
        <p className="mt-3 text-sm font-medium text-[var(--muted)]">
          Last updated May 19, 2026.
        </p>

        <div className="mt-10 space-y-8 text-base leading-7 text-[var(--muted)]">
          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              Overview
            </h2>
            <p className="mt-3">
              Bram: Workout Notes helps you write workouts naturally, then
              turns those notes into training history, progress stats, and
              suggestions. This policy explains what Bram collects, how that
              data is used, and the choices you have. Bram does not sell your
              workout data, does not use workout notes for advertising, and does
              not send raw workout note bodies or raw Apple Health samples to
              product analytics.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              Data We Collect
            </h2>
            <p className="mt-3">
              Bram collects the information needed to create your account,
              operate the app, sync your training data, process subscriptions,
              provide support, and improve reliability. This can include your
              name, email address, Supabase user ID, subscription status,
              onboarding answers, goal settings, preferred units, workout notes,
              parsed workout data, training metrics, customer support messages,
              product interaction events, crash data, performance data, and
              device or install identifiers.
            </p>
            <p className="mt-3">
              If you choose to connect Apple Health, Bram may read workout
              sessions, active energy, heart rate, distance, duration, and
              bodyweight data that you authorize through iOS. Apple Health
              access is optional and controlled by your device permissions.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              How We Use Data
            </h2>
            <p className="mt-3">
              Bram uses account data to sign you in, restore sessions, sync
              data across devices, manage subscriptions and promos, show account
              status, provide customer support, and delete your account when you
              ask us to. Bram uses workout notes, parsed workouts, goals, and
              training history to build charts, PRs, streaks, exercise history,
              and in-app suggestions. Bram uses Apple Health data only for app
              functionality, such as energy, heart rate, duration, distance,
              bodyweight context, and workout matching. Bram does not use
              HealthKit data for advertising, marketing, ad attribution, or
              analytics profiling.
            </p>
            <p className="mt-3">
              Bram uses product analytics and diagnostics to understand basic
              app usage, onboarding completion, paywall behavior, support
              categories, crashes, and performance. Analytics events are
              designed to use coarse properties and must not include raw workout
              note text, raw Health samples, bodyweight values, heart-rate
              values, support message bodies, or other freeform sensitive
              content.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              Workout Notes, Encryption, and Sync
            </h2>
            <p className="mt-3">
              Bram stores workout data locally on your device and syncs
              account-owned workout data to Supabase when you are signed in.
              Free-text workout note bodies are encrypted on-device before
              upload. The encrypted note body, nonce, key version, and
              encryption algorithm are stored in Supabase, while the decryption
              key stays in the iOS Keychain. Bram admins are not intended to be
              able to read encrypted note bodies from Supabase.
            </p>
            <p className="mt-3">
              Derived workout data remains stored in structured form so the app
              can show useful features: exercises, sets, reps, loads, cardio
              summaries, PRs, daily metrics, Health-derived summaries, and
              exercise history. These rows are keyed by your Supabase user ID and
              do not duplicate direct identity fields such as your email or
              display name.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              AI Features
            </h2>
            <p className="mt-3">
              Bram may use AI services to help interpret workout notes and
              improve structured suggestions. AI requests are sent through
              Bram&apos;s server routes and are designed to use only the content
              needed for the feature. Raw workout note text is not sent to
              analytics. AI usage accounting stores metadata such as user ID,
              task, model, estimated cost, month, and policy decision, not raw
              note bodies.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              Subscriptions and Payments
            </h2>
            <p className="mt-3">
              Bram subscriptions are purchased through Apple&apos;s in-app
              purchase system. Bram uses RevenueCat to read subscription state,
              support restore purchases, and sync entitlement status to Supabase.
              Bram does not receive your full payment card details from Apple.
              Subscription state may be linked to your Supabase user ID so Bram
              can unlock paid access, trials, promos, developer access, or
              manual grants.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              Third-Party Services
            </h2>
            <p className="mt-3">
              Bram uses Supabase for authentication and account-owned storage,
              Vercel for website and API hosting, Resend for email, RevenueCat
              for subscription state, PostHog for product analytics and crash
              reporting, Linear for support issue tracking, and selected AI
              providers for interpretation and suggestions. These services
              process data only as needed to provide, secure, support, and
              improve Bram.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              Your Choices
            </h2>
            <p className="mt-3">
              You can choose whether to create an account, connect Apple Health,
              enable notifications, submit a support request, or redeem a promo
              code. You can manage Apple Health permissions in iOS Settings and
              manage subscriptions through your Apple ID or App Store account.
              If you contact support, Bram may use your account email and
              diagnostic metadata to respond.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              Deletion, Export, and Contact
            </h2>
            <p className="mt-3">
              You can delete your account from Bram Settings. Account deletion
              removes your Supabase Auth account and cascades deletion through
              account-owned profile, entitlement, subscription, workout, goal,
              and Health-derived rows. Bram also clears the current
              account-scoped local database on the device after deletion
              succeeds. You can request privacy help or workout-history export
              support at{" "}
              <a
                className="font-semibold text-[var(--violet)]"
                href="mailto:support@trybram.app"
              >
                support@trybram.app
              </a>
              .
            </p>
          </section>

          <section>
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              Changes
            </h2>
            <p className="mt-3">
              Bram may update this policy as the app changes. If the changes
              are material, we will update this page and, when appropriate,
              provide additional notice in the app or by email.
            </p>
          </section>
        </div>
      </article>
    </main>
  );
}
