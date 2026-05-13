do $$
begin
  create type public.bram_workout_sync_state as enum (
    'LOCAL_ONLY',
    'PENDING_UPLOAD',
    'SYNCED',
    'FAILED',
    'DELETED'
  );
exception
  when duplicate_object then null;
end
$$;

do $$
begin
  create type public.bram_workout_line_kind as enum (
    'strength',
    'cardio',
    'health',
    'note',
    'suggestion',
    'reading'
  );
exception
  when duplicate_object then null;
end
$$;

create table if not exists public.training_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  primary_goal text,
  experience_level text,
  preferred_split text,
  available_equipment text[],
  weekly_training_days integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint training_profiles_weekly_days_check check (
    weekly_training_days is null or weekly_training_days between 0 and 14
  )
);

create table if not exists public.exercise_catalog (
  exercise_key text primary key,
  canonical_name text not null,
  muscle_group text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_exercise_aliases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  alias text not null,
  exercise_key text not null references public.exercise_catalog(exercise_key) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, alias)
);

create table if not exists public.workout_notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  client_local_id uuid,
  workout_date date not null,
  timezone_identifier text not null,
  body text not null default '',
  sync_state public.bram_workout_sync_state not null default 'SYNCED',
  client_updated_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, workout_date)
);

create table if not exists public.workout_note_lines (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  note_id uuid not null references public.workout_notes(id) on delete cascade,
  line_index integer not null,
  raw_text text not null,
  kind public.bram_workout_line_kind not null,
  chip_text text,
  detail_title text,
  detail_text text,
  confidence numeric(4, 3),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (note_id, line_index),
  constraint workout_note_lines_confidence_check check (
    confidence is null or (confidence >= 0 and confidence <= 1)
  )
);

create table if not exists public.strength_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  note_id uuid not null references public.workout_notes(id) on delete cascade,
  line_id uuid references public.workout_note_lines(id) on delete set null,
  exercise_name text not null,
  exercise_key text references public.exercise_catalog(exercise_key) on delete set null,
  sets integer not null,
  reps integer,
  load_value numeric(8, 2),
  load_unit text not null default 'lb',
  effort text,
  muscle_group text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint strength_entries_sets_positive check (sets > 0),
  constraint strength_entries_reps_positive check (reps is null or reps > 0),
  constraint strength_entries_load_positive check (load_value is null or load_value >= 0)
);

create table if not exists public.cardio_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  note_id uuid not null references public.workout_notes(id) on delete cascade,
  line_id uuid references public.workout_note_lines(id) on delete set null,
  activity_type text not null,
  duration_minutes integer,
  distance_value numeric(8, 2),
  distance_unit text,
  average_heart_rate integer,
  active_energy_calories integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint cardio_duration_positive check (duration_minutes is null or duration_minutes >= 0),
  constraint cardio_distance_positive check (distance_value is null or distance_value >= 0),
  constraint cardio_average_hr_check check (average_heart_rate is null or average_heart_rate between 20 and 240),
  constraint cardio_energy_positive check (active_energy_calories is null or active_energy_calories >= 0)
);

create table if not exists public.daily_workout_metrics (
  user_id uuid not null references auth.users(id) on delete cascade,
  workout_date date not null,
  note_id uuid references public.workout_notes(id) on delete cascade,
  total_sets integer not null default 0,
  hard_sets integer not null default 0,
  estimated_volume integer not null default 0,
  pr_count integer not null default 0,
  cardio_minutes integer not null default 0,
  active_energy_calories integer,
  average_heart_rate integer,
  workout_duration_minutes integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, workout_date)
);

create table if not exists public.workout_prs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  note_id uuid references public.workout_notes(id) on delete cascade,
  exercise_name text not null,
  exercise_key text references public.exercise_catalog(exercise_key) on delete set null,
  pr_kind text not null,
  value numeric(10, 2) not null,
  unit text not null,
  achieved_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table if not exists public.exercise_history_summaries (
  user_id uuid not null references auth.users(id) on delete cascade,
  exercise_key text not null references public.exercise_catalog(exercise_key) on delete cascade,
  display_name text not null,
  estimated_one_rep_max numeric(8, 2),
  best_set_text text,
  recent_dates date[] not null default '{}',
  recommendation text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, exercise_key)
);

