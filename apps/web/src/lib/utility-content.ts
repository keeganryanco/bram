export type UtilityPage = {
  slug: string;
  kind:
    | "oneRepMax"
    | "progressiveOverload"
    | "workoutVolume"
    | "gymSplit"
    | "nextWeekWeight"
    | "prEstimator"
    | "notesConverter";
  title: string;
  description: string;
  intro: string;
  updated: string;
  keywords: string[];
  sections: Array<{
    heading: string;
    body: string[];
  }>;
  faqs: Array<{
    question: string;
    answer: string;
  }>;
  related: string[];
};

export const utilityPages: UtilityPage[] = [
  {
    slug: "1rm-calculator",
    kind: "oneRepMax",
    title: "1RM Calculator",
    description:
      "Estimate your one-rep max, training max, and useful working weights with Bram's free 1RM calculator.",
    intro:
      "Use this 1RM calculator to estimate your max from a hard set. Enter the weight and reps, then use the result to choose smarter working weights.",
    updated: "June 11, 2026",
    keywords: [
      "1RM calculator",
      "one rep max calculator",
      "estimated 1RM",
      "strength calculator",
    ],
    sections: [
      {
        heading: "How to use it",
        body: [
          "Enter a weight you lifted and the reps you completed. A set of 3 to 10 hard reps usually gives the most useful estimate.",
          "Use the training max for everyday programming. It is 90% of the estimated 1RM and gives you a calmer target.",
        ],
      },
      {
        heading: "Where Bram fits",
        body: [
          "Bram remembers these numbers from your workout notes. Write the set naturally, then use your history to see PRs and choose the next target.",
        ],
      },
    ],
    faqs: [
      {
        question: "How accurate is a 1RM calculator?",
        answer:
          "It is an estimate. Sets closer to failure and between 3 and 10 reps usually produce better numbers.",
      },
      {
        question: "Can Bram track my estimated 1RM?",
        answer:
          "Bram tracks sets from your workout notes and turns them into strength history over time.",
      },
    ],
    related: ["pr-estimator", "track-prs", "progressive-overload-calculator"],
  },
  {
    slug: "progressive-overload-calculator",
    kind: "progressiveOverload",
    title: "Progressive Overload Calculator",
    description:
      "Choose your next workout target using last week's weight, reps, and a small jump.",
    intro:
      "Use this progressive overload calculator to decide whether to add weight, add reps, or repeat the same target next week.",
    updated: "June 11, 2026",
    keywords: [
      "progressive overload calculator",
      "best workout tracker for progressive overload",
      "add weight next workout",
      "strength progression calculator",
    ],
    sections: [
      {
        heading: "A simple progression rule",
        body: [
          "If you hit the top of your rep target with solid form, add a small amount of weight next time.",
          "If you missed the target, repeat the same weight and try to add reps.",
        ],
      },
      {
        heading: "Where Bram fits",
        body: [
          "Bram keeps your last workout close. Write your workout like Notes, then check history, PRs, and progress before the next set.",
        ],
      },
    ],
    faqs: [
      {
        question: "How much weight should I add for progressive overload?",
        answer:
          "Most lifters do well with small jumps: 5 lb for barbell upper-body lifts, 10 lb for lower-body lifts, or the smallest jump your gym allows.",
      },
      {
        question: "Should I add weight every workout?",
        answer:
          "Add weight when you hit your rep target with good form. Repeat the same load when the reps are still improving.",
      },
    ],
    related: [
      "progressive-overload-without-spreadsheet",
      "what-weight-should-i-use-next-week",
      "workout-volume-calculator",
    ],
  },
  {
    slug: "workout-volume-calculator",
    kind: "workoutVolume",
    title: "Workout Volume Calculator",
    description:
      "Calculate sets, reps, tonnage, and volume per exercise with Bram's free workout volume calculator.",
    intro:
      "Workout volume is usually sets x reps x weight. Use this calculator to total your training volume and see which exercises drove the session.",
    updated: "June 11, 2026",
    keywords: [
      "workout volume calculator",
      "training volume calculator",
      "sets reps weight calculator",
      "gym volume calculator",
    ],
    sections: [
      {
        heading: "What volume tells you",
        body: [
          "Volume helps you compare similar workouts. If the exercise, range of motion, and effort are similar, more volume usually means more work.",
          "Volume is not the whole story. Keep a short note about form, pain, energy, or effort when it changes the meaning of the numbers.",
        ],
      },
      {
        heading: "Where Bram fits",
        body: [
          "Bram calculates useful training history from your notes, so you can review volume without maintaining a spreadsheet.",
        ],
      },
    ],
    faqs: [
      {
        question: "How do you calculate workout volume?",
        answer:
          "Multiply sets by reps by weight for each exercise. Add exercises together for session volume.",
      },
      {
        question: "Can Bram track workout volume?",
        answer:
          "Bram turns natural workout notes into sets, reps, weights, and progress history, including volume.",
      },
    ],
    related: [
      "workout-log-template",
      "progressive-overload-calculator",
      "notes-to-workout-log-converter",
    ],
  },
  {
    slug: "gym-split-generator",
    kind: "gymSplit",
    title: "Gym Split Generator",
    description:
      "Generate a simple lifting split based on days per week, goal, and session length.",
    intro:
      "Use this gym split generator to pick a simple weekly structure. Choose your training days, goal, and session length.",
    updated: "June 11, 2026",
    keywords: [
      "gym split generator",
      "workout split generator",
      "lifting split generator",
      "simple gym split",
    ],
    sections: [
      {
        heading: "Keep the split easy to repeat",
        body: [
          "The best split is one you can run for several weeks. Start simple, then adjust volume and exercise selection from your logs.",
          "A split gives structure. Your workout notes show whether the structure is working.",
        ],
      },
      {
        heading: "Where Bram fits",
        body: [
          "Bram does not force a routine setup. You can follow any split, write each workout naturally, and keep progress history.",
        ],
      },
    ],
    faqs: [
      {
        question: "What is the best gym split?",
        answer:
          "The best split fits your weekly schedule and lets each muscle recover before the next hard session.",
      },
      {
        question: "Can Bram track any workout split?",
        answer:
          "Yes. Bram works with push/pull/legs, upper/lower, full body, bro splits, and notes-first training.",
      },
    ],
    related: [
      "workout-tracker-without-routine-setup",
      "simple-gym-log-app",
      "workout-log-template",
    ],
  },
  {
    slug: "what-weight-should-i-use-next-week",
    kind: "nextWeekWeight",
    title: "What Weight Should I Use Next Week?",
    description:
      "Estimate next week's lifting target from your current weight, reps, rep goal, and jump size.",
    intro:
      "Use this calculator when you know last week's set and need a practical next target.",
    updated: "June 11, 2026",
    keywords: [
      "what weight should I use next week",
      "what weight should I lift next workout",
      "next week weight calculator",
      "progressive overload target",
    ],
    sections: [
      {
        heading: "The practical rule",
        body: [
          "Hit the top of the rep range with good form, then add the smallest useful jump.",
          "Miss the rep target, then keep the same weight and aim for more reps next time.",
        ],
      },
      {
        heading: "Where Bram fits",
        body: [
          "Bram keeps the last target visible in your workout history, so choosing next week's weight takes seconds.",
        ],
      },
    ],
    faqs: [
      {
        question: "Should I increase weight or reps first?",
        answer:
          "Most lifters should add reps until they reach the top of the target range, then add a small amount of weight.",
      },
      {
        question: "Can Bram suggest next weights?",
        answer:
          "Bram keeps your workout history and surfaces useful progress context from the notes you write.",
      },
    ],
    related: [
      "progressive-overload-calculator",
      "1rm-calculator",
      "track-prs",
    ],
  },
  {
    slug: "pr-estimator",
    kind: "prEstimator",
    title: "PR Estimator",
    description:
      "Estimate rep PRs and strength targets from a recent set.",
    intro:
      "Use this PR estimator to turn one hard set into realistic targets for other rep ranges.",
    updated: "June 11, 2026",
    keywords: [
      "PR estimator",
      "rep PR calculator",
      "strength PR calculator",
      "gym PR estimator",
    ],
    sections: [
      {
        heading: "How to use PR targets",
        body: [
          "Use the estimate to pick a smart attempt. A recent hard set of 225 for 5 can guide targets for 3 reps, 8 reps, or a single.",
          "Do not chase every estimate. Use it to make the next workout more precise.",
        ],
      },
      {
        heading: "Where Bram fits",
        body: [
          "Bram tracks PRs from your workout notes and keeps them tied to the exercise history.",
        ],
      },
    ],
    faqs: [
      {
        question: "What is a rep PR?",
        answer:
          "A rep PR is your best set at a specific weight or rep count, such as 185 for 8.",
      },
      {
        question: "Can Bram track rep PRs?",
        answer:
          "Bram turns your logged sets into progress history and highlights useful PRs.",
      },
    ],
    related: ["track-prs", "1rm-calculator", "progressive-overload-calculator"],
  },
  {
    slug: "notes-to-workout-log-converter",
    kind: "notesConverter",
    title: "Notes to Workout Log Converter",
    description:
      "Paste a workout note and convert it into a simple structured workout log.",
    intro:
      "Paste a lifting note into this demo to see how plain text can become a cleaner workout log.",
    updated: "June 11, 2026",
    keywords: [
      "notes to workout log converter",
      "workout note parser",
      "freeform workout logger",
      "Apple Notes workout tracker",
    ],
    sections: [
      {
        heading: "What this demo shows",
        body: [
          "A normal workout note already has structure: exercise names, sets, reps, weights, and notes.",
          "Bram is built around this idea. Write naturally, then let the app remember the useful training details.",
        ],
      },
      {
        heading: "Where Bram fits",
        body: [
          "This page is a simple demo. The Bram app keeps the full workout history, PRs, and progress on your iPhone.",
        ],
      },
    ],
    faqs: [
      {
        question: "Can workout notes become a workout log?",
        answer:
          "Yes. Clear notes with exercise names, weights, reps, and sets can become structured workout history.",
      },
      {
        question: "Does Bram convert notes into workout data?",
        answer:
          "Yes. Bram is designed to turn natural workout notes into structured progress history.",
      },
    ],
    related: [
      "track-workouts-in-apple-notes",
      "workout-log-template",
      "notes-style-workout-tracker",
    ],
  },
];

export const utilityPageBySlug = new Map(
  utilityPages.map((utilityPage) => [utilityPage.slug, utilityPage]),
);
