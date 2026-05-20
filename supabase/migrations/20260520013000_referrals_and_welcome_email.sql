alter table public.account_promo_eligibilities
  drop constraint if exists account_promo_eligibilities_kind_check;

alter table public.account_promo_eligibilities
  add constraint account_promo_eligibilities_kind_check check (
    grant_kind in (
      'TESTFLIGHT_1MONTH',
      'PRODUCT_HUNT_1MONTH',
      'FOUNDER_1MONTH',
      'FOUNDER_LIFETIME',
      'FRIENDS_DISCOUNT',
      'REFERRAL_1MONTH'
    )
  );

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
      'FRIENDS_DISCOUNT',
      'REFERRAL_1MONTH'
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
      'FRIENDS_DISCOUNT',
      'REFERRAL_1MONTH'
    )
  );

create table if not exists public.account_referral_codes (
  user_id uuid primary key references auth.users(id) on delete cascade,
  code text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint account_referral_codes_uppercase check (code = upper(code)),
  constraint account_referral_codes_format check (code ~ '^BRAM[A-Z0-9]{6,14}$')
);

create table if not exists public.account_referral_redemptions (
  id uuid primary key default gen_random_uuid(),
  referral_code text not null references public.account_referral_codes(code) on delete restrict,
  referrer_user_id uuid not null references auth.users(id) on delete cascade,
  referred_user_id uuid not null references auth.users(id) on delete cascade,
  redeemed_at timestamptz not null default now(),
  constraint account_referral_redemptions_no_self_check check (referrer_user_id <> referred_user_id)
);

create unique index if not exists account_referral_redemptions_code_referred_idx
  on public.account_referral_redemptions(referral_code, referred_user_id);

create unique index if not exists account_referral_redemptions_referred_once_idx
  on public.account_referral_redemptions(referred_user_id);

create table if not exists public.account_referral_rewards (
  id uuid primary key default gen_random_uuid(),
  redemption_id uuid not null unique references public.account_referral_redemptions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reward_kind text not null default 'REFERRAL_1MONTH',
  status text not null,
  premium_expires_at timestamptz,
  reason text,
  created_at timestamptz not null default now(),
  constraint account_referral_rewards_kind_check check (reward_kind in ('REFERRAL_1MONTH')),
  constraint account_referral_rewards_status_check check (status in ('APPLIED', 'QUEUED', 'SKIPPED'))
);

alter table public.account_referral_codes enable row level security;
alter table public.account_referral_redemptions enable row level security;
alter table public.account_referral_rewards enable row level security;

revoke all on public.account_referral_codes from anon, authenticated;
revoke all on public.account_referral_redemptions from anon, authenticated;
revoke all on public.account_referral_rewards from anon, authenticated;

drop trigger if exists set_account_referral_codes_updated_at on public.account_referral_codes;
create trigger set_account_referral_codes_updated_at
before update on public.account_referral_codes
for each row
execute function public.set_updated_at();

comment on table public.account_referral_codes is
  'Service-route managed user referral codes. Clients read them only through authenticated server routes.';
comment on table public.account_referral_redemptions is
  'Service-route managed audit of referral code redemptions.';
comment on table public.account_referral_rewards is
  'Service-route managed audit of referrer rewards; queued rewards are not Apple subscription extensions.';