create table if not exists public.health_daily_metrics (
  user_id uuid not null references auth.users(id) on delete cascade,
  metric_date date not null,
  active_energy_calories integer,
  average_heart_rate integer,
  max_heart_rate integer,
  bodyweight_value numeric(6, 2),
  bodyweight_unit text,
  sleep_minutes integer,
  source text not null default 'APPLE_HEALTH',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, metric_date),
  constraint health_average_hr_check check (average_heart_rate is null or average_heart_rate between 20 and 240),
  constraint health_max_hr_check check (max_heart_rate is null or max_heart_rate between 20 and 240)
);

create table if not exists public.health_workout_matches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  note_id uuid not null references public.workout_notes(id) on delete cascade,
  health_workout_id text not null,
  match_quality text not null,
  matched_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, health_workout_id),
  constraint health_workout_matches_quality_check check (
    match_quality in ('strong', 'possible', 'manual')
  )
);

create table if not exists public.suggestions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  note_id uuid references public.workout_notes(id) on delete cascade,
  suggestion_kind text not null,
  body text not null,
  accepted_at timestamptz,
  dismissed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.ai_usage_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  pseudonymous_user_id text not null,
  task text not null,
  model text not null,
  input_tokens integer,
  output_tokens integer,
  estimated_cents numeric(10, 4),
  success boolean not null,
  error_code text,
  created_at timestamptz not null default now(),
  constraint ai_usage_no_raw_note_check check (
    task <> ''
    and model <> ''
  )
);

create index if not exists workout_notes_user_date_idx on public.workout_notes(user_id, workout_date desc);
create index if not exists workout_notes_sync_state_idx on public.workout_notes(user_id, sync_state);
create index if not exists workout_note_lines_note_idx on public.workout_note_lines(note_id, line_index);
create index if not exists user_exercise_aliases_user_key_idx on public.user_exercise_aliases(user_id, exercise_key);
create index if not exists strength_entries_user_exercise_idx on public.strength_entries(user_id, exercise_key, created_at desc);
create index if not exists cardio_entries_user_activity_idx on public.cardio_entries(user_id, activity_type, created_at desc);
create index if not exists workout_prs_user_exercise_idx on public.workout_prs(user_id, exercise_key, achieved_at desc);
create index if not exists exercise_history_summaries_user_key_idx on public.exercise_history_summaries(user_id, exercise_key);
create index if not exists health_workout_matches_user_note_idx on public.health_workout_matches(user_id, note_id);
create index if not exists suggestions_user_created_idx on public.suggestions(user_id, created_at desc);
create index if not exists ai_usage_events_user_created_idx on public.ai_usage_events(user_id, created_at desc);

alter table public.exercise_catalog enable row level security;
alter table public.training_profiles enable row level security;
alter table public.user_exercise_aliases enable row level security;
alter table public.workout_notes enable row level security;
alter table public.workout_note_lines enable row level security;
alter table public.strength_entries enable row level security;
alter table public.cardio_entries enable row level security;
alter table public.daily_workout_metrics enable row level security;
alter table public.workout_prs enable row level security;
alter table public.exercise_history_summaries enable row level security;
alter table public.health_daily_metrics enable row level security;
alter table public.health_workout_matches enable row level security;
alter table public.suggestions enable row level security;
alter table public.ai_usage_events enable row level security;

drop policy if exists "Authenticated users can read exercise catalog" on public.exercise_catalog;
create policy "Authenticated users can read exercise catalog"
on public.exercise_catalog
for select
to authenticated
using (true);

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'training_profiles',
    'user_exercise_aliases',
    'workout_notes',
    'workout_note_lines',
    'strength_entries',
    'cardio_entries',
    'daily_workout_metrics',
    'workout_prs',
    'exercise_history_summaries',
    'health_daily_metrics',
    'health_workout_matches',
    'suggestions',
    'ai_usage_events'
  ]
  loop
    execute format('drop policy if exists "Users can manage own %1$s" on public.%1$I', table_name);
    execute format(
      'create policy "Users can manage own %1$s" on public.%1$I for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)',
      table_name
    );
  end loop;
end
$$;

revoke all on public.exercise_catalog from anon, authenticated;
revoke all on public.training_profiles from anon, authenticated;
revoke all on public.user_exercise_aliases from anon, authenticated;
revoke all on public.workout_notes from anon, authenticated;
revoke all on public.workout_note_lines from anon, authenticated;
revoke all on public.strength_entries from anon, authenticated;
revoke all on public.cardio_entries from anon, authenticated;
revoke all on public.daily_workout_metrics from anon, authenticated;
revoke all on public.workout_prs from anon, authenticated;
revoke all on public.exercise_history_summaries from anon, authenticated;
revoke all on public.health_daily_metrics from anon, authenticated;
revoke all on public.health_workout_matches from anon, authenticated;
revoke all on public.suggestions from anon, authenticated;
revoke all on public.ai_usage_events from anon, authenticated;

