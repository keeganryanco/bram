create table if not exists public.account_promo_eligibilities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  email text,
  promo_code text not null,
  grant_kind text not null,
  label text not null,
  expires_at timestamptz,
  redeemed_by_user_id uuid references auth.users(id) on delete set null,
  redeemed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint account_promo_eligibilities_target_check check (
    user_id is not null or email is not null
  ),
  constraint account_promo_eligibilities_email_lowercase check (
    email is null or email = lower(email)
  ),
  constraint account_promo_eligibilities_kind_check check (
    grant_kind in (
      'TESTFLIGHT_1MONTH',
      'PRODUCT_HUNT_1MONTH',
      'FOUNDER_1MONTH',
      'FOUNDER_LIFETIME',
      'FRIENDS_DISCOUNT'
    )
  )
);

create unique index if not exists account_promo_eligibilities_user_code_idx
  on public.account_promo_eligibilities(user_id, upper(promo_code))
  where user_id is not null;

create unique index if not exists account_promo_eligibilities_email_code_idx
  on public.account_promo_eligibilities(email, upper(promo_code))
  where email is not null;

alter table public.account_entitlements
  add column if not exists active_promo_kind text,
  add column if not exists active_promo_code text,
  add column if not exists active_promo_label text;

alter table public.account_entitlements
  drop constraint if exists account_entitlements_active_promo_kind_check;

alter table public.account_entitlements
  add constraint account_entitlements_active_promo_kind_check check (
    active_promo_kind is null
    or active_promo_kind in (
      'TESTFLIGHT_1MONTH',
      'PRODUCT_HUNT_1MONTH',
      'FOUNDER_1MONTH',
      'FOUNDER_LIFETIME',
      'FRIENDS_DISCOUNT'
    )
  );

alter table public.account_grant_events
  drop constraint if exists account_grant_events_kind_check;

alter table public.account_grant_events
  add constraint account_grant_events_kind_check check (
    grant_kind in (
      'TESTFLIGHT',
      'PRODUCT_HUNT',
      'TESTFLIGHT_1MONTH',
      'PRODUCT_HUNT_1MONTH',
      'FOUNDER_1MONTH',
      'FOUNDER_LIFETIME',
      'FRIENDS_DISCOUNT'
    )
  );

alter table public.account_promo_eligibilities enable row level security;
revoke all on public.account_promo_eligibilities from anon, authenticated;

drop trigger if exists set_account_promo_eligibilities_updated_at on public.account_promo_eligibilities;
create trigger set_account_promo_eligibilities_updated_at
before update on public.account_promo_eligibilities
for each row
execute function public.set_updated_at();

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
  is_founder_eligible boolean;
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

  is_founder_eligible := coalesce(
    waitlist_match.founder_offer_eligible,
    waitlist_match.founder_discount_eligible,
    false
  );

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
    account_tier,
    subscription_status,
    entitlement_source,
    founder_offer_eligible,
    founder_offer_waitlist_signup_id,
    premium_expires_at,
    active_promo_kind,
    active_promo_code,
    active_promo_label,
    manual_reason
  )
  values (
    new.id,
    case
      when is_founder_eligible then 'FREE_PREMIUM'::public.bram_account_tier
      else 'FREE'::public.bram_account_tier
    end,
    case
      when is_founder_eligible then 'FREE_PREMIUM'::public.bram_subscription_status
      else 'NONE'::public.bram_subscription_status
    end,
    case
      when is_founder_eligible then 'FOUNDER_OFFER'::public.bram_entitlement_source
      else 'NONE'::public.bram_entitlement_source
    end,
    is_founder_eligible,
    waitlist_match.id,
    case when is_founder_eligible then now() + interval '1 month' else null end,
    case when is_founder_eligible then 'FOUNDER_1MONTH' else null end,
    case when is_founder_eligible then 'FOUNDER1MONTH' else null end,
    case when is_founder_eligible then 'Founder month' else null end,
    case
      when is_founder_eligible then 'Matched from waitlist email at signup; one-month founder promo auto-applied.'
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
    account_tier = case
      when public.account_entitlements.account_tier in ('PREMIUM', 'FREE_PREMIUM')
        then public.account_entitlements.account_tier
      else excluded.account_tier
    end,
    subscription_status = case
      when public.account_entitlements.account_tier in ('PREMIUM', 'FREE_PREMIUM')
        then public.account_entitlements.subscription_status
      else excluded.subscription_status
    end,
    entitlement_source = case
      when public.account_entitlements.entitlement_source = 'NONE'
        then excluded.entitlement_source
      else public.account_entitlements.entitlement_source
    end,
    premium_expires_at = coalesce(public.account_entitlements.premium_expires_at, excluded.premium_expires_at),
    active_promo_kind = coalesce(public.account_entitlements.active_promo_kind, excluded.active_promo_kind),
    active_promo_code = coalesce(public.account_entitlements.active_promo_code, excluded.active_promo_code),
    active_promo_label = coalesce(public.account_entitlements.active_promo_label, excluded.active_promo_label),
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
  case
    when e.account_tier = 'FREE_PREMIUM'
      and e.is_developer = false
      and e.premium_expires_at is not null
      and e.premium_expires_at <= now()
      then 'FREE'::public.bram_account_tier
    else e.account_tier
  end as account_tier,
  case
    when e.account_tier = 'FREE_PREMIUM'
      and e.is_developer = false
      and e.premium_expires_at is not null
      and e.premium_expires_at <= now()
      then 'EXPIRED'::public.bram_subscription_status
    else e.subscription_status
  end as subscription_status,
  case
    when e.account_tier = 'FREE_PREMIUM'
      and e.is_developer = false
      and e.premium_expires_at is not null
      and e.premium_expires_at <= now()
      then 'NONE'::public.bram_entitlement_source
    else e.entitlement_source
  end as entitlement_source,
  e.is_developer,
  e.founder_offer_eligible,
  case
    when e.account_tier = 'FREE_PREMIUM'
      and e.is_developer = false
      and e.premium_expires_at is not null
      and e.premium_expires_at <= now()
      then null
    else e.premium_expires_at
  end as premium_expires_at,
  case
    when e.account_tier = 'FREE_PREMIUM'
      and e.is_developer = false
      and e.premium_expires_at is not null
      and e.premium_expires_at <= now()
      then null
    else e.active_promo_kind
  end as active_promo_kind,
  case
    when e.account_tier = 'FREE_PREMIUM'
      and e.is_developer = false
      and e.premium_expires_at is not null
      and e.premium_expires_at <= now()
      then null
    else e.active_promo_code
  end as active_promo_code,
  case
    when e.account_tier = 'FREE_PREMIUM'
      and e.is_developer = false
      and e.premium_expires_at is not null
      and e.premium_expires_at <= now()
      then null
    else e.active_promo_label
  end as active_promo_label,
  e.updated_at as entitlements_updated_at
from public.profiles p
join public.account_entitlements e on e.user_id = p.user_id;

revoke all on public.account_snapshot from anon, authenticated;
grant select on public.account_snapshot to authenticated;

comment on table public.account_promo_eligibilities is
  'Service-role-only allowlist for Bram-owned promo codes. iOS submits a code, but eligibility is decided server-side.';
comment on column public.account_entitlements.active_promo_kind is
  'Current Bram-owned promo/grant kind used for app copy and grant precedence.';
comment on column public.account_entitlements.active_promo_code is
  'Promo code that produced the current Bram-owned grant, when applicable.';
comment on column public.account_entitlements.active_promo_label is
  'Short user-facing label for the current Bram-owned grant.';
