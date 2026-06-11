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
    image: "https://trybram.app/screenshots/bram_website_card_1.png",
  },
  {
    title: "Progress comes from the note.",
    description:
      "Bram turns sets, reps, weights, PRs, volume, and progress into history without making you build a routine first.",
    image: "https://trybram.app/screenshots/bram_website_card_2.png",
  },
  {
    title: "Your training history, remembered.",
    description:
      "See what you did last time, what improved, and where you are trending before the next set starts.",
    image: "https://trybram.app/screenshots/bram_website_card_3.png",
  },
  {
    title: "Context when you want it.",
    description:
      "Apple Health context and simple weekly progress help Bram stay useful without turning into a giant dashboard.",
    image: "https://trybram.app/screenshots/bram_website_card_4.png",
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
      "Yes, Bram is built for people who like the speed of Apple Notes and want their workouts remembered. It keeps the writing flow and adds workout tracking underneath.",
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
          "A notes-style workout tracker starts with plain text. You write the workout in your own shorthand, then the app organizes the useful parts: exercises, sets, reps, load, PRs, volume, and history.",
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
          "Strong history after structured entry.",
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
          "Bram is designed for lifters who currently track workouts in Apple Notes, a paper notebook, or a spreadsheet. Bram lets you write naturally and turns your notes into structured workout data.",
      },
      {
        question: "Is Bram better than Apple Notes for workouts?",
        answer:
          "Apple Notes is great for quickly writing workouts. Bram keeps the note-taking workflow while adding workout history, PRs, volume, sets, reps, and strength insights.",
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
          "Strong is better if you want a mature traditional gym log. Bram is better if you want natural writing, lighter setup, and notes-first progress tracking.",
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
      "Apple Notes is one of the fastest workout trackers because it is a clean writing surface. You open a note, type what you did, and keep lifting. Bram keeps that feeling and adds progress history.",
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
          "Bram keeps the same natural writing habit and turns workout notes into sets, reps, weights, PRs, volume, and progress history.",
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
          "Apple Notes is great for quickly writing workouts. Bram keeps the note-taking workflow while adding workout history, PRs, volume, sets, reps, and strength insights.",
      },
      {
        question: "Can Bram replace my Apple Notes workout log?",
        answer:
          "Yes. Bram is built specifically for lifters who already like Apple Notes-style logging and want their workouts to become progress data.",
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
          "Use a notes app for raw writing. Use Bram for notes with workout history and progress tracking.",
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
  {
    slug: "progressive-overload-without-spreadsheet",
    title: "How to Track Progressive Overload Without a Spreadsheet",
    description:
      "A simple way to track progressive overload with notes, PRs, history, and Bram.",
    intro:
      "Progressive overload starts with a clear record: exercise, sets, reps, load, and one useful note. The hard part is keeping that record close during the next workout.",
    verdict:
      "Bram is the clean iPhone method: write the workout like a note, then use the history to add weight, reps, or sets at the right time.",
    updated: "June 11, 2026",
    keywords: [
      "best workout tracker for progressive overload",
      "track progressive overload",
      "progressive overload workout tracker",
      "workout tracker without spreadsheet",
    ],
    sections: [
      {
        heading: "The simple method",
        body: [
          "Track the exercise name, working sets, reps, load, and how the last set felt. Your next workout should start from that record.",
          "Apple Notes works when you search old entries. A spreadsheet works when you keep it updated. Bram keeps the writing flow and the training history together.",
        ],
      },
      {
        heading: "A note format that works",
        body: [
          "Write one exercise per block: Bench press, 185 for 5, 185 for 5, 185 for 6, next target 190 for 5.",
          "That gives you the decision for next time. Add a rep, add a small amount of weight, or repeat the same load with cleaner form.",
        ],
      },
      {
        heading: "Where Bram fits",
        body: [
          "Bram reads the workout note and remembers PRs, recent sets, volume, and progress history. You get the useful parts of a spreadsheet from a normal lifting note.",
        ],
      },
    ],
    comparison: {
      columns: ["Method", "What you do", "What you get"],
      rows: [
        ["Apple Notes", "Write sets in plain text.", "Fast capture with manual history checks."],
        ["Spreadsheet", "Enter rows and formulas.", "Flexible tracking with more maintenance."],
        ["Bram", "Write the workout naturally.", "Notes plus PRs, history, and progress."],
      ],
    },
    faqs: [
      {
        question: "What should I track for progressive overload?",
        answer:
          "Track exercise, sets, reps, load, and one effort cue. Bram turns that simple note into progress history.",
      },
      {
        question: "Do I need a spreadsheet for progressive overload?",
        answer:
          "No. A spreadsheet is useful, though many lifters can progress with clear workout notes and reliable exercise history.",
      },
    ],
    related: [
      "track-prs",
      "workout-log-template",
      "notes-style-workout-tracker",
    ],
  },
  {
    slug: "track-workouts-in-apple-notes",
    title: "How to Track Workouts in Apple Notes",
    description:
      "A simple Apple Notes workout tracking method, plus the Bram upgrade for PRs and history.",
    intro:
      "Apple Notes is fast because it gets out of the way. Open a note, write the workout, and keep lifting.",
    verdict:
      "Use Apple Notes for raw capture. Use Bram when you want that same speed with PRs, exercise history, and progress.",
    updated: "June 11, 2026",
    keywords: [
      "how to track workouts in Apple Notes",
      "Apple Notes workout tracker",
      "notes app for lifting",
      "workout notes app",
    ],
    sections: [
      {
        heading: "Use a repeatable note format",
        body: [
          "Start each workout with the date, then list exercises in blocks. Example: Incline press, 70s for 8, 8, 7. Add a short note if it changes the next workout.",
          "Keep names consistent. Bench press and barbell bench should not become five different labels across the month.",
        ],
      },
      {
        heading: "Review your last workout",
        body: [
          "Before a lift, search the exercise name and check your last working sets. That is enough to choose the next target.",
          "The manual part is the cost. You need to search, compare, and remember your best sets yourself.",
        ],
      },
      {
        heading: "Bram is the Notes upgrade",
        body: [
          "Bram keeps the same writing habit and turns the note into sets, reps, weights, PRs, and progress history.",
        ],
      },
    ],
    comparison: {
      columns: ["Need", "Apple Notes", "Bram"],
      rows: [
        ["Fast capture", "Excellent.", "Excellent."],
        ["Exercise history", "Manual search.", "Built from your notes."],
        ["PRs", "Manual memory.", "Tracked from logged workouts."],
      ],
    },
    faqs: [
      {
        question: "Can I track workouts in Apple Notes?",
        answer:
          "Yes. Use consistent exercise names, write sets clearly, and review old notes before each lift.",
      },
      {
        question: "What is better than Apple Notes for lifting?",
        answer:
          "Bram keeps the note-taking workflow and adds workout history, PRs, and progress tracking.",
      },
    ],
    related: [
      "bram-vs-apple-notes",
      "notes-app-for-lifting",
      "workout-log-template",
    ],
  },
  {
    slug: "workout-log-template",
    title: "Simple Workout Log Template for Lifters",
    description:
      "A clean workout log template for strength training, Apple Notes, and Bram.",
    intro:
      "A good workout log should be short enough to use during a hard set and clear enough to guide the next session.",
    verdict:
      "The best template is a normal lifting note: exercise, load, reps, sets, and one next-step cue. Bram turns that note into history.",
    updated: "June 11, 2026",
    keywords: [
      "workout log template",
      "gym log template",
      "lifting log template",
      "workout notes template",
    ],
    sections: [
      {
        heading: "Copy this format",
        body: [
          "Date. Main lift. Working sets. Accessories. One note for the next workout.",
          "Example: Bench press: 185 x 5, 185 x 5, 185 x 6. Incline press: 70s x 8, 8, 7. Note: try 190 on bench next push day.",
        ],
      },
      {
        heading: "Keep it useful",
        body: [
          "Skip extra fields during the workout. Add effort, soreness, or form notes only when they affect the next session.",
          "Consistent exercise names matter more than perfect formatting.",
        ],
      },
      {
        heading: "Use Bram for the history",
        body: [
          "Bram lets you write in this same format and keeps track of PRs, volume, recent sets, and progress.",
        ],
      },
    ],
    comparison: {
      columns: ["Field", "Example", "Why it matters"],
      rows: [
        ["Exercise", "Bench press", "Makes history searchable."],
        ["Sets", "185 x 5, 5, 6", "Shows the next target."],
        ["Note", "Try 190 next", "Turns the log into a plan."],
      ],
    },
    faqs: [
      {
        question: "What should be in a workout log?",
        answer:
          "Track date, exercise, load, reps, sets, and a short note when it helps the next workout.",
      },
      {
        question: "Can Bram use a workout log template?",
        answer:
          "Yes. Bram is built for plain workout notes, so simple templates work well.",
      },
    ],
    related: [
      "track-workouts-in-apple-notes",
      "progressive-overload-without-spreadsheet",
      "track-prs",
    ],
  },
  {
    slug: "simple-gym-log-app",
    title: "Simple Gym Log App for Lifters Who Want Fast Tracking",
    description:
      "Bram is a simple gym log app for iPhone lifters who prefer notes-style workout tracking.",
    intro:
      "A simple gym log app should make the workout easier to record in the moment and easier to review next time.",
    verdict:
      "Bram is the simple gym log for lifters who want to write naturally and still get progress history.",
    updated: "June 11, 2026",
    keywords: [
      "simple gym log app",
      "minimal gym log app",
      "simple workout tracker",
      "workout tracker for lifters",
    ],
    sections: [
      {
        heading: "What simple should mean",
        body: [
          "Open the app, write the workout, check your last numbers, and move on. That is the core job.",
          "A simple gym log should still remember exercise history, PRs, and recent volume.",
        ],
      },
      {
        heading: "Why Bram works",
        body: [
          "Bram starts with the note. You can write bench 185 for 5 or curls 30s for 12 in the language you already use.",
          "Bram then organizes the useful details so your next workout has context.",
        ],
      },
    ],
    comparison: {
      columns: ["Need", "Typical tracker", "Bram"],
      rows: [
        ["Logging", "Tap through fields.", "Write a workout note."],
        ["History", "Available after structured entry.", "Built from notes."],
        ["Focus", "Many features.", "Fast lifting notes."],
      ],
    },
    faqs: [
      {
        question: "What is the simplest gym log app?",
        answer:
          "Bram is built to be the simplest gym log app for iPhone lifters who like notes-style tracking.",
      },
      {
        question: "Does a simple gym log still track progress?",
        answer:
          "Yes. Bram keeps logging simple and tracks PRs, volume, recent sets, and exercise history.",
      },
    ],
    related: [
      "notes-style-workout-tracker",
      "workout-tracker-without-routine-setup",
      "best-workout-notes-app",
    ],
  },
  {
    slug: "track-prs",
    title: "How to Track PRs in the Gym",
    description:
      "A simple method for tracking gym PRs, rep PRs, and progress in Bram.",
    intro:
      "A PR is only useful if you can find it during the next workout. Track the best set, the date, and the context.",
    verdict:
      "Bram tracks PRs from your workout notes, so your best sets stay connected to the exercises you actually train.",
    updated: "June 11, 2026",
    keywords: [
      "how to track PRs",
      "track gym PRs",
      "workout PR tracker",
      "strength PR tracker",
    ],
    sections: [
      {
        heading: "Track more than one kind of PR",
        body: [
          "Keep heaviest weight, best reps at a weight, and best set volume. A lifter can improve before a new one-rep max appears.",
          "For hypertrophy work, rep PRs often tell the better story.",
        ],
      },
      {
        heading: "Write PR-friendly notes",
        body: [
          "Use clear set lines: Squat 275 x 5, 275 x 5, 275 x 6. Add a note when form, range of motion, or effort changes the meaning.",
        ],
      },
      {
        heading: "Let Bram remember",
        body: [
          "Bram turns those notes into exercise history and highlights progress so you can see what improved.",
        ],
      },
    ],
    comparison: {
      columns: ["PR type", "Example", "Use"],
      rows: [
        ["Load PR", "225 x 1", "Max strength marker."],
        ["Rep PR", "185 x 8", "Progress at a working weight."],
        ["Volume PR", "70s x 12", "Useful for accessories."],
      ],
    },
    faqs: [
      {
        question: "What PRs should I track?",
        answer:
          "Track heaviest weight, best reps at a weight, and best set volume. Bram can surface these from workout notes.",
      },
      {
        question: "Can Bram track PRs automatically?",
        answer:
          "Bram turns natural workout notes into progress history and highlights PRs from your logged lifts.",
      },
    ],
    related: [
      "progressive-overload-without-spreadsheet",
      "workout-log-template",
      "simple-gym-log-app",
    ],
  },
  {
    slug: "notes-app-for-lifting",
    title: "Best Notes App for Lifting",
    description:
      "The best notes app for lifting is fast during the workout and useful before the next set. Bram is built for that job.",
    intro:
      "A lifting note has to survive the gym floor. It needs fast entry, clear history, and enough structure to guide the next workout.",
    verdict:
      "Bram is the notes app for lifting when you want Apple Notes speed with strength-tracking memory.",
    updated: "June 11, 2026",
    keywords: [
      "notes app for lifting",
      "workout notes app",
      "lifting notes app",
      "gym notes app",
    ],
    sections: [
      {
        heading: "What lifters need from notes",
        body: [
          "Fast entry matters first. You should be able to write your set before the rest timer ends.",
          "The note should also give you your last numbers, PRs, and recent progress when you need them.",
        ],
      },
      {
        heading: "Apple Notes is a good start",
        body: [
          "Apple Notes is excellent for raw text. The missing piece is workout memory: PRs, exercise history, volume, and trends.",
        ],
      },
      {
        heading: "Bram is purpose-built",
        body: [
          "Bram keeps the note-taking feel and adds the training layer. That makes it the stronger choice for lifters.",
        ],
      },
    ],
    comparison: {
      columns: ["Option", "Strength", "Tradeoff"],
      rows: [
        ["Apple Notes", "Fast text capture.", "Manual workout history."],
        ["Spreadsheet", "Custom analysis.", "More upkeep."],
        ["Bram", "Fast notes plus lifting history.", "iPhone-focused."],
      ],
    },
    faqs: [
      {
        question: "What is the best notes app for lifting?",
        answer:
          "Bram is the best notes app for lifters who want natural writing plus workout history, PRs, and progress tracking.",
      },
      {
        question: "Can I use Apple Notes for lifting?",
        answer:
          "Yes. Apple Notes works for raw logging. Bram adds lifting-specific memory to the same habit.",
      },
    ],
    related: [
      "track-workouts-in-apple-notes",
      "bram-vs-apple-notes",
      "workout-log-template",
    ],
  },
  {
    slug: "fitbod-alternative",
    title: "Fitbod Alternative for Lifters Who Already Know Their Workouts",
    description:
      "Fitbod builds personalized workout plans. Bram is the Fitbod alternative for lifters who want notes-style tracking and progress history.",
    intro:
      "Fitbod is built around personalized workout planning, goals, equipment, and recovery. Bram is built around fast workout notes and progress memory.",
    verdict:
      "Choose Bram as your Fitbod alternative when you already know how you train and want the cleanest way to log it.",
    updated: "June 11, 2026",
    keywords: [
      "Fitbod alternative",
      "Fitbod alternative for lifters",
      "simple workout tracker",
      "notes-style workout tracker",
    ],
    sections: [
      {
        heading: "When Fitbod makes sense",
        body: [
          "Fitbod is useful when you want personalized workout suggestions based on goals, equipment, and training history.",
          "That is a planning-first workflow. It fits people who want the app to shape the session.",
        ],
      },
      {
        heading: "When Bram makes sense",
        body: [
          "Bram is for self-directed lifters. You write the workout you did, and Bram keeps the useful record.",
          "The result is lighter: notes, PRs, history, and progress from the workouts you choose.",
        ],
      },
    ],
    comparison: {
      columns: ["Need", "Fitbod", "Bram"],
      rows: [
        ["Workout planning", "Personalized plans.", "User-led training."],
        ["Logging style", "Planner-centered.", "Notes-centered."],
        ["Best fit", "Someone who wants suggested workouts.", "Someone who wants simple tracking."],
      ],
    },
    faqs: [
      {
        question: "What is a good Fitbod alternative?",
        answer:
          "Bram is a strong Fitbod alternative for lifters who already know their workouts and want notes-style tracking.",
      },
      {
        question: "Is Bram a workout planner?",
        answer:
          "Bram focuses on logging, progress history, PRs, and simple insights from the workouts you write.",
      },
    ],
    related: [
      "simple-gym-log-app",
      "workout-tracker-without-routine-setup",
      "notes-style-workout-tracker",
    ],
  },
  {
    slug: "hevy-alternative",
    title: "Hevy Alternative for Notes-Style Workout Logging",
    description:
      "Bram is a Hevy alternative for lifters who want freeform workout notes, PRs, and history.",
    intro:
      "Hevy is a strong gym tracker with routines, stats, and community. Bram is focused on notes-style logging for lifters who want a calmer workflow.",
    verdict:
      "Bram is the Hevy alternative for people who prefer writing workouts naturally.",
    updated: "June 11, 2026",
    keywords: [
      "Hevy alternative",
      "Hevy app alternative",
      "notes-style workout tracker",
      "freeform workout logger",
    ],
    sections: [
      {
        heading: "Why people look for a Hevy alternative",
        body: [
          "Some lifters want tracking, stats, and history. They also want less app structure during the set.",
          "That is where a notes-style tracker makes sense.",
        ],
      },
      {
        heading: "Why Bram fits",
        body: [
          "Bram lets you write workouts like a normal note. The app turns the note into sets, reps, weights, PRs, and progress.",
        ],
      },
    ],
    comparison: {
      columns: ["Need", "Hevy", "Bram"],
      rows: [
        ["Community", "Strong fit.", "Private notes focus."],
        ["Routine tracking", "Structured workflow.", "Write the workout."],
        ["Notes-style logging", "Limited fit.", "Core product."],
      ],
    },
    faqs: [
      {
        question: "What is the best Hevy alternative for notes-style logging?",
        answer:
          "Bram is built for lifters who want workout notes with PRs, history, and progress tracking.",
      },
      {
        question: "Is Bram simpler than Hevy?",
        answer:
          "Bram has a smaller workflow centered on writing workouts naturally and reviewing progress.",
      },
    ],
    related: ["bram-vs-hevy", "simple-gym-log-app", "best-workout-notes-app"],
  },
  {
    slug: "strong-app-alternative",
    title: "Strong App Alternative for Freeform Workout Logging",
    description:
      "Bram is a Strong app alternative for lifters who want a notes-first gym log.",
    intro:
      "Strong is a classic gym log with a mature structured workflow. Bram is a notes-first gym log for lifters who want fast entry and useful history.",
    verdict:
      "Bram is the Strong app alternative for lifters who keep coming back to notes.",
    updated: "June 11, 2026",
    keywords: [
      "Strong app alternative",
      "Strong alternative",
      "minimal gym log app",
      "workout notes app",
    ],
    sections: [
      {
        heading: "Why people look for a Strong alternative",
        body: [
          "Strong is powerful for classic gym logging. Some lifters want the same progress memory from a more natural writing flow.",
        ],
      },
      {
        heading: "Why Bram fits",
        body: [
          "Bram starts with a workout note. It keeps the log fast and turns your lifting shorthand into progress history.",
        ],
      },
    ],
    comparison: {
      columns: ["Need", "Strong", "Bram"],
      rows: [
        ["Classic gym log", "Strong fit.", "Lean notes flow."],
        ["Freeform logging", "Structured entry.", "Natural writing."],
        ["PR history", "Tracked through app fields.", "Built from notes."],
      ],
    },
    faqs: [
      {
        question: "What is a good Strong app alternative?",
        answer:
          "Bram is a good Strong app alternative for lifters who want a notes-first gym log with PRs and history.",
      },
      {
        question: "Is Bram a full routine builder?",
        answer:
          "Bram focuses on fast workout logging, progress history, and simple insights.",
      },
    ],
    related: ["bram-vs-strong", "simple-gym-log-app", "notes-app-for-lifting"],
  },
  {
    slug: "workout-tracker-without-routine-setup",
    title: "Workout Tracker Without Routine Setup",
    description:
      "Bram is a workout tracker for lifters who want to start with today's workout note.",
    intro:
      "Some lifters want to log today's workout before building a routine, choosing templates, or managing exercise lists.",
    verdict:
      "Bram lets you start with the workout note. Write what you did, then let the app remember the useful details.",
    updated: "June 11, 2026",
    keywords: [
      "workout tracker without routine setup",
      "workout tracker no routine setup",
      "simple workout tracker",
      "freeform workout logger",
    ],
    sections: [
      {
        heading: "The fastest path",
        body: [
          "Open the app and write today's workout. Bench 185 for 5, incline 70s for 8, curls 30s for 12.",
          "That is enough for Bram to build useful exercise history over time.",
        ],
      },
      {
        heading: "Who this fits",
        body: [
          "This fits lifters who already know their training style: push/pull/legs, upper/lower, full body, bodybuilding, powerbuilding, or intuitive sessions.",
          "You can keep your style and still get PRs, recent sets, volume, and progress.",
        ],
      },
    ],
    comparison: {
      columns: ["Workflow", "Setup", "Result"],
      rows: [
        ["Routine builder", "Create a plan first.", "Structured logging."],
        ["Apple Notes", "Start writing.", "Manual history."],
        ["Bram", "Start writing.", "Notes with progress history."],
      ],
    },
    faqs: [
      {
        question: "Can I track workouts with no routine setup?",
        answer:
          "Yes. Bram lets you start from a natural workout note and builds history as you log.",
      },
      {
        question: "Who should use a no-setup workout tracker?",
        answer:
          "Self-directed lifters who already know their workouts and want faster logging are the best fit.",
      },
    ],
    related: [
      "simple-gym-log-app",
      "fitbod-alternative",
      "notes-style-workout-tracker",
    ],
  },
];

export const articleBySlug = new Map(articles.map((article) => [article.slug, article]));
