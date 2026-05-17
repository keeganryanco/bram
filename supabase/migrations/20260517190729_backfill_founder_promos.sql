with founder_matches as (
  select
    e.user_id,
    w.id as waitlist_signup_id
  from public.account_entitlements e
  join public.profiles p on p.user_id = e.user_id
  join public.waitlist_signups w on w.email = p.email
  where coalesce(w.founder_offer_eligible, w.founder_discount_eligible, false) = true
    and e.is_developer = false
    and e.account_tier = 'FREE'
)
update public.account_entitlements e
set
  account_tier = 'FREE_PREMIUM',
  subscription_status = 'FREE_PREMIUM',
  entitlement_source = 'FOUNDER_OFFER',
  founder_offer_eligible = true,
  founder_offer_waitlist_signup_id = coalesce(e.founder_offer_waitlist_signup_id, founder_matches.waitlist_signup_id),
  premium_expires_at = now() + interval '1 month',
  active_promo_kind = 'FOUNDER_1MONTH',
  active_promo_code = 'FOUNDER1MONTH',
  active_promo_label = 'Founder month',
  manual_reason = 'Matched from waitlist email; one-month founder promo backfilled.',
  updated_at = now()
from founder_matches
where e.user_id = founder_matches.user_id;

update public.waitlist_signups w
set
  founder_offer_redeemed_by_user_id = coalesce(w.founder_offer_redeemed_by_user_id, p.user_id),
  founder_offer_redeemed_at = coalesce(w.founder_offer_redeemed_at, now()),
  updated_at = now()
from public.profiles p
join public.account_entitlements e on e.user_id = p.user_id
where w.email = p.email
  and coalesce(w.founder_offer_eligible, w.founder_discount_eligible, false) = true
  and e.active_promo_kind = 'FOUNDER_1MONTH';
