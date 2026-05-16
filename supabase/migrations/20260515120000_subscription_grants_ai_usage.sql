create table if not exists public.account_grant_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  grant_kind text not null,
  entitlement_source public.bram_entitlement_source not null,
  premium_starts_at timestamptz not null default now(),
  premium_expires_at timestamptz,
  ai_soft_cap_cents integer,
  ai_hard_cap_cents integer,
  reason text,
  created_by text,
  created_at timestamptz not null default now(),
  constraint account_grant_events_kind_check check (
    grant_kind in ('TESTFLIGHT', 'PRODUCT_HUNT', 'FOUNDER_LIFETIME')
  ),
  constraint account_grant_events_caps_positive check (
    (ai_soft_cap_cents is null or ai_soft_cap_cents > 0)
    and (ai_hard_cap_cents is null or ai_hard_cap_cents > 0)
    and (
      ai_soft_cap_cents is null
      or ai_hard_cap_cents is null
      or ai_soft_cap_cents <= ai_hard_cap_cents
    )
  )
);

create index if not exists account_grant_events_user_created_idx
  on public.account_grant_events(user_id, created_at desc);

create table if not exists public.ai_usage_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  usage_month date not null,
  task text not null,
  model text not null,
  requested_model text,
  estimated_cost_cents integer not null default 0,
  policy_decision text not null,
  response_id text,
  created_at timestamptz not null default now(),
  constraint ai_usage_events_cost_nonnegative check (estimated_cost_cents >= 0),
  constraint ai_usage_events_policy_check check (
    policy_decision in ('NORMAL', 'DOWNGRADED', 'BLOCKED')
  )
);

create index if not exists ai_usage_events_user_month_idx
  on public.ai_usage_events(user_id, usage_month);

alter table public.account_grant_events enable row level security;
alter table public.ai_usage_events enable row level security;

revoke all on public.account_grant_events from anon, authenticated;
revoke all on public.ai_usage_events from anon, authenticated;

comment on table public.account_grant_events is
  'Service-role-only audit history for TestFlight, Product Hunt, and founder grants.';
comment on table public.ai_usage_events is
  'Server-only AI usage ledger. Stores usage metadata and estimated cost only; never raw workout notes.';

create or replace view public.account_snapshot
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
  e.updated_at as entitlements_updated_at
from public.profiles p
join public.account_entitlements e on e.user_id = p.user_id;

revoke all on public.account_snapshot from anon, authenticated;
grant select on public.account_snapshot to authenticated;
