import Image from "next/image";
import Link from "next/link";
import { WaitlistForm } from "@/components/waitlist-form";

const footerLinks = [
  { href: "/privacy", label: "Privacy" },
  { href: "/terms", label: "Terms" },
  { href: "mailto:support@trybram.app", label: "Contact" },
];

export default function Home() {
  return (
    <main className="relative flex min-h-[100svh] overflow-hidden bg-[var(--background)] px-5 py-5 text-[var(--foreground)] sm:px-8 lg:px-12">
      <div className="mx-auto grid h-[calc(100svh-40px)] w-full max-w-6xl grid-rows-[auto_1fr_auto]">
        <header className="flex items-center justify-between">
          <Link
            href="/"
            className="brand-wordmark text-[28px] leading-none text-[var(--violet)]"
            aria-label="Bram home"
          >
            Bram
          </Link>
          <span className="hidden text-sm font-medium text-[var(--muted)] sm:block">
            Workout Notes
          </span>
        </header>

        <section className="grid min-h-0 items-center gap-8 py-4 md:grid-cols-[1.05fr_0.95fr] md:gap-12 lg:gap-20">
          <div className="max-w-xl">
            <h1 className="text-balance text-[clamp(2.45rem,6vw,5.8rem)] font-semibold leading-[0.94] tracking-normal text-[var(--foreground)]">
              Write your workout. Bram tracks the rest.
            </h1>
            <p className="mt-5 max-w-lg text-pretty text-base leading-7 text-[var(--muted)] sm:text-lg sm:leading-8">
              A simpler strength tracker for lifters who already write in
              Notes. Log naturally, keep your history organized, and see
              progress without building a spreadsheet.
            </p>
            <WaitlistForm />
          </div>

          <div className="flex justify-center md:justify-end">
            <div className="relative aspect-square w-[min(54vw,360px)] max-w-[360px] min-w-[190px] overflow-hidden rounded-[28%] bg-[var(--charcoal)] shadow-[0_28px_80px_rgba(35,38,44,0.22)] ring-1 ring-black/10">
              <Image
                src="/bram-icon.png"
                alt="Bram app icon"
                fill
                sizes="(max-width: 768px) 54vw, 360px"
                priority
                className="object-cover"
              />
            </div>
          </div>
        </section>

        <footer className="flex items-center justify-center gap-7 text-sm font-medium text-[var(--muted)]">
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
      </div>
    </main>
  );
}
