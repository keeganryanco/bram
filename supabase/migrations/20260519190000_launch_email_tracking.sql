create table if not exists public.account_email_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  email text not null,
  event_key text not null,
  metadata jsonb not null default '{}'::jsonb,
  sent_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint account_email_events_email_lowercase check (email = lower(email)),
  constraint account_email_events_event_key_not_blank check (length(trim(event_key)) > 0)
);

create unique index if not exists account_email_events_user_event_idx
  on public.account_email_events(user_id, event_key)
  where user_id is not null;

create index if not exists account_email_events_email_event_idx
  on public.account_email_events(email, event_key);

alter table public.account_email_events enable row level security;
revoke all on public.account_email_events from anon, authenticated;

alter table public.waitlist_signups
  add column if not exists launch_email_sent_at timestamptz,
  add column if not exists launch_email_variant text,
  add column if not exists launch_email_error text;

alter table public.waitlist_signups
  drop constraint if exists waitlist_signups_launch_email_variant_check;

alter table public.waitlist_signups
  add constraint waitlist_signups_launch_email_variant_check check (
    launch_email_variant is null
    or launch_email_variant in ('WAITLIST_1MONTH', 'FRIENDS_LIFETIME')
  );

comment on table public.account_email_events is
  'Service-role-only idempotency log for account lifecycle and promo emails.';
comment on column public.waitlist_signups.launch_email_sent_at is
  'Timestamp for the May 2026 launch-day waitlist email, used to prevent duplicate sends.';
