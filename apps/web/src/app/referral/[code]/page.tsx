import Link from "next/link";
import {
  normalizeReferralCode,
  referralFriendOfferURL,
} from "@/lib/referrals";

type ReferralPageProps = {
  params: Promise<{
    code: string;
  }>;
};

export default async function ReferralPage({ params }: ReferralPageProps) {
  const { code: rawCode } = await params;
  const code = normalizeReferralCode(rawCode);
  const offerURL = referralFriendOfferURL();
  const appURL = `app.trybram.Bram://referral?code=${encodeURIComponent(code)}`;

  return (
    <main className="flex min-h-[100svh] bg-[var(--background)] px-6 py-7 text-[var(--foreground)]">
      <section className="mx-auto flex w-full max-w-xl flex-col justify-center">
        <Link
          href="/"
          className="brand-wordmark mb-16 text-[34px] leading-none text-[var(--violet)]"
          aria-label="Bram home"
        >
          Bram
        </Link>

        <p className="mb-4 text-sm font-semibold uppercase tracking-[0.08em] text-[var(--violet)]">
          Friend invite
        </p>
        <h1 className="max-w-[11ch] text-[clamp(3rem,11vw,5.5rem)] font-semibold leading-[0.94] tracking-normal">
          Try Bram free for a month.
        </h1>
        <p className="mt-6 max-w-md text-lg leading-8 text-[var(--muted)]">
          Redeem the Apple offer code, install Bram, then open your invite so
          your friend gets credit.
        </p>

        <div className="mt-8 flex flex-col gap-3">
          {offerURL ? (
            <Link
              href={offerURL}
              className="rounded-full bg-[var(--violet)] px-6 py-4 text-center text-base font-semibold text-white shadow-[0_18px_38px_rgba(93,90,247,0.24)] transition hover:bg-[var(--violet-deep)]"
            >
              Redeem 1 month free
            </Link>
          ) : (
            <div className="rounded-3xl border border-[var(--border)] bg-[var(--cream-panel)] p-5 text-sm leading-6 text-[var(--muted)]">
              Offer-code links are being configured. Open Bram and tap Redeem
              code on the paywall.
            </div>
          )}
          <Link
            href={appURL}
            className="rounded-full border border-[var(--border)] bg-[var(--cream-panel)] px-6 py-4 text-center text-base font-semibold text-[var(--foreground)] transition hover:border-[var(--violet)]"
          >
            Open Bram invite
          </Link>
        </div>

        <p className="mt-6 text-sm leading-6 text-[var(--muted)]">
          Referral code: <span className="font-semibold">{code}</span>
        </p>
      </section>
    </main>
  );
}
