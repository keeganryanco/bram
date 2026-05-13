alter table public.subscription_events
  add column if not exists provider_event_id text;

create unique index if not exists subscription_events_provider_event_id_idx
  on public.subscription_events(provider, provider_event_id)
  where provider_event_id is not null;

comment on column public.subscription_events.provider_event_id is
  'Provider event identifier used to make webhook processing idempotent.';
