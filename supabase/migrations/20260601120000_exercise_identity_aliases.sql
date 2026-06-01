insert into public.exercise_catalog (exercise_key, canonical_name, muscle_group)
values
  ('barbell_bench_press', 'Barbell Bench Press', 'Chest'),
  ('chest_press', 'Chest Press', 'Chest'),
  ('dumbbell_chest_press', 'Dumbbell Chest Press', 'Chest'),
  ('incline_chest_press', 'Incline Chest Press', 'Chest'),
  ('incline_barbell_press', 'Incline Barbell Press', 'Chest'),
  ('incline_dumbbell_chest_press', 'Incline Dumbbell Chest Press', 'Chest')
on conflict (exercise_key) do update set
  canonical_name = excluded.canonical_name,
  muscle_group = excluded.muscle_group,
  updated_at = now();

update public.strength_entries
set exercise_key = case exercise_key
  when 'flat_barbell_chest_press' then 'barbell_bench_press'
  when 'chest_press_barbell' then 'barbell_bench_press'
  when 'barbell_chest_press' then 'barbell_bench_press'
  when 'barbell_chest' then 'barbell_bench_press'
  when 'barbell_bench' then 'barbell_bench_press'
  when 'flat_barbell_bench' then 'barbell_bench_press'
  when 'flat_barbell_bench_press' then 'barbell_bench_press'
  when 'incline_barbell_chest_press' then 'incline_barbell_press'
  when 'incline_chest_press_barbell' then 'incline_barbell_press'
  when 'incline_db_chest_press' then 'incline_dumbbell_chest_press'
  else exercise_key
end
where exercise_key in (
  'flat_barbell_chest_press',
  'chest_press_barbell',
  'barbell_chest_press',
  'barbell_chest',
  'barbell_bench',
  'flat_barbell_bench',
  'flat_barbell_bench_press',
  'incline_barbell_chest_press',
  'incline_chest_press_barbell',
  'incline_db_chest_press'
);

update public.workout_prs
set exercise_key = case exercise_key
  when 'flat_barbell_chest_press' then 'barbell_bench_press'
  when 'chest_press_barbell' then 'barbell_bench_press'
  when 'barbell_chest_press' then 'barbell_bench_press'
  when 'barbell_chest' then 'barbell_bench_press'
  when 'barbell_bench' then 'barbell_bench_press'
  when 'flat_barbell_bench' then 'barbell_bench_press'
  when 'flat_barbell_bench_press' then 'barbell_bench_press'
  when 'incline_barbell_chest_press' then 'incline_barbell_press'
  when 'incline_chest_press_barbell' then 'incline_barbell_press'
  when 'incline_db_chest_press' then 'incline_dumbbell_chest_press'
  else exercise_key
end
where exercise_key in (
  'flat_barbell_chest_press',
  'chest_press_barbell',
  'barbell_chest_press',
  'barbell_chest',
  'barbell_bench',
  'flat_barbell_bench',
  'flat_barbell_bench_press',
  'incline_barbell_chest_press',
  'incline_chest_press_barbell',
  'incline_db_chest_press'
);

with alias_map(legacy_key, canonical_key) as (
  values
    ('flat_barbell_chest_press', 'barbell_bench_press'),
    ('chest_press_barbell', 'barbell_bench_press'),
    ('barbell_chest_press', 'barbell_bench_press'),
    ('barbell_chest', 'barbell_bench_press'),
    ('barbell_bench', 'barbell_bench_press'),
    ('flat_barbell_bench', 'barbell_bench_press'),
    ('flat_barbell_bench_press', 'barbell_bench_press'),
    ('incline_barbell_chest_press', 'incline_barbell_press'),
    ('incline_chest_press_barbell', 'incline_barbell_press'),
    ('incline_db_chest_press', 'incline_dumbbell_chest_press')
),
legacy_summaries as (
  select s.*, a.canonical_key
  from public.exercise_history_summaries s
  join alias_map a on a.legacy_key = s.exercise_key
)
insert into public.exercise_history_summaries (
  user_id,
  exercise_key,
  display_name,
  estimated_one_rep_max,
  best_set_text,
  recent_dates,
  recommendation,
  created_at,
  updated_at
)
select
  user_id,
  canonical_key,
  display_name,
  estimated_one_rep_max,
  best_set_text,
  recent_dates,
  recommendation,
  created_at,
  now()
from legacy_summaries
on conflict (user_id, exercise_key) do update set
  estimated_one_rep_max = greatest(
    coalesce(public.exercise_history_summaries.estimated_one_rep_max, 0),
    coalesce(excluded.estimated_one_rep_max, 0)
  ),
  recent_dates = (
    select array(
      select distinct unnest(public.exercise_history_summaries.recent_dates || excluded.recent_dates)
      order by 1 desc
      limit 12
    )
  ),
  updated_at = now();

with alias_map(legacy_key, canonical_key) as (
  values
    ('flat_barbell_chest_press', 'barbell_bench_press'),
    ('chest_press_barbell', 'barbell_bench_press'),
    ('barbell_chest_press', 'barbell_bench_press'),
    ('barbell_chest', 'barbell_bench_press'),
    ('barbell_bench', 'barbell_bench_press'),
    ('flat_barbell_bench', 'barbell_bench_press'),
    ('flat_barbell_bench_press', 'barbell_bench_press'),
    ('incline_barbell_chest_press', 'incline_barbell_press'),
    ('incline_chest_press_barbell', 'incline_barbell_press'),
    ('incline_db_chest_press', 'incline_dumbbell_chest_press')
)
delete from public.exercise_history_summaries s
using alias_map a
where s.exercise_key = a.legacy_key;
