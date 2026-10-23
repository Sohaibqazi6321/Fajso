-- Cover foreign keys used during account deletion and pending-couple lookup.
create index if not exists couples_created_by_idx on public.couples(created_by);
create index if not exists pair_invites_consumed_by_idx on public.pair_invites(consumed_by);
