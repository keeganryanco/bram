create extension if not exists pgcrypto;

create table if not exists public.waitlist_signups (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  full_name text,
  source text not null default 'website',
  user_agent text,
  referrer text,
  founder_discount_eligible boolean not null default true,
  welcome_email_sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint waitlist_signups_email_unique unique (email),
  constraint waitlist_signups_email_lowercase check (email = lower(email)),
  constraint waitlist_signups_email_shape check (position('@' in email) > 1)
);

alter table public.waitlist_signups
  add column if not exists full_name text,
  add column if not exists founder_discount_eligible boolean not null default true,
  add column if not exists welcome_email_sent_at timestamptz;

alter table public.waitlist_signups enable row level security;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_waitlist_signups_updated_at on public.waitlist_signups;
create trigger set_waitlist_signups_updated_at
before update on public.waitlist_signups
for each row
execute function public.set_updated_at();

-- No public insert/select/update/delete policies are defined intentionally.
-- The website writes through the Next.js server route with the Supabase service role.
