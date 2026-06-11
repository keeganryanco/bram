"use client";

import { useMemo, useState, type ReactNode } from "react";
import Link from "next/link";
import {
  appStoreURL,
  siteURL,
} from "@/lib/marketing-content";
import type { UtilityPage } from "@/lib/utility-content";
import { FAQList, JsonLd, SectionHeader } from "@/components/marketing";

type NumberInputProps = {
  label: string;
  value: number;
  min?: number;
  max?: number;
  step?: number;
  suffix?: string;
  onChange: (value: number) => void;
};

function NumberInput({
  label,
  value,
  min = 0,
  max,
  step = 1,
  suffix,
  onChange,
}: NumberInputProps) {
  return (
    <label className="grid gap-2">
      <span className="text-sm font-semibold text-[var(--foreground)]">
        {label}
      </span>
      <span className="flex items-center overflow-hidden rounded-lg border border-[var(--border)] bg-white">
        <input
          type="number"
          min={min}
          max={max}
          step={step}
          value={Number.isFinite(value) ? value : 0}
          onChange={(event) => onChange(Number(event.target.value))}
          className="min-h-12 w-full bg-transparent px-4 text-base font-semibold text-[var(--foreground)] outline-none"
        />
        {suffix ? (
          <span className="pr-4 text-sm font-semibold text-[var(--muted)]">
            {suffix}
          </span>
        ) : null}
      </span>
    </label>
  );
}