grant select on public.exercise_catalog to authenticated;
grant select, insert, update, delete on public.training_profiles to authenticated;
grant select, insert, update, delete on public.user_exercise_aliases to authenticated;
grant select, insert, update, delete on public.workout_notes to authenticated;
grant select, insert, update, delete on public.workout_note_lines to authenticated;
grant select, insert, update, delete on public.strength_entries to authenticated;
grant select, insert, update, delete on public.cardio_entries to authenticated;
grant select, insert, update, delete on public.daily_workout_metrics to authenticated;
grant select, insert, update, delete on public.workout_prs to authenticated;
grant select, insert, update, delete on public.exercise_history_summaries to authenticated;
grant select, insert, update, delete on public.health_daily_metrics to authenticated;
grant select, insert, update, delete on public.health_workout_matches to authenticated;
grant select, insert, update, delete on public.suggestions to authenticated;
grant select on public.ai_usage_events to authenticated;

insert into public.exercise_catalog (exercise_key, canonical_name, muscle_group)
values
  ('bench_press', 'Bench Press', 'Chest'),
  ('single_arm_preacher_curl', 'Single Arm Preacher Curl', 'Arms'),
  ('incline_hammer_curl', 'Incline Hammer Curl', 'Arms'),
  ('cable_pullover', 'Cable Pullover', 'Back'),
  ('bike', 'Bike', null)
on conflict (exercise_key) do nothing;

drop trigger if exists set_training_profiles_updated_at on public.training_profiles;
create trigger set_training_profiles_updated_at
before update on public.training_profiles
for each row execute function public.set_updated_at();

drop trigger if exists set_exercise_catalog_updated_at on public.exercise_catalog;
create trigger set_exercise_catalog_updated_at
before update on public.exercise_catalog
for each row execute function public.set_updated_at();

drop trigger if exists set_user_exercise_aliases_updated_at on public.user_exercise_aliases;
create trigger set_user_exercise_aliases_updated_at
before update on public.user_exercise_aliases
for each row execute function public.set_updated_at();

drop trigger if exists set_workout_notes_updated_at on public.workout_notes;
create trigger set_workout_notes_updated_at
before update on public.workout_notes
for each row execute function public.set_updated_at();

drop trigger if exists set_workout_note_lines_updated_at on public.workout_note_lines;
create trigger set_workout_note_lines_updated_at
before update on public.workout_note_lines
for each row execute function public.set_updated_at();

drop trigger if exists set_strength_entries_updated_at on public.strength_entries;
create trigger set_strength_entries_updated_at
before update on public.strength_entries
for each row execute function public.set_updated_at();

drop trigger if exists set_cardio_entries_updated_at on public.cardio_entries;
create trigger set_cardio_entries_updated_at
before update on public.cardio_entries
for each row execute function public.set_updated_at();

drop trigger if exists set_daily_workout_metrics_updated_at on public.daily_workout_metrics;
create trigger set_daily_workout_metrics_updated_at
before update on public.daily_workout_metrics
for each row execute function public.set_updated_at();

drop trigger if exists set_health_daily_metrics_updated_at on public.health_daily_metrics;
create trigger set_health_daily_metrics_updated_at
before update on public.health_daily_metrics
for each row execute function public.set_updated_at();

drop trigger if exists set_exercise_history_summaries_updated_at on public.exercise_history_summaries;
create trigger set_exercise_history_summaries_updated_at
before update on public.exercise_history_summaries
for each row execute function public.set_updated_at();

drop trigger if exists set_health_workout_matches_updated_at on public.health_workout_matches;
create trigger set_health_workout_matches_updated_at
before update on public.health_workout_matches
for each row execute function public.set_updated_at();

comment on table public.exercise_catalog is
  'Canonical exercise keys and names. Authenticated clients can read; writes should be server/admin managed.';
comment on table public.user_exercise_aliases is
  'User-owned aliases that map messy note exercise names to canonical exercise keys.';
comment on table public.workout_notes is
  'User-owned raw workout notes by day. Access is limited by RLS to the note owner.';
comment on table public.health_workout_matches is
  'User-owned Apple Health workout associations. Match quality is user-facing language, not a confidence meter.';
comment on table public.ai_usage_events is
  'AI usage metadata only. Do not store raw workout note text, exercise note bodies, or health notes here.';
