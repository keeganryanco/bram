create table if not exists public.support_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null,
  message text not null,
  contact_email text,
  contact_display_name text,
  source text,
  app_version text,
  build_number text,
  os_version text,
  device_model text,
  diagnostics jsonb not null default '{}'::jsonb,
  linear_issue_id text,
  linear_issue_url text,
  status text not null default 'OPEN',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint support_requests_category_check check (
    category in ('BUG', 'ACCOUNT', 'BILLING', 'WORKOUT_DATA', 'FEEDBACK', 'OTHER')
  ),
  constraint support_requests_status_check check (
    status in ('OPEN', 'TRIAGED', 'CLOSED')
  )
);

create index if not exists support_requests_user_created_idx
  on public.support_requests(user_id, created_at desc);

create table if not exists public.app_error_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  severity text not null,
  source text not null,
  event_name text not null,
  message text,
  error_code text,
  app_version text,
  build_number text,
  os_version text,
  device_model text,
  diagnostics jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint app_error_reports_severity_check check (
    severity in ('INFO', 'WARNING', 'ERROR', 'FATAL')
  )
);

create index if not exists app_error_reports_user_created_idx
  on public.app_error_reports(user_id, created_at desc);
create index if not exists app_error_reports_event_created_idx
  on public.app_error_reports(event_name, created_at desc);

alter table public.support_requests enable row level security;
alter table public.app_error_reports enable row level security;

revoke all on public.support_requests from anon, authenticated;
revoke all on public.app_error_reports from anon, authenticated;

comment on table public.support_requests is
  'Service-role-only in-app support inbox. Messages are user-submitted support content and may be linked to account identity.';
comment on table public.app_error_reports is
  'Service-role-only app diagnostics. Stores crash/nonfatal metadata only; never raw workout notes, Health samples, or body measurements.';
