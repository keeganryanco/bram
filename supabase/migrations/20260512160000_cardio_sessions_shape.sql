alter table public.cardio_entries
add column if not exists session_index integer,
add column if not exists session_name text,
add column if not exists source_line_index integer,
add column if not exists pace_text text;

create index if not exists cardio_entries_user_note_session_idx
on public.cardio_entries(user_id, note_id, session_index);
