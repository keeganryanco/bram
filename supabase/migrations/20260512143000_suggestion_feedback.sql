-- Suggestion feedback is categorical only. Do not store raw workout notes,
-- raw exercise lines, health notes, bodyweight, or injury text here.

create table if not exists public.suggestion_feedback (
  id uuid primary key default gen_random_uuid(),
  install_id text not null,
  user_id uuid references auth.users(id) on delete cascade,
  suggestion_id uuid not null,
  suggestion_type text not null check (suggestion_type in ('daily', 'exercise', 'draft')),
  action text not null check (action in ('accepted', 'dismissed', 'thumbsUp', 'thumbsDown', 'modified', 'deleted')),
  source text not null check (source in ('local', 'ai')),
  coarse_context jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint suggestion_feedback_coarse_context_object check (jsonb_typeof(coarse_context) = 'object')
);

create index if not exists suggestion_feedback_install_created_idx
on public.suggestion_feedback(install_id, created_at desc);

create index if not exists suggestion_feedback_user_created_idx
on public.suggestion_feedback(user_id, created_at desc)
where user_id is not null;

alter table public.suggestion_feedback enable row level security;

drop policy if exists suggestion_feedback_select_own on public.suggestion_feedback;
create policy suggestion_feedback_select_own
on public.suggestion_feedback
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists suggestion_feedback_insert_own on public.suggestion_feedback;
create policy suggestion_feedback_insert_own
on public.suggestion_feedback
for insert
to authenticated
with check ((select auth.uid()) = user_id);

revoke all on public.suggestion_feedback from anon, authenticated;
grant select, insert on public.suggestion_feedback to authenticated;
