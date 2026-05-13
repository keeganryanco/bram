do $$
begin
  create type public.bram_height_unit as enum (
    'in',
    'cm'
  );
exception
  when duplicate_object then null;
end
$$;

do $$
begin
  create type public.bram_bodyweight_source as enum (
    'manual',
    'note',
    'appleHealth'
  );
exception
  when duplicate_object then null;
end
$$;

alter table public.profiles
  add column if not exists height_value numeric(6, 2),
  add column if not exists height_unit public.bram_height_unit,
  add column if not exists target_bodyweight_value numeric(6, 2),
  add column if not exists current_bodyweight_logged_at timestamptz,
  add column if not exists current_bodyweight_source public.bram_bodyweight_source,
  add column if not exists estimated_daily_calories integer;

alter table public.profiles
  drop constraint if exists profiles_height_positive,
  add constraint profiles_height_positive check (
    height_value is null or height_value > 0
  );

alter table public.profiles
  drop constraint if exists profiles_target_bodyweight_positive,
  add constraint profiles_target_bodyweight_positive check (
    target_bodyweight_value is null or target_bodyweight_value > 0
  );

alter table public.profiles
  drop constraint if exists profiles_estimated_daily_calories_positive,
  add constraint profiles_estimated_daily_calories_positive check (
    estimated_daily_calories is null or estimated_daily_calories > 0
  );

alter table public.profiles
  drop constraint if exists profiles_current_bodyweight_source_requires_value,
  add constraint profiles_current_bodyweight_source_requires_value check (
    current_bodyweight_source is null or bodyweight_value is not null
  );

alter table public.training_profiles
  add column if not exists session_length_minutes integer,
  add column if not exists training_styles text[] not null default '{}',
  add column if not exists onboarding_completed_at timestamptz;

alter table public.training_profiles
  drop constraint if exists training_profiles_session_length_check,
  add constraint training_profiles_session_length_check check (
    session_length_minutes is null
    or session_length_minutes between 10 and 240
  );

alter table public.training_profiles
  drop constraint if exists training_profiles_training_styles_not_null,
  add constraint training_profiles_training_styles_not_null check (
    training_styles is not null
  );

grant update (
  display_name,
  birthdate,
  bodyweight_value,
  bodyweight_unit,
  sex,
  sex_self_describe,
  preferred_units,
  onboarding_completed_at,
  height_value,
  height_unit,
  target_bodyweight_value,
  current_bodyweight_logged_at,
  current_bodyweight_source,
  estimated_daily_calories
) on public.profiles to authenticated;

comment on column public.profiles.height_value is
  'Optional onboarding/settings height value. Unit is stored in height_unit.';
comment on column public.profiles.target_bodyweight_value is
  'Optional target bodyweight for progress framing. Same unit family as bodyweight_unit/preferred_units.';
comment on column public.profiles.current_bodyweight_source is
  'Source for the current bodyweight value: manual settings, workout note extraction, or Apple Health.';
comment on column public.profiles.estimated_daily_calories is
  'Optional private onboarding estimate. Never send raw values to analytics.';
comment on table public.training_profiles is
  'User-owned training intent and equipment context captured during onboarding and editable in Settings.';
