alter table public.strength_entries
  add column if not exists duration_seconds integer;

alter table public.strength_entries
  drop constraint if exists strength_entries_duration_seconds_positive;

alter table public.strength_entries
  add constraint strength_entries_duration_seconds_positive
  check (duration_seconds is null or duration_seconds > 0);