function SelectInput({
  label,
  value,
  options,
  onChange,
}: {
  label: string;
  value: string;
  options: Array<{ label: string; value: string }>;
  onChange: (value: string) => void;
}) {
  return (
    <label className="grid gap-2">
      <span className="text-sm font-semibold text-[var(--foreground)]">
        {label}
      </span>
      <select
        value={value}
        onChange={(event) => onChange(event.target.value)}
        className="min-h-12 rounded-lg border border-[var(--border)] bg-white px-4 text-base font-semibold text-[var(--foreground)] outline-none"
      >
        {options.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>
    </label>
  );
}

function ResultCard({
  label,
  value,
  detail,
}: {
  label: string;
  value: string;
  detail?: string;
}) {
  return (
    <div className="rounded-lg border border-[var(--border)] bg-white p-5">
      <p className="text-sm font-semibold uppercase tracking-[0.1em] text-[var(--muted)]">
        {label}
      </p>
      <p className="mt-2 text-3xl font-semibold tracking-normal text-[var(--foreground)]">
        {value}
      </p>
      {detail ? (
        <p className="mt-3 text-sm leading-6 text-[var(--muted)]">{detail}</p>
      ) : null}
    </div>
  );
}

function oneRepMax(weight: number, reps: number) {
  if (reps <= 1) {
    return weight;
  }

  return weight * (1 + reps / 30);
}

function OneRepMaxTool() {
  const [weight, setWeight] = useState(185);
  const [reps, setReps] = useState(5);
  const max = useMemo(() => oneRepMax(weight, reps), [weight, reps]);
  const trainingMax = max * 0.9;

  return (
    <ToolShell>
      <div className="grid gap-4 md:grid-cols-2">
        <NumberInput label="Weight lifted" value={weight} min={1} suffix="lb" onChange={setWeight} />
        <NumberInput label="Reps completed" value={reps} min={1} max={30} onChange={setReps} />
      </div>
      <div className="mt-6 grid gap-4 md:grid-cols-3">
        <ResultCard label="Estimated 1RM" value={`${Math.round(max)} lb`} detail="Epley estimate from your set." />
        <ResultCard label="Training max" value={`${Math.round(trainingMax)} lb`} detail="90% of estimated 1RM." />
        <ResultCard label="Hard 5 target" value={`${Math.round(max * 0.86)} lb`} detail="A practical next 5-rep target." />
      </div>
    </ToolShell>
  );
}

function ProgressiveOverloadTool() {
  const [weight, setWeight] = useState(185);
  const [bestReps, setBestReps] = useState(8);
  const [targetReps, setTargetReps] = useState(8);
  const [increment, setIncrement] = useState(5);
  const hitTarget = bestReps >= targetReps;
  const nextWeight = hitTarget ? weight + increment : weight;

  return (
    <ToolShell>
      <div className="grid gap-4 md:grid-cols-4">
        <NumberInput label="Current weight" value={weight} min={1} suffix="lb" onChange={setWeight} />
        <NumberInput label="Best reps last time" value={bestReps} min={1} max={50} onChange={setBestReps} />
        <NumberInput label="Rep target" value={targetReps} min={1} max={50} onChange={setTargetReps} />
        <NumberInput label="Weight jump" value={increment} min={1} suffix="lb" onChange={setIncrement} />
      </div>
      <div className="mt-6 grid gap-4 md:grid-cols-2">
        <ResultCard
          label="Next target"
          value={`${nextWeight} lb`}
          detail={hitTarget ? "You hit the rep target. Add the planned jump." : "Keep the same weight and add reps first."}
        />
        <ResultCard
          label="Rep goal"
          value={hitTarget ? `${targetReps} reps again` : `${Math.min(bestReps + 1, targetReps)} reps`}
          detail="Use clean form before adding more load."
        />
      </div>
    </ToolShell>
  );
}

function WorkoutVolumeTool() {
  const [exercise, setExercise] = useState("Bench press");
  const [sets, setSets] = useState(3);
  const [reps, setReps] = useState(8);
  const [weight, setWeight] = useState(185);
  const volume = sets * reps * weight;

  return (
    <ToolShell>
      <label className="grid gap-2">
        <span className="text-sm font-semibold text-[var(--foreground)]">
          Exercise
        </span>
        <input
          value={exercise}
          onChange={(event) => setExercise(event.target.value)}
          className="min-h-12 rounded-lg border border-[var(--border)] bg-white px-4 text-base font-semibold text-[var(--foreground)] outline-none"
        />
      </label>
      <div className="mt-4 grid gap-4 md:grid-cols-3">
        <NumberInput label="Sets" value={sets} min={1} max={20} onChange={setSets} />
        <NumberInput label="Reps per set" value={reps} min={1} max={100} onChange={setReps} />
        <NumberInput label="Weight" value={weight} min={0} suffix="lb" onChange={setWeight} />
      </div>
      <div className="mt-6 grid gap-4 md:grid-cols-3">
        <ResultCard label={exercise || "Exercise"} value={`${volume.toLocaleString()} lb`} detail="Sets x reps x weight." />
        <ResultCard label="Total reps" value={`${sets * reps}`} />
        <ResultCard label="Logged sets" value={`${sets}`} />
      </div>
    </ToolShell>
  );
}

function GymSplitTool() {
  const [days, setDays] = useState(4);
  const [goal, setGoal] = useState("strength");
  const [minutes, setMinutes] = useState(60);

  const split = useMemo(() => {
    if (days <= 2) {
      return ["Full body", "Full body"];
    }
    if (days === 3) {
      return goal === "hypertrophy"
        ? ["Push", "Pull", "Legs"]
        : ["Full body A", "Full body B", "Full body C"];
    }
    if (days === 4) {
      return ["Upper", "Lower", "Upper", "Lower"];
    }
    if (days === 5) {
      return ["Upper strength", "Lower strength", "Push", "Pull", "Legs"];
    }

    return ["Push", "Pull", "Legs", "Push", "Pull", "Legs"];
  }, [days, goal]);

  return (
    <ToolShell>
      <div className="grid gap-4 md:grid-cols-3">
        <NumberInput label="Training days per week" value={days} min={2} max={6} onChange={setDays} />
        <SelectInput
          label="Primary goal"
          value={goal}
          onChange={setGoal}
          options={[
            { label: "Strength", value: "strength" },
            { label: "Hypertrophy", value: "hypertrophy" },
            { label: "General fitness", value: "general" },
          ]}
        />
        <NumberInput label="Minutes per session" value={minutes} min={30} max={120} suffix="min" onChange={setMinutes} />
      </div>
      <div className="mt-6 rounded-lg border border-[var(--border)] bg-white p-5">
        <p className="text-sm font-semibold uppercase tracking-[0.1em] text-[var(--muted)]">
          Suggested split
        </p>
        <div className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {split.slice(0, Math.max(2, Math.min(days, 6))).map((day, index) => (
            <div key={`${day}-${index}`} className="rounded-lg bg-[var(--background)] p-4">
              <p className="text-sm font-semibold text-[var(--muted)]">
                Day {index + 1}
              </p>
              <p className="mt-1 text-xl font-semibold text-[var(--foreground)]">
                {day}
              </p>
            </div>
          ))}
        </div>
        <p className="mt-5 text-sm leading-6 text-[var(--muted)]">
          Keep 1 to 3 main lifts and 2 to 4 accessories per session if you have about {minutes} minutes.
        </p>
      </div>
    </ToolShell>
  );
}

function NextWeekWeightTool() {
  const [weight, setWeight] = useState(185);
  const [reps, setReps] = useState(8);
  const [target, setTarget] = useState(8);
  const [increment, setIncrement] = useState(5);
  const [difficulty, setDifficulty] = useState("solid");
  const addWeight = reps >= target && difficulty !== "grind";
  const next = addWeight ? weight + increment : weight;

  return (
    <ToolShell>
      <div className="grid gap-4 md:grid-cols-5">
        <NumberInput label="Last weight" value={weight} min={1} suffix="lb" onChange={setWeight} />
        <NumberInput label="Reps hit" value={reps} min={1} max={50} onChange={setReps} />
        <NumberInput label="Target reps" value={target} min={1} max={50} onChange={setTarget} />
        <NumberInput label="Jump" value={increment} min={1} suffix="lb" onChange={setIncrement} />
        <SelectInput
          label="Set quality"
          value={difficulty}
          onChange={setDifficulty}
          options={[
            { label: "Solid", value: "solid" },
            { label: "Easy", value: "easy" },
            { label: "Grindy", value: "grind" },
          ]}
        />
      </div>
      <div className="mt-6 grid gap-4 md:grid-cols-2">
        <ResultCard
          label="Use next week"
          value={`${next} lb`}
          detail={addWeight ? "You earned the next jump." : "Repeat the same load and make the reps cleaner."}
        />
        <ResultCard
          label="Target"
          value={addWeight ? `${target} reps` : `${Math.min(reps + 1, target)} reps`}
          detail="Small jumps compound when you track them."
        />
      </div>
    </ToolShell>
  );
}

function PREstimatorTool() {
  const [weight, setWeight] = useState(225);
  const [reps, setReps] = useState(5);
  const max = oneRepMax(weight, reps);
  const targets = [
    ["1 rep", max],
    ["3 reps", max * 0.93],
    ["5 reps", max * 0.86],
    ["8 reps", max * 0.8],
    ["10 reps", max * 0.75],
  ];

  return (
    <ToolShell>
      <div className="grid gap-4 md:grid-cols-2">
        <NumberInput label="Recent weight" value={weight} min={1} suffix="lb" onChange={setWeight} />
        <NumberInput label="Reps completed" value={reps} min={1} max={30} onChange={setReps} />
      </div>
      <div className="mt-6 grid gap-4 md:grid-cols-5">
        {targets.map(([label, value]) => (
          <ResultCard key={label} label={String(label)} value={`${Math.round(Number(value))} lb`} />
        ))}
      </div>
    </ToolShell>
  );
}

function parseWorkoutNote(note: string) {
  const lines = note
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);

  return lines.map((line) => {
    const setPattern =
      /(\d+(?:\.\d+)?)\s*(?:s|lb|lbs|#)?\s*(?:x|for)\s*(\d+)/gi;
    const setMatches = [
      ...line.matchAll(setPattern),
    ];
    const exercise = line
      .replace(/[-–—:]/g, " ")
      .replace(setPattern, "")
      .replace(/\b\d+\s*x\s*\d+\b/gi, "")
      .replace(/,+/g, " ")
      .replace(/\s+/g, " ")
      .trim();

    return {
      exercise: exercise || "Workout line",
      sets: setMatches.length
        ? setMatches.map((match) => `${match[1]} x ${match[2]}`)
        : ["Needs review"],
      raw: line,
    };
  });
}

function NotesConverterTool() {
  const [note, setNote] = useState(
    "Bench press 185 x 5, 185 x 5, 185 x 6\nIncline press 70s for 8, 70s for 7\nTricep pushdown 90 x 10, 90 x 8",
  );
  const parsed = useMemo(() => parseWorkoutNote(note), [note]);

  return (
    <ToolShell>
      <label className="grid gap-2">
        <span className="text-sm font-semibold text-[var(--foreground)]">
          Paste your workout note
        </span>
        <textarea
          value={note}
          onChange={(event) => setNote(event.target.value)}
          rows={7}
          className="w-full rounded-lg border border-[var(--border)] bg-white p-4 text-base leading-7 text-[var(--foreground)] outline-none"
        />
      </label>
      <div className="mt-6 overflow-hidden rounded-lg border border-[var(--border)] bg-white">
        <div className="hidden grid-cols-[1fr_1.2fr] border-b border-[var(--border)] bg-[var(--background)] px-4 py-3 text-sm font-semibold text-[var(--foreground)] sm:grid">
          <span>Exercise</span>
          <span>Parsed sets</span>
        </div>
        {parsed.map((row, index) => (
          <div key={`${row.raw}-${index}`} className="grid gap-3 border-b border-[var(--border)] px-4 py-4 last:border-0 sm:grid-cols-[1fr_1.2fr] sm:gap-4">
            <div>
              <p className="text-xs font-semibold uppercase tracking-[0.1em] text-[var(--muted)] sm:hidden">
                Exercise
              </p>
              <p className="mt-1 font-semibold text-[var(--foreground)] sm:mt-0">
                {row.exercise}
              </p>
            </div>
            <div>
              <p className="text-xs font-semibold uppercase tracking-[0.1em] text-[var(--muted)] sm:hidden">
                Parsed sets
              </p>
              <p className="mt-1 text-[var(--muted)] sm:mt-0">
                {row.sets.join(", ")}
              </p>
            </div>
          </div>
        ))}
      </div>
    </ToolShell>
  );
}

function ToolShell({ children }: { children: ReactNode }) {
  return (
    <section className="rounded-lg border border-[var(--border)] bg-[var(--cream-panel)] p-5 shadow-[0_16px_54px_rgba(35,38,44,0.07)] sm:p-7">
      {children}
    </section>
  );
}

function UtilityWidget({ kind }: { kind: UtilityPage["kind"] }) {
  switch (kind) {
    case "oneRepMax":
      return <OneRepMaxTool />;
    case "progressiveOverload":
      return <ProgressiveOverloadTool />;
    case "workoutVolume":
      return <WorkoutVolumeTool />;
    case "gymSplit":
      return <GymSplitTool />;
    case "nextWeekWeight":
      return <NextWeekWeightTool />;
    case "prEstimator":
      return <PREstimatorTool />;
    case "notesConverter":
      return <NotesConverterTool />;
  }
}

export function WorkoutUtilityPage({ utility }: { utility: UtilityPage }) {
  const canonical = `${siteURL}/${utility.slug}`;
  const webAppSchema = {
    "@context": "https://schema.org",
    "@type": "WebApplication",
    name: utility.title,
    description: utility.description,
    url: canonical,
    applicationCategory: "HealthApplication",
    operatingSystem: "Any",
    offers: {
      "@type": "Offer",
      price: "0",
      priceCurrency: "USD",
    },
  };

  const faqSchema = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: utility.faqs.map((faq) => ({
      "@type": "Question",
      name: faq.question,
      acceptedAnswer: {
        "@type": "Answer",
        text: faq.answer,
      },
    })),
  };

  return (
    <main className="min-h-screen bg-[var(--background)] px-5 py-8 text-[var(--foreground)] sm:px-8">
      <JsonLd data={webAppSchema} />
      <JsonLd data={faqSchema} />

      <article className="mx-auto max-w-5xl">
        <header>
          <Link
            href="/"
            className="brand-wordmark text-2xl text-[var(--violet)]"
            aria-label="Bram home"
          >
            Bram
          </Link>
          <div className="mt-14 max-w-3xl">
            <p className="text-sm font-semibold uppercase tracking-[0.12em] text-[var(--violet)]">
              Free workout tool
            </p>
            <h1 className="mt-4 text-balance text-5xl font-semibold leading-[0.98] tracking-normal sm:text-6xl">
              {utility.title}
            </h1>
            <p className="mt-6 text-xl leading-9 text-[var(--muted)]">
              {utility.intro}
            </p>
            <p className="mt-5 text-sm font-medium text-[var(--muted)]">
              Updated {utility.updated}
            </p>
          </div>
        </header>

        <div className="mt-12">
          <UtilityWidget kind={utility.kind} />
        </div>

        <div className="mt-12 grid gap-12 lg:grid-cols-[1fr_280px] lg:items-start">
          <div className="space-y-12">
            {utility.sections.map((section) => (
              <section key={section.heading}>
                <h2 className="text-3xl font-semibold tracking-normal text-[var(--foreground)]">
                  {section.heading}
                </h2>
                <div className="mt-5 space-y-5 text-lg leading-8 text-[var(--muted)]">
                  {section.body.map((paragraph) => (
                    <p key={paragraph}>{paragraph}</p>
                  ))}
                </div>
              </section>
            ))}

            <section>
              <h2 className="text-3xl font-semibold tracking-normal text-[var(--foreground)]">
                FAQ
              </h2>
              <div className="mt-6">
                <FAQList faqs={utility.faqs} />
              </div>
            </section>
          </div>

          <aside className="sticky top-8 hidden rounded-lg border border-[var(--border)] bg-[var(--cream-panel)] p-5 lg:block">
            <p className="text-sm font-semibold uppercase tracking-[0.12em] text-[var(--muted)]">
              More tools
            </p>
            <nav className="mt-4 grid gap-3 text-sm font-semibold leading-5">
              {utility.related.map((slug) => (
                <Link
                  key={slug}
                  href={`/${slug}`}
                  className="text-[var(--foreground)] transition hover:text-[var(--violet)]"
                >
                  {slug
                    .split("-")
                    .map((word) => word[0].toUpperCase() + word.slice(1))
                    .join(" ")}
                </Link>
              ))}
            </nav>
          </aside>
        </div>

        <section className="mt-14">
          <SectionHeader
            eyebrow="Workout notes"
            title="Use the calculator. Keep the history in Bram."
            description="Write workouts naturally in Bram and keep the progress every week."
          />
        </section>

        <section className="mt-16 rounded-lg bg-[var(--charcoal)] px-6 py-10 text-center text-white shadow-[0_24px_80px_rgba(35,38,44,0.16)] sm:px-10">
          <p className="brand-wordmark text-4xl text-[var(--violet)]">Bram</p>
          <h2 className="mx-auto mt-5 max-w-2xl text-balance text-4xl font-semibold leading-tight tracking-normal">
            Track the full workout in Bram.
          </h2>
          <p className="mx-auto mt-4 max-w-2xl text-lg leading-8 text-white/70">
            These tools answer one question. Bram remembers every lift, PR,
            note, and trend from your actual training.
          </p>
          <Link
            href={appStoreURL}
            target="_blank"
            rel="noopener noreferrer"
            className="mt-7 inline-flex min-h-13 items-center justify-center rounded-full bg-white px-7 text-base font-semibold text-[var(--charcoal)] transition hover:-translate-y-0.5 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-white"
          >
            Download Bram from App Store
          </Link>
        </section>
      </article>
    </main>
  );
}
