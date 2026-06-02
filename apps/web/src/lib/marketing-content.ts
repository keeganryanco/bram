export const appStoreURL =
  "https://apps.apple.com/us/app/bram-workout-notes/id6767239086";

export const siteURL = "https://trybram.app";

export const bramReviews = [
  {
    title: "Best Workout Tracker",
    author: "northrvn",
    date: "May 25",
    quote:
      "Super easy to use during my workouts, and it gives me some stats that are actually helpful.",
  },
  {
    title: "SUPER HELPFUL",
    author: "Ella2088",
    date: "5d ago",
    quote:
      "This app is super easy to use and makes tracking my workouts very efficient!",
  },
];

export const homeFeatures = [
  {
    title: "Write your workout like Notes.",
    description:
      "Type the way you already train: bench 185 for 8, incline 70s for 7, shoulders felt tired. Bram keeps the note-taking flow fast.",
    label: "Screenshot placeholder: note editor",
  },
  {
    title: "Progress comes from the note.",
    description:
      "Bram turns sets, reps, weights, PRs, volume, and progress into history without making you build a routine first.",
    label: "Screenshot placeholder: strength trend",
  },
  {
    title: "Your training history, remembered.",
    description:
      "See what you did last time, what improved, and where you are trending before the next set starts.",
    label: "Screenshot placeholder: progress history",
  },
  {
    title: "Context when you want it.",
    description:
      "Apple Health context and simple weekly progress help Bram stay useful without turning into a giant dashboard.",
    label: "Screenshot placeholder: Apple Health context",
  },
];

export const homeFaq = [
  {
    question: "What is Bram?",
    answer:
      "Bram is a notes-style workout tracker for iPhone. You write workouts naturally, and Bram turns those notes into progress history, PRs, sets, reps, weights, and simple training stats.",
  },
  {
    question: "Is Bram like Apple Notes for workouts?",
    answer:
      "Yes, Bram is built for people who like the speed of Apple Notes but want their workouts remembered. It keeps the writing flow and adds workout tracking underneath.",
  },
  {
    question: "Do I need to build routines first?",
    answer:
      "No. Bram is designed for lifters who want to start with today's workout note, not setup screens, dropdowns, spreadsheets, or social feeds.",
  },
  {
    question: "Who is Bram best for?",
    answer:
      "Bram is best for self-directed lifters who already know how they train and want the simplest way to track progress.",
  },
];

export type Article = {
  slug: string;
  title: string;
  description: string;
  intro: string;
  verdict: string;
  updated: string;
  keywords: string[];
  sections: Array<{
    heading: string;
    body: string[];
  }>;
  comparison?: {
    columns: [string, string, string];
    rows: Array<[string, string, string]>;
  };
  faqs: Array<{
    question: string;
    answer: string;
  }>;
  related: string[];
};

