-- Upgrade-path fixes identified by the independent pre-deployment security review.
-- The legacy schema made membership.role NOT NULL, while V1 intentionally does
-- not use identity roles. RLS callers also need narrowly scoped EXECUTE access to
-- the auth-bound helpers referenced by policies.

alter table public.couple_members
  alter column role drop not null;

grant usage on schema private to authenticated;
grant execute on function private.is_couple_member(uuid) to authenticated;
grant execute on function private.is_self_couple_member(uuid, uuid) to authenticated;
grant execute on function private.try_uuid(text) to authenticated;
