drop index if exists public.subscription_events_provider_event_id_idx;

create unique index if not exists subscription_events_provider_event_id_idx
  on public.subscription_events(provider, provider_event_id);

comment on index public.subscription_events_provider_event_id_idx is
  'Unique RevenueCat event idempotency target for PostgREST upsert on provider,provider_event_id. Null event ids remain insert-only.';
