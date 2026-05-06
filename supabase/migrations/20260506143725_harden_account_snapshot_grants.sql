revoke all on public.account_snapshot from anon, authenticated;
grant select on public.account_snapshot to authenticated;

comment on view public.account_snapshot is
  'Read-only app-facing account state for the authenticated user. Explicitly not granted to anon.';
