"use client";

import { FormEvent, useState } from "react";

type Status = "idle" | "submitting" | "success" | "error";

export function WaitlistForm() {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<Status>("idle");
  const [message, setMessage] = useState("");

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatus("submitting");
    setMessage("");

    try {
      const response = await fetch("/api/waitlist", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email }),
      });
      const body = (await response.json()) as { message?: string };

      if (!response.ok) {
        setStatus("error");
        setMessage(body.message ?? "Something went wrong. Try again.");
        return;
      }

      setStatus("success");
      setMessage(body.message ?? "You are on the list.");
      setEmail("");
    } catch {
      setStatus("error");
      setMessage("Could not join right now. Try again in a minute.");
    }
  }

  return (
    <form onSubmit={onSubmit} className="mt-8 w-full max-w-[29rem] sm:max-w-xl" noValidate>
      <div className="flex flex-col gap-3 sm:flex-row">
        <label className="sr-only" htmlFor="email">
          Email address
        </label>
        <input
          id="email"
          name="email"
          type="email"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          placeholder="you@example.com"
          autoComplete="email"
          disabled={status === "submitting"}
          className="h-14 min-h-14 min-w-0 flex-1 rounded-[20px] border border-[var(--border)] bg-[var(--cream-panel)] px-5 py-4 text-base leading-6 text-[var(--foreground)] shadow-[0_10px_24px_rgba(35,38,44,0.06)] outline-none transition placeholder:text-[#94969b] focus:border-[var(--violet)] focus:ring-4 focus:ring-[rgba(93,90,247,0.12)] disabled:cursor-not-allowed disabled:opacity-70 sm:h-12 sm:min-h-12 sm:rounded-full sm:py-0 sm:text-[15px]"
        />
        <button
          type="submit"
          disabled={status === "submitting"}
          className="h-14 rounded-[20px] bg-[var(--violet)] px-6 text-base font-semibold text-white shadow-[0_12px_28px_rgba(93,90,247,0.22)] transition hover:bg-[var(--violet-deep)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-[var(--violet)] disabled:cursor-not-allowed disabled:opacity-70 sm:h-12 sm:rounded-full sm:text-[15px]"
        >
          {status === "submitting" ? "Joining..." : "Join waitlist"}
        </button>
      </div>
      <p
        role="status"
        className="mt-3 min-h-5 text-sm font-medium text-[var(--muted)]"
      >
        {message}
      </p>
    </form>
  );
}
