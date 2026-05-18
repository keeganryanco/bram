create or replace function public.apply_best_available_promo()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  current_user_id uuid;
  profile_email text;
  candidate record;
  current_entitlement record;
  candidate_rank integer;
  current_rank integer;
  next_expires_at timestamptz;
  next_source public.bram_entitlement_source;
begin
  current_user_id := auth.uid();

  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select email
  into profile_email
  from public.profiles
  where user_id = current_user_id;

  if profile_email is null then
    return;
  end if;

  select *
  into current_entitlement
  from public.account_entitlements
  where user_id = current_user_id;

  if current_entitlement.is_developer = true
    or current_entitlement.account_tier = 'PREMIUM' then
    return;
  end if;

  select
    pe.*,
    case pe.grant_kind
      when 'FRIENDS_DISCOUNT' then 500
      when 'FOUNDER_LIFETIME' then 400
      when 'FOUNDER_1MONTH' then 300
      when 'PRODUCT_HUNT_1MONTH' then 200
      when 'TESTFLIGHT_1MONTH' then 100
      else 0
    end as promo_rank
  into candidate
  from public.account_promo_eligibilities pe
  where (pe.user_id = current_user_id or pe.email = profile_email)
    and pe.redeemed_at is null
    and (pe.expires_at is null or pe.expires_at > now())
  order by promo_rank desc, pe.created_at asc
  limit 1;

  if candidate.id is null then
    return;
  end if;

  candidate_rank := candidate.promo_rank;
  current_rank := case current_entitlement.active_promo_kind
    when 'FRIENDS_DISCOUNT' then 500
    when 'FOUNDER_LIFETIME' then 400
    when 'FOUNDER_1MONTH' then 300
    when 'PRODUCT_HUNT_1MONTH' then 200
    when 'TESTFLIGHT_1MONTH' then 100
    else 0
  end;

  if current_entitlement.account_tier = 'FREE_PREMIUM'
    and (
      current_entitlement.premium_expires_at is null
      or current_entitlement.premium_expires_at > now()
    )
    and current_rank >= candidate_rank then
    return;
  end if;

  next_expires_at := case
    when candidate.grant_kind in ('FRIENDS_DISCOUNT', 'FOUNDER_LIFETIME') then null
    else now() + interval '1 month'
  end;

  next_source := case
    when candidate.grant_kind in ('FOUNDER_1MONTH', 'FOUNDER_LIFETIME')
      then 'FOUNDER_OFFER'::public.bram_entitlement_source
    else 'MANUAL'::public.bram_entitlement_source
  end;

  update public.account_entitlements
  set
    account_tier = 'FREE_PREMIUM',
    subscription_status = 'FREE_PREMIUM',
    entitlement_source = next_source,
    premium_expires_at = next_expires_at,
    active_promo_kind = candidate.grant_kind,
    active_promo_code = candidate.promo_code,
    active_promo_label = candidate.label,
    manual_reason = 'Automatically applied best available account promo.',
    founder_offer_redeemed_at = case
      when candidate.grant_kind in ('FOUNDER_1MONTH', 'FOUNDER_LIFETIME')
        then coalesce(founder_offer_redeemed_at, now())
      else founder_offer_redeemed_at
    end,
    updated_at = now()
  where user_id = current_user_id;

  update public.account_promo_eligibilities
  set
    redeemed_by_user_id = current_user_id,
    redeemed_at = now(),
    updated_at = now()
  where id = candidate.id;
end;
$$;

revoke all on function public.apply_best_available_promo() from public;
grant execute on function public.apply_best_available_promo() to authenticated;

comment on function public.apply_best_available_promo() is
  'Authenticated user helper that applies the best unredeemed account-specific promo eligibility, without trusting client-supplied entitlement values.';
