create schema if not exists bram_private;

do $$
begin
  create type public.bram_account_tier as enum (
    'FREE',
    'PREMIUM',
    'FREE_PREMIUM'
  );
exception
  when duplicate_object then null;
end
$$;

do $$
begin
  create type public.bram_entitlement_source as enum (
    'NONE',
    'APP_STORE',
    'REVENUECAT',
    'FOUNDER_OFFER',
    'MANUAL',
    'DEV'
  );
exception
  when duplicate_object then null;
end
$$;

do $$
begin
  create type public.bram_subscription_status as enum (
    'NONE',
    'TRIAL',
    'ACTIVE',
    'GRACE_PERIOD',
    'EXPIRED',
    'CANCELED',
    'BILLING_RETRY',
    'FREE_PREMIUM'
  );
exception
  when duplicate_object then null;
end
$$;

do $$
begin
  create type public.bram_bodyweight_unit as enum (
    'lb',
    'kg'
  );
exception
  when duplicate_object then null;
end
$$;

do $$
begin
  create type public.bram_sex as enum (
    'female',
    'male',
    'intersex',
    'self_describe',
    'prefer_not_to_say'
  );
exception
  when duplicate_object then null;
end
$$;

do $$
begin
  create type public.bram_preferred_units as enum (
    'lb',
    'kg'
  );
exception
  when duplicate_object then null;
end
$$;

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  display_name text,
  birthdate date,
  bodyweight_value numeric(6, 2),
  bodyweight_unit public.bram_bodyweight_unit,
  sex public.bram_sex,
  sex_self_describe text,
  preferred_units public.bram_preferred_units not null default 'lb',
  onboarding_completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_email_lowercase check (email = lower(email)),
  constraint profiles_bodyweight_positive check (
    bodyweight_value is null or bodyweight_value > 0
  ),
  constraint profiles_self_describe_required check (
    sex is distinct from 'self_describe'
    or nullif(trim(coalesce(sex_self_describe, '')), '') is not null
  )
);

create table if not exists public.account_entitlements (
  user_id uuid primary key references auth.users(id) on delete cascade,
  account_tier public.bram_account_tier not null default 'FREE',
  subscription_status public.bram_subscription_status not null default 'NONE',
  entitlement_source public.bram_entitlement_source not null default 'NONE',
  is_developer boolean not null default false,
  founder_offer_eligible boolean not null default false,
  founder_offer_redeemed_at timestamptz,
  founder_offer_waitlist_signup_id uuid references public.waitlist_signups(id) on delete set null,
  premium_expires_at timestamptz,
  revenuecat_app_user_id text,
  app_store_original_transaction_id text,
  manual_reason text,
  internal_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint account_entitlements_free_premium_source check (
    account_tier <> 'FREE_PREMIUM'
    or entitlement_source in ('FOUNDER_OFFER', 'MANUAL', 'DEV')
  ),
  constraint account_entitlements_dev_tier check (
    is_developer = false
    or entitlement_source in ('DEV', 'MANUAL')
    or account_tier in ('FREE_PREMIUM', 'PREMIUM')
  )
);

create table if not exists public.subscription_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null,
  event_type text not null,
  product_id text,
  original_transaction_id text,
  transaction_id text,
  purchased_at timestamptz,
  expires_at timestamptz,
  raw_event jsonb,
  created_at timestamptz not null default now(),
  constraint subscription_events_provider_check check (
    provider in ('APP_STORE', 'REVENUECAT', 'MANUAL')
  )
);

create index if not exists profiles_email_idx on public.profiles(email);
create index if not exists account_entitlements_tier_idx
  on public.account_entitlements(account_tier);
create index if not exists account_entitlements_developer_idx
  on public.account_entitlements(user_id)
  where is_developer = true;
create index if not exists account_entitlements_founder_offer_idx
  on public.account_entitlements(user_id)
  where founder_offer_eligible = true;
create index if not exists account_entitlements_revenuecat_app_user_id_idx
  on public.account_entitlements(revenuecat_app_user_id)
  where revenuecat_app_user_id is not null;
create index if not exists account_entitlements_app_store_original_transaction_id_idx
  on public.account_entitlements(app_store_original_transaction_id)
  where app_store_original_transaction_id is not null;
create index if not exists subscription_events_user_created_idx
  on public.subscription_events(user_id, created_at desc);
create index if not exists subscription_events_original_transaction_idx
  on public.subscription_events(original_transaction_id)
  where original_transaction_id is not null;

alter table public.waitlist_signups
  add column if not exists founder_offer_eligible boolean not null default true,
  add column if not exists founder_offer_code text,
  add column if not exists founder_offer_redeemed_by_user_id uuid references auth.users(id) on delete set null,
  add column if not exists founder_offer_redeemed_at timestamptz;

create index if not exists waitlist_signups_founder_offer_idx
  on public.waitlist_signups(email)
  where founder_offer_eligible = true;

alter table public.profiles enable row level security;
alter table public.account_entitlements enable row level security;
alter table public.subscription_events enable row level security;

