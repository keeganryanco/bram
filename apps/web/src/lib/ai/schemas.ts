import { z } from "zod";

export const WorkoutSetSchema = z.object({
  reps: z.number().int().positive().nullable(),
  load: z.number().positive().nullable(),
  unit: z.enum(["lb", "kg", "bodyweight", "unknown"]).default("unknown"),
  rpe: z.number().min(1).max(10).nullable(),
  rir: z.number().min(0).max(10).nullable(),
  note: z.string().max(160).nullable(),
});

export const ParsedExerciseSchema = z.object({
  name: z.string().min(1).max(120),
  normalizedName: z.string().min(1).max(120).nullable(),
  exerciseKey: z.string().min(1).max(120).nullable(),
  muscleGroupHint: z.string().max(80).nullable(),
  sets: z.array(WorkoutSetSchema).max(12),
  uncertainty: z.string().max(180).nullable(),
});

export const ParsedCardioEntrySchema = z.object({
  activityType: z.string().min(1).max(80),
  durationMinutes: z.number().int().nonnegative().nullable(),
  distanceValue: z.number().nonnegative().nullable(),
  distanceUnit: z.enum(["mi", "km", "m", "unknown"]).default("unknown"),
  paceText: z.string().max(80).nullable(),
  sessionIndex: z.number().int().nonnegative().nullable(),
  sourceLineIndex: z.number().int().nonnegative().nullable(),
});

export const ParsedWorkoutSessionSchema = z.object({
  sessionIndex: z.number().int().nonnegative(),
  title: z.string().min(1).max(100),
  kind: z.enum(["strength", "cardio", "mixed", "mobility", "unknown"]),
  startLineIndex: z.number().int().nonnegative(),
  endLineIndex: z.number().int().nonnegative().nullable(),
});

export const ParsedWorkoutLineSegmentSchema = z.object({
  type: z.enum(["text", "exercise_anchor", "badge", "metric"]),
  text: z.string().min(1).max(160),
  exerciseKey: z.string().min(1).max(120).nullable(),
});

export const ParsedWorkoutLineSchema = z.object({
  lineIndex: z.number().int().nonnegative(),
  kind: z.enum(["strength", "cardio", "health", "note", "suggestion", "reading"]),
  segments: z.array(ParsedWorkoutLineSegmentSchema).max(8),
});

export const ParsedWorkoutSchema = z.object({
  workoutDate: z.string().max(40).nullable(),
  title: z.string().max(80).nullable(),
  summary: z.string().max(180),
  lines: z.array(ParsedWorkoutLineSchema).max(80).default([]),
  sessions: z.array(ParsedWorkoutSessionSchema).max(8).default([]),
  exercises: z.array(ParsedExerciseSchema).max(24),
  cardioEntries: z.array(ParsedCardioEntrySchema).max(12).default([]),
  sessionNotes: z.array(z.string().max(160)).max(8),
  unresolvedText: z.array(z.string().max(160)).max(8),
});

export const InlineSuggestionSchema = z.object({
  type: z.enum(["reminder", "progression", "balance", "recovery"]),
  category: z.enum(["reminder", "progression", "balance", "recovery"]).optional(),
  text: z
    .string()
    .min(1)
    .max(180)
    .refine((value) => value.split(/[.!?]/).filter(Boolean).length <= 1, {
      message: "Suggestion must be one sentence.",
    }),
  evidence: z.array(z.string().max(120)).max(3),
  affectedExerciseKey: z.string().min(1).max(120).nullable().optional(),
  affectedCardioKey: z.string().min(1).max(80).nullable().optional(),
});

export const ExerciseSuggestionSchema = z.object({
  exerciseKey: z.string().min(1).max(120),
  title: z.string().min(1).max(40).default("Next time"),
  text: z.string().min(1).max(180),
  target: z.string().max(80).nullable(),
  evidence: z.array(z.string().max(120)).max(4),
  reasonTags: z.array(z.string().max(80)).max(4).default([]),
});

export const SuggestionDraftSchema = z.object({
  text: z
    .string()
    .min(1)
    .max(180)
    .refine((value) => value.startsWith("Bram:"), {
      message: "Draft note suggestions must start with Bram:.",
    }),
  evidence: z.array(z.string().max(120)).max(4),
});

export const WorkoutSuggestionResponseSchema = z.object({
  dailySuggestion: InlineSuggestionSchema.nullable(),
  exerciseSuggestions: z.array(ExerciseSuggestionSchema).max(12),
  draft: SuggestionDraftSchema.nullable(),
});

export const CurrentWorkoutSuggestionContextSchema = z.object({
  sets: z.number().int().nonnegative(),
  prs: z.number().int().nonnegative(),
  cardioMinutes: z.number().int().nonnegative(),
  energyBucket: z.enum(["low", "moderate", "high", "unknown"]),
  sessionKind: z.enum(["strength", "cardio", "mixed", "unknown"]).default("unknown"),
  activeExerciseKey: z.string().min(1).max(120).nullable().optional(),
  activeExerciseSetCount: z.number().int().nonnegative().default(0),
  activeExerciseEffort: z.enum(["easy", "moderate", "hard", "max", "unknown"]).default("unknown"),
});

export const MuscleVolumeSuggestionContextSchema = z.object({
  muscleGroup: z.string().min(1).max(80),
  sets: z.number().int().nonnegative(),
});

