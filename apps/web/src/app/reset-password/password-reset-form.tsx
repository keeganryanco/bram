"use client";

import Link from "next/link";
import { createClient } from "@supabase/supabase-js";
import { FormEvent, useEffect, useMemo, useState } from "react";

const supabaseURL =
  process.env.NEXT_PUBLIC_SUPABASE_URL ??
  "https://njotbjmpcostgktjjihv.supabase.co";
const supabasePublishableKey =
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ??
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ??
  "sb_publishable_LovuYXBzXPbXevP8FuHSLA_wen7RoSQ";

type ResetStage = "request" | "checking" | "update" | "sent" | "complete";

export function PasswordResetForm() {
  const [stage, setStage] = useState<ResetStage>("checking");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const supabase = useMemo(
    () => createClient(supabaseURL, supabasePublishableKey),
    [],
  );

  useEffect(() => {
    async function restoreRecoverySession() {
      const url = new URL(window.location.href);
      const hash = new URLSearchParams(window.location.hash.replace(/^#/, ""));
      const accessToken = hash.get("access_token");
      const refreshToken = hash.get("refresh_token");
      const authCode = url.searchParams.get("code");
      const tokenHash = url.searchParams.get("token_hash");
      const tokenType = url.searchParams.get("type");
      const requestedEmail = url.searchParams.get("email");

      if (requestedEmail) {
        setEmail(requestedEmail);
      }

      if (accessToken && refreshToken) {
        const { error } = await supabase.auth.setSession({
          access_token: accessToken,
          refresh_token: refreshToken,
        });

        window.history.replaceState(null, "", "/reset-password");
        if (error) {
          setMessage("That reset link is no longer valid. Request a new one.");
          setStage("request");
          return;
        }

        setStage("update");
        return;
      }

      if (authCode) {
        const { error } = await supabase.auth.exchangeCodeForSession(authCode);

        window.history.replaceState(null, "", "/reset-password");
        if (error) {
          setMessage("That reset link is no longer valid. Request a new one.");
          setStage("request");
          return;
        }

        setStage("update");
        return;
      }

      if (tokenHash && tokenType === "recovery") {
        const { error } = await supabase.auth.verifyOtp({
          token_hash: tokenHash,
          type: "recovery",
        });

        window.history.replaceState(null, "", "/reset-password");
        if (error) {
          setMessage("That reset link is no longer valid. Request a new one.");
          setStage("request");
          return;
        }

        setStage("update");
        return;
      }

      setStage("request");
    }

    restoreRecoverySession();
  }, [supabase]);

  async function requestReset(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setIsSubmitting(true);
    setMessage(null);

    try {
      const response = await fetch("/api/auth/password-reset/request", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email }),
      });
      const result = (await response.json()) as { message?: string };

      setMessage(result.message ?? "Check your email for a reset link.");
      setStage(response.ok ? "sent" : "request");
    } catch {
      setMessage("Could not request a reset link right now.");
      setStage("request");
    } finally {
      setIsSubmitting(false);
    }
  }

  async function updatePassword(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setIsSubmitting(true);
    setMessage(null);

    if (password.length < 8) {
      setMessage("Use at least 8 characters.");
      setIsSubmitting(false);
      return;
    }

    const { error } = await supabase.auth.updateUser({ password });
    if (error) {
      setMessage("Could not update your password. Request a new reset link.");
      setIsSubmitting(false);
      return;
    }

    await supabase.auth.signOut();
    setPassword("");
    setStage("complete");
    setMessage("Your password has been updated. You can sign in in the app.");
    setIsSubmitting(false);
  }

  return (
    <main className="flex min-h-[100svh] bg-[var(--background)] px-5 py-5 text-[var(--foreground)] sm:px-8 lg:px-12">
      <div className="mx-auto grid min-h-[calc(100svh-40px)] w-full max-w-3xl grid-rows-[auto_1fr_auto]">
        <header className="flex items-center justify-between">
          <Link
            href="/"
            className="brand-wordmark text-[28px] leading-none text-[var(--violet)]"
            aria-label="Bram home"
          >
            Bram
          </Link>
        </header>

        <section className="flex items-center py-10">
          <div className="w-full max-w-xl">
            <h1 className="text-balance text-[clamp(2.3rem,7vw,4.7rem)] font-semibold leading-[0.96] tracking-normal">
              Reset your password.
            </h1>
            <p className="mt-5 max-w-lg text-pretty text-base leading-7 text-[var(--muted)] sm:text-lg sm:leading-8">
              Use the same email as your Bram account. The reset link opens here
              so you can choose a new password securely.
            </p>

            {stage === "checking" ? (
              <p className="mt-8 text-sm font-medium text-[var(--muted)]">
                Checking reset link...
              </p>
            ) : null}

            {stage === "request" || stage === "sent" ? (
              <form className="mt-8 flex max-w-md flex-col gap-3" onSubmit={requestReset}>
                <label className="text-sm font-semibold text-[var(--foreground)]" htmlFor="email">
                  Account email
                </label>
                <input
                  id="email"
                  type="email"
                  value={email}
                  onChange={(event) => setEmail(event.target.value)}
                  autoComplete="email"
                  required
                  className="min-h-12 rounded-[8px] border border-[var(--border)] bg-[var(--cream-panel)] px-4 text-base outline-none transition focus:border-[var(--violet)]"
                />
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="mt-1 min-h-12 rounded-full bg-[var(--violet)] px-5 text-base font-semibold text-white transition hover:bg-[var(--violet-deep)] disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {isSubmitting ? "Sending..." : "Send reset link"}
                </button>
              </form>
            ) : null}

            {stage === "update" ? (
              <form className="mt-8 flex max-w-md flex-col gap-3" onSubmit={updatePassword}>
                <label className="text-sm font-semibold text-[var(--foreground)]" htmlFor="password">
                  New password
                </label>
                <input
                  id="password"
                  type="password"
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                  autoComplete="new-password"
                  minLength={8}
                  required
                  className="min-h-12 rounded-[8px] border border-[var(--border)] bg-[var(--cream-panel)] px-4 text-base outline-none transition focus:border-[var(--violet)]"
                />
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="mt-1 min-h-12 rounded-full bg-[var(--violet)] px-5 text-base font-semibold text-white transition hover:bg-[var(--violet-deep)] disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {isSubmitting ? "Updating..." : "Update password"}
                </button>
              </form>
            ) : null}

            {message ? (
              <p className="mt-5 max-w-md text-sm font-medium leading-6 text-[var(--muted)]">
                {message}
              </p>
            ) : null}
          </div>
        </section>

        <footer className="flex items-center justify-center gap-7 text-sm font-medium text-[var(--muted)]">
          <Link
            href="/privacy"
            className="transition hover:text-[var(--foreground)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-[var(--violet)]"
          >
            Privacy Policy
          </Link>
          <Link
            href="/terms"
            className="transition hover:text-[var(--foreground)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-[var(--violet)]"
          >
            Terms
          </Link>
        </footer>
      </div>
    </main>
  );
}