drop policy if exists "Users can read own profile" on public.profiles;
create policy "Users can read own profile"
on public.profiles
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
on public.profiles
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can read own entitlements" on public.account_entitlements;
create policy "Users can read own entitlements"
on public.account_entitlements
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can read own subscription events" on public.subscription_events;
create policy "Users can read own subscription events"
on public.subscription_events
for select
to authenticated
using ((select auth.uid()) = user_id);

revoke all on public.profiles from anon, authenticated;
revoke all on public.account_entitlements from anon, authenticated;
revoke all on public.subscription_events from anon, authenticated;

grant select on public.profiles to authenticated;
grant update (
  display_name,
  birthdate,
  bodyweight_value,
  bodyweight_unit,
  sex,
  sex_self_describe,
  preferred_units,
  onboarding_completed_at
) on public.profiles to authenticated;
grant select on public.account_entitlements to authenticated;
grant select on public.subscription_events to authenticated;

create or replace function bram_private.create_account_records_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  normalized_email text;
  waitlist_match public.waitlist_signups%rowtype;
  inferred_name text;
begin
  normalized_email := lower(coalesce(new.email, ''));
  inferred_name := nullif(
    trim(coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      new.raw_user_meta_data ->> 'display_name',
      ''
    )),
    ''
  );

  select *
  into waitlist_match
  from public.waitlist_signups
  where email = normalized_email
  order by created_at asc
  limit 1;

  insert into public.profiles (
    user_id,
    email,
    display_name
  )
  values (
    new.id,
    normalized_email,
    inferred_name
  )
  on conflict (user_id) do update
  set
    email = excluded.email,
    display_name = coalesce(public.profiles.display_name, excluded.display_name),
    updated_at = now();

  insert into public.account_entitlements (
    user_id,
    founder_offer_eligible,
    founder_offer_waitlist_signup_id,
    entitlement_source,
    manual_reason
  )
  values (
    new.id,
    coalesce(waitlist_match.founder_offer_eligible, waitlist_match.founder_discount_eligible, false),
    waitlist_match.id,
    case
      when coalesce(waitlist_match.founder_offer_eligible, waitlist_match.founder_discount_eligible, false)
        then 'FOUNDER_OFFER'::public.bram_entitlement_source
      else 'NONE'::public.bram_entitlement_source
    end,
    case
      when coalesce(waitlist_match.founder_offer_eligible, waitlist_match.founder_discount_eligible, false)
        then 'Matched from waitlist email at signup.'
      else null
    end
  )
  on conflict (user_id) do update
  set
    founder_offer_eligible = public.account_entitlements.founder_offer_eligible
      or excluded.founder_offer_eligible,
    founder_offer_waitlist_signup_id = coalesce(
      public.account_entitlements.founder_offer_waitlist_signup_id,
      excluded.founder_offer_waitlist_signup_id
    ),
    entitlement_source = case
      when public.account_entitlements.entitlement_source = 'NONE'
        then excluded.entitlement_source
      else public.account_entitlements.entitlement_source
    end,
    updated_at = now();

  if waitlist_match.id is not null then
    update public.waitlist_signups
    set
      founder_offer_redeemed_by_user_id = coalesce(founder_offer_redeemed_by_user_id, new.id),
      founder_offer_redeemed_at = coalesce(founder_offer_redeemed_at, now()),
      updated_at = now()
    where id = waitlist_match.id;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_create_bram_account on auth.users;
create trigger on_auth_user_created_create_bram_account
after insert on auth.users
for each row
execute function bram_private.create_account_records_for_new_user();

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

drop trigger if exists set_account_entitlements_updated_at on public.account_entitlements;
create trigger set_account_entitlements_updated_at
before update on public.account_entitlements
for each row
execute function public.set_updated_at();

drop view if exists public.account_snapshot;
create view public.account_snapshot
with (security_invoker = true)
as
select
  p.user_id,
  p.email,
  p.display_name,
  p.preferred_units,
  p.onboarding_completed_at,
  e.account_tier,
  e.subscription_status,
  e.entitlement_source,
  e.is_developer,
  e.founder_offer_eligible,
  e.premium_expires_at,
  e.updated_at as entitlements_updated_at
from public.profiles p
join public.account_entitlements e on e.user_id = p.user_id;

grant select on public.account_snapshot to authenticated;

comment on table public.profiles is
  'User-editable account/profile fields. Authorization flags do not live here.';
comment on table public.account_entitlements is
  'Service-role managed account tier, founder offer, subscription, and developer access flags.';
comment on column public.account_entitlements.account_tier is
  'Set to FREE_PREMIUM manually for a lifetime pass while native App Store subscription work remains separate.';
comment on column public.account_entitlements.is_developer is
  'Set true manually to reveal development/debug features in the app.';
comment on table public.subscription_events is
  'Append-only subscription history from App Store, RevenueCat, or manual service-role operations.';
comment on view public.account_snapshot is
  'Read-only app-facing account state for the authenticated user.';