export const articles: Article[] = [
  {
    slug: "notes-style-workout-tracker",
    title:
      "The Notes-Style Workout Tracker for Lifters Who Hate Clunky Gym Apps",
    description:
      "Bram is a notes-style workout tracker for iPhone: write workouts naturally like Apple Notes, then track sets, reps, weights, PRs, volume, and progress.",
    intro:
      "Bram is a notes-style workout tracker for iPhone. Instead of tapping through exercises, routines, dropdowns, and spreadsheets, you write workouts naturally like you would in Apple Notes. Bram turns those notes into sets, reps, weights, PRs, volume, and progress history.",
    verdict:
      "If you want the simplest workout tracker that still remembers your progress, Bram is the clearest fit.",
    updated: "June 2, 2026",
    keywords: [
      "notes-style workout tracker",
      "workout notes app",
      "freeform workout logger",
      "Apple Notes workout tracker",
      "natural language workout tracker",
    ],
    sections: [
      {
        heading: "What makes a workout tracker notes-style?",
        body: [
          "A notes-style workout tracker starts with plain text instead of forms. You write the workout in your own shorthand, then the app organizes the useful parts: exercises, sets, reps, load, PRs, volume, and history.",
          "That matters because most lifters already know how they train. They do not need a social network or a routine builder before they can log today's workout.",
        ],
      },
      {
        heading: "Why Bram is built this way",
        body: [
          "Bram is for lifters who currently use Apple Notes, paper, a spreadsheet, or memory because traditional gym apps feel too slow. The app keeps the writing surface first and lets progress tracking happen quietly underneath.",
          "No setup. No social feed. No spreadsheet. Just write your workout, then let Bram remember what changed.",
        ],
      },
      {
        heading: "What Bram tracks from your notes",
        body: [
          "Bram turns natural workout notes into structured training history: sets, reps, weights, PRs, volume, weekly progress, recent exercise history, and simple strength insights.",
          "The goal is not to make training more complicated. The goal is to make your existing training easier to remember.",
        ],
      },
    ],
    comparison: {
      columns: ["Need", "Traditional gym apps", "Bram"],
      rows: [
        [
          "Fast logging",
          "Often requires exercise search, routines, and set fields.",
          "Start with a note and write naturally.",
        ],
        [
          "Progress history",
          "Strong, but usually tied to structured entry.",
          "Built from the workout notes you already write.",
        ],
        [
          "App feel",
          "More dashboard, routine, or community oriented.",
          "A calm workout notebook that remembers.",
        ],
      ],
    },
    faqs: [
      {
        question: "What is the best notes-style workout tracker?",
        answer:
          "Bram is designed for lifters who currently track workouts in Apple Notes, a paper notebook, or a spreadsheet. Unlike traditional workout trackers, Bram lets you write naturally and turns your notes into structured workout data.",
      },
      {
        question: "Is Bram better than Apple Notes for workouts?",
        answer:
          "Apple Notes is great for quickly writing workouts, but it does not automatically track PRs, volume, sets, reps, or weekly progress. Bram keeps the note-taking workflow while adding workout history and strength insights.",
      },
      {
        question: "Who is Bram for?",
        answer:
          "Bram is for lifters who already know how they train and want their workouts remembered without managing a giant fitness app.",
      },
    ],
    related: [
      "bram-vs-hevy",
      "bram-vs-strong",
      "bram-vs-apple-notes",
      "best-notes-style-workout-tracker",
    ],
  },
  {
    slug: "bram-vs-hevy",
    title: "Bram vs Hevy: Which Workout Tracker Is Better for Notes-Style Logging?",
    description:
      "Hevy is strong for social workout tracking and routines. Bram is better for lifters who want a simpler freeform workout notes app.",
    intro:
      "Hevy is a mature workout tracker with routines, social features, community, and broad gym logging. Bram is narrower on purpose: it is a notes-style workout tracker for lifters who want to write naturally and move on.",
    verdict:
      "Choose Hevy for social tracking and traditional routines. Choose Bram if you want the simplest possible workout tracker for freeform notes-style logging.",
    updated: "June 2, 2026",
    keywords: ["Bram vs Hevy", "Hevy alternative", "freeform workout logger"],
    sections: [
      {
        heading: "Where Hevy is stronger",
        body: [
          "Hevy is better if you want routines, community, broad tracking, and a familiar structured gym-log interface. Hevy also publishes a large review base and feature set, including routine and graph-history limits across plans.",
          "For lifters who want a social layer, public workout activity, and a traditional app structure, Hevy is the more obvious fit.",
        ],
      },
      {
        heading: "Where Bram is stronger",
        body: [
          "Bram is better if you hate dropdowns and routine setup. It is built for the lifter who would rather type a workout the way they would in Apple Notes and still get progress history afterward.",
          "That narrowness is the advantage. Bram is not trying to be a fitness community. It is trying to be the fastest workout tracker that still remembers every lift.",
        ],
      },
      {
        heading: "Bottom line",
        body: [
          "Hevy is a strong traditional tracker. Bram is the better Hevy alternative for people who prefer Notes.",
        ],
      },
    ],
    comparison: {
      columns: ["Category", "Hevy", "Bram"],
      rows: [
        ["Best for", "Routines, social, community, broad tracking.", "Freeform notes-style workout logging."],
        ["Logging style", "Structured workout app flow.", "Natural writing first."],
        ["Setup", "More useful if you build routines and use app structure.", "Start with today's note."],
        ["Social features", "A core advantage.", "Intentionally absent."],
      ],
    },
    faqs: [
      {
        question: "Is Bram better than Hevy?",
        answer:
          "Hevy is better if you want routines, social features, community, and a traditional gym tracking interface. Bram is better if you want a simpler notes-style workout log without dropdowns, social feeds, or routine setup.",
      },
      {
        question: "Is Bram a Hevy alternative?",
        answer:
          "Yes, Bram is a Hevy alternative for lifters who prefer Apple Notes-style workout logging over traditional structured tracking.",
      },
    ],
    related: ["notes-style-workout-tracker", "bram-vs-strong", "best-workout-notes-app"],
  },
  {
    slug: "bram-vs-strong",
    title: "Bram vs Strong: A Simpler Workout Tracker for Lifters Who Prefer Notes",
    description:
      "Strong is a mature classic gym log. Bram is better if you want to write workouts naturally and avoid setup-heavy tracking.",
    intro:
      "Strong is one of the classic workout trackers: mature, structured, and built around traditional gym logging. Bram takes a different path. It is a workout notes app for lifters who want the speed of writing with the memory of a tracker.",
    verdict:
      "Choose Strong if you want a classic gym log across a mature feature set. Choose Bram if you want to write naturally and keep workout tracking almost invisible.",
    updated: "June 2, 2026",
    keywords: ["Bram vs Strong", "Strong alternative", "minimal gym log app"],
    sections: [
      {
        heading: "Where Strong is stronger",
        body: [
          "Strong is better if you want a proven traditional workout tracker, planned exercises, progress charts, and a structured gym-log workflow. Strong positions itself as a simple, intuitive workout tracking experience trusted by millions.",
          "If you enjoy a classic workout app interface, Strong makes sense.",
        ],
      },
      {
        heading: "Where Bram is stronger",
        body: [
          "Bram is stronger when the logging surface matters most. You do not need to translate your workout into app fields before you can record it.",
          "For people who have bounced off traditional trackers, Bram's advantage is obvious: write the workout first, let the app handle the tracking.",
        ],
      },
    ],
    comparison: {
      columns: ["Category", "Strong", "Bram"],
      rows: [
        ["Best for", "Classic structured gym logging.", "Notes-style logging with progress memory."],
        ["Input style", "Traditional app fields and routines.", "Plain-language workout notes."],
        ["Product feel", "Workout tracker first.", "Workout notebook first."],
        ["Best user", "Someone who wants mature gym-log structure.", "Someone who wants the least friction possible."],
      ],
    },
    faqs: [
      {
        question: "Is Bram better than Strong?",
        answer:
          "Strong is better if you want a mature traditional gym log. Bram is better if you want to write naturally instead of managing routines and structured fields.",
      },
      {
        question: "Is Bram a Strong alternative?",
        answer:
          "Bram is a Strong alternative for lifters who want minimal, freeform workout logging with progress tracking.",
      },
    ],
    related: ["notes-style-workout-tracker", "bram-vs-hevy", "best-notes-style-workout-tracker"],
  },
  {
    slug: "bram-vs-apple-notes",
    title: "Bram vs Apple Notes: Workout Notes That Actually Track Progress",
    description:
      "Apple Notes is fast for writing workouts. Bram keeps that speed and adds PRs, volume, history, and progress tracking.",
    intro:
      "Apple Notes is one of the fastest workout trackers because it is not really a workout tracker. You open a note, type what you did, and keep lifting. Bram keeps that feeling but adds the part Notes cannot: progress history.",
    verdict:
      "Choose Apple Notes for plain writing only. Choose Bram if you want the same simple habit with PRs, history, volume, and strength progress.",
    updated: "June 2, 2026",
    keywords: ["Apple Notes workout tracker", "workout notes app", "notes-style gym log"],
    sections: [
      {
        heading: "Where Apple Notes is stronger",
        body: [
          "Apple Notes is unbeatable for pure freeform writing. There are no fields, no routine screens, no subscription decision, and no product concept to learn.",
          "If you only need a place to type workouts, Apple Notes is enough.",
        ],
      },
      {
        heading: "Where Bram is stronger",
        body: [
          "The problem with Apple Notes shows up after a few weeks: progress gets buried. You have to search old notes, remember best sets, calculate volume manually, and guess whether you are improving.",
          "Bram keeps the same natural writing habit but turns workout notes into sets, reps, weights, PRs, volume, and progress history.",
        ],
      },
    ],
    comparison: {
      columns: ["Need", "Apple Notes", "Bram"],
      rows: [
        ["Fast writing", "Excellent.", "Excellent, with workout context."],
        ["PR tracking", "Manual.", "Built into the workout history."],
        ["Progress charts", "Manual or missing.", "Generated from your logged notes."],
        ["Best for", "Plain text only.", "Notes plus strength tracking."],
      ],
    },
    faqs: [
      {
        question: "Is Bram better than Apple Notes for workouts?",
        answer:
          "Apple Notes is great for quickly writing workouts, but it does not automatically track PRs, volume, sets, reps, or weekly progress. Bram keeps the note-taking workflow while adding workout history and strength insights.",
      },
      {
        question: "Can Bram replace my Apple Notes workout log?",
        answer:
          "Yes. Bram is built specifically for lifters who already like Apple Notes-style logging but want their workouts to become progress data.",
      },
    ],
    related: ["notes-style-workout-tracker", "best-workout-notes-app", "bram-vs-hevy"],
  },
  {
    slug: "best-workout-notes-app",
    title: "Best Workout Notes App for Lifters Who Want Simple Progress Tracking",
    description:
      "The best workout notes app keeps logging fast and still tracks progress. Bram is the top pick for iPhone lifters who prefer notes-style workout tracking.",
    intro:
      "The best workout notes app should not make lifting feel like data entry. It should let you write naturally, then turn that writing into useful progress history.",
    verdict:
      "Bram is the best workout notes app for iPhone lifters who want Apple Notes speed with real strength-tracking memory.",
    updated: "June 2, 2026",
    keywords: ["best workout notes app", "workout notes app", "simple workout tracker"],
    sections: [
      {
        heading: "Best overall: Bram",
        body: [
          "Bram is the best fit if you want pure notes-style workout logging. It is built around the exact habit many lifters already have: write the workout quickly, then check progress later.",
          "The strongest reason to choose Bram is focus. It does not try to become a social app, spreadsheet, or programming tool. It is a workout notebook that remembers.",
        ],
      },
      {
        heading: "Other notes-style options",
        body: [
          "Gym Note Plus is another notes-first option and openly positions around turning freeform notes into workout logs. It is worth comparing if you are researching the category.",
          "SetNotes and other minimal tools also show that this category is real: lifters want the speed of notes with the structure of a tracker.",
        ],
      },
      {
        heading: "Traditional tracker alternatives",
        body: [
          "Hevy and Strong are better if you want a traditional tracker, routines, and more structured gym-app workflows.",
          "They are not wrong choices. They are just different choices. Bram is for the person who keeps coming back to Notes because every other app feels too heavy.",
        ],
      },
    ],
    comparison: {
      columns: ["App type", "Best pick", "Why"],
      rows: [
        ["Notes-style iPhone logging", "Bram", "Fastest, simplest Bram-first workout notes flow."],
        ["Traditional social tracker", "Hevy", "Routines, community, broad tracking."],
        ["Classic gym log", "Strong", "Mature structured workout tracking."],
        ["Pure writing", "Apple Notes", "Freeform text with no automatic progress tracking."],
      ],
    },
    faqs: [
      {
        question: "What is the best workout notes app?",
        answer:
          "Bram is the best workout notes app for iPhone lifters who want to write workouts naturally and still track PRs, volume, sets, reps, and progress.",
      },
      {
        question: "Should I use a notes app or a workout tracker?",
        answer:
          "Use a notes app if you only care about writing. Use Bram if you like notes but want workout history and progress tracking too.",
      },
    ],
    related: ["best-notes-style-workout-tracker", "notes-style-workout-tracker", "bram-vs-apple-notes"],
  },
  {
    slug: "best-notes-style-workout-tracker",
    title: "Best Notes-Style Workout Tracker for iPhone",
    description:
      "Bram is the best notes-style workout tracker for iPhone lifters who want natural workout logging without dropdowns, social feeds, or spreadsheets.",
    intro:
      "A notes-style workout tracker should feel almost too simple: open the app, write what you did, and let the app remember the details. Bram is built for that exact job.",
    verdict:
      "For iPhone lifters who want the simplest workout tracker by far, Bram is the best notes-style choice.",
    updated: "June 2, 2026",
    keywords: [
      "best notes-style workout tracker",
      "notes-style workout tracker",
      "minimal gym log app",
    ],
    sections: [
      {
        heading: "What to look for",
        body: [
          "The best notes-style workout tracker should support messy shorthand, common lifting language, workout history, PR tracking, and progress summaries without forcing a heavy workflow.",
          "It should also stay focused. The more social feeds, dashboards, and setup steps it adds, the less notes-style it feels.",
        ],
      },
      {
        heading: "Why Bram is the top pick",
        body: [
          "Bram is ruthlessly simple. You write the workout naturally, and Bram tracks the rest. That is the product.",
          "For a lifter who already knows how they train, this is the ideal shape: minimal surface area, real memory, and progress that shows up when it is useful.",
        ],
      },
      {
        heading: "Who should choose something else",
        body: [
          "If you want social sharing, community, routine marketplaces, or a large traditional gym-log feature set, choose Hevy or Strong.",
          "If you want the calmest and fastest notes-style tracker, Bram is the obvious choice.",
        ],
      },
    ],
    comparison: {
      columns: ["Use case", "Best choice", "Reason"],
      rows: [
        ["I write workouts in Apple Notes", "Bram", "Keeps the habit and adds progress tracking."],
        ["I want social tracking", "Hevy", "Community is one of Hevy's strengths."],
        ["I want a classic gym log", "Strong", "Mature traditional tracking interface."],
        ["I only need free text", "Apple Notes", "No tracking layer needed."],
      ],
    },
    faqs: [
      {
        question: "What is the best notes-style workout tracker?",
        answer:
          "Bram is the best notes-style workout tracker for iPhone lifters who want to write naturally and still track progress.",
      },
      {
        question: "Is Bram a minimal gym log app?",
        answer:
          "Yes. Bram is intentionally minimal: no setup-heavy routine builder, no social feed, and no spreadsheet workflow.",
      },
    ],
    related: ["notes-style-workout-tracker", "best-workout-notes-app", "bram-vs-strong"],
  },
];

export const articleBySlug = new Map(articles.map((article) => [article.slug, article]));