export const ExerciseHistorySuggestionContextSchema = z.object({
  exerciseKey: z.string().min(1).max(120),
  displayName: z.string().min(1).max(120).optional(),
  bestSet: z.string().max(80).nullable().optional(),
  estimatedOneRepMax: z.number().int().nonnegative().nullable().optional(),
  recentSessionCount: z.number().int().nonnegative(),
  recommendationEvidence: z.array(z.string().max(120)).max(6).default([]),
  target: z.string().max(80).nullable().optional(),
});

export const CardioHistorySuggestionContextSchema = z.object({
  activityType: z.string().min(1).max(80),
  recentSessionCount: z.number().int().nonnegative(),
  averageDurationMinutes: z.number().int().nonnegative().nullable().optional(),
  bestDistance: z.string().max(80).nullable().optional(),
  estimatedCalories: z.string().max(40).optional(),
  recommendation: z.string().max(180).optional(),
});

export const DailyMetricsSuggestionContextSchema = z.object({
  duration: z.string().max(40),
  heartRate: z.string().max(40),
});

export const GoalsSuggestionContextSchema = z.object({
  primaryGoal: z.string().min(1).max(80),
  weeklyTrainingDays: z.number().int().min(0).max(14),
  sessionLengthMinutes: z.number().int().min(0).max(300),
  trainingStyles: z.array(z.string().max(80)).max(12).default([]),
  equipment: z.array(z.string().max(80)).max(16).default([]),
});

export const NoteHintsSuggestionContextSchema = z.object({
  readiness: z.enum(["low", "high", "unknown"]).default("unknown"),
  equipment: z.string().max(80).default("unknown"),
  constraint: z.enum(["time", "none"]).default("none"),
  cardioIntent: z.enum(["cardio_logged", "none"]).default("none"),
  sessionKind: z.enum(["strength", "cardio", "mixed", "unknown"]).default("unknown"),
});

export const WorkoutPatternSuggestionContextSchema = z.object({
  label: z.string().min(1).max(80),
  confidence: z.enum(["none", "low", "high"]),
  workoutCount: z.number().int().nonnegative(),
  matchedMuscleGroup: z.string().max(80).nullable().optional(),
  matchedExerciseKeys: z.array(z.string().max(120)).max(8).default([]),
  evidence: z.array(z.string().max(120)).max(6).default([]),
});

export const WorkoutSuggestionInputSchema = z.object({
  installId: z.string().min(8).max(160),
  userId: z.string().uuid().optional(),
  currentWorkout: CurrentWorkoutSuggestionContextSchema,
  exerciseHistorySummaries: z.array(ExerciseHistorySuggestionContextSchema).max(24).default([]),
  cardioHistorySummaries: z.array(CardioHistorySuggestionContextSchema).max(12).default([]),
  dailyMetrics: DailyMetricsSuggestionContextSchema,
  muscleVolume: z.array(MuscleVolumeSuggestionContextSchema).max(16).default([]),
  goals: GoalsSuggestionContextSchema,
  noteHints: NoteHintsSuggestionContextSchema,
  workoutPattern: WorkoutPatternSuggestionContextSchema.nullable().optional(),
  feedbackSummary: z.record(z.string(), z.number().int()).default({}),
});

export const SuggestionFeedbackInputSchema = z.object({
  installId: z.string().min(8).max(160),
  suggestionId: z.string().uuid(),
  suggestionType: z.enum(["daily", "exercise", "draft"]),
  action: z.enum([
    "accepted",
    "dismissed",
    "thumbsUp",
    "thumbsDown",
    "modified",
    "deleted",
  ]),
  source: z.enum(["local", "ai"]),
  coarseContext: z.record(z.string(), z.string().max(80)).default({}),
});

export const WeeklyReviewSchema = z.object({
  summary: z.string().min(1).max(320),
  chartMetric: z.object({
    label: z.string().min(1).max(80),
    value: z.string().min(1).max(80),
    rationale: z.string().min(1).max(160),
  }),
  suggestedAdjustment: z.string().min(1).max(180),
});

export const OnboardingTrainingProfileSchema = z.object({
  experienceLevel: z.enum(["new", "novice", "intermediate", "advanced"]),
  preferredUnits: z.enum(["lb", "kg", "unknown"]),
  trainingStyle: z.string().max(120),
  likelyGoals: z.array(z.string().max(80)).max(4),
  constraints: z.array(z.string().max(120)).max(6),
});

export type ParsedWorkout = z.infer<typeof ParsedWorkoutSchema>;
export type ParsedCardioEntry = z.infer<typeof ParsedCardioEntrySchema>;
export type InlineSuggestion = z.infer<typeof InlineSuggestionSchema>;
export type ExerciseSuggestion = z.infer<typeof ExerciseSuggestionSchema>;
export type WorkoutSuggestionResponse = z.infer<
  typeof WorkoutSuggestionResponseSchema
>;
export type WorkoutSuggestionInput = z.infer<typeof WorkoutSuggestionInputSchema>;
export type CurrentWorkoutSuggestionContext = z.infer<typeof CurrentWorkoutSuggestionContextSchema>;
export type ExerciseHistorySuggestionContext = z.infer<typeof ExerciseHistorySuggestionContextSchema>;
export type CardioHistorySuggestionContext = z.infer<typeof CardioHistorySuggestionContextSchema>;
export type SuggestionFeedbackInput = z.infer<
  typeof SuggestionFeedbackInputSchema
>;
export type WeeklyReview = z.infer<typeof WeeklyReviewSchema>;
export type OnboardingTrainingProfile = z.infer<
  typeof OnboardingTrainingProfileSchema
>;
