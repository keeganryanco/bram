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
  muscleGroupHint: z.string().max(80).nullable(),
  sets: z.array(WorkoutSetSchema).max(12),
  uncertainty: z.string().max(180).nullable(),
});

export const ParsedWorkoutSchema = z.object({
  workoutDate: z.string().max(40).nullable(),
  title: z.string().max(80).nullable(),
  summary: z.string().max(180),
  exercises: z.array(ParsedExerciseSchema).max(24),
  sessionNotes: z.array(z.string().max(160)).max(8),
  unresolvedText: z.array(z.string().max(160)).max(8),
});

export const InlineSuggestionSchema = z.object({
  type: z.enum(["reminder", "progression", "balance", "recovery"]),
  text: z
    .string()
    .min(1)
    .max(180)
    .refine((value) => value.split(/[.!?]/).filter(Boolean).length <= 1, {
      message: "Suggestion must be one sentence.",
    }),
  evidence: z.array(z.string().max(120)).max(3),
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
export type InlineSuggestion = z.infer<typeof InlineSuggestionSchema>;
export type WeeklyReview = z.infer<typeof WeeklyReviewSchema>;
export type OnboardingTrainingProfile = z.infer<
  typeof OnboardingTrainingProfileSchema
>;
