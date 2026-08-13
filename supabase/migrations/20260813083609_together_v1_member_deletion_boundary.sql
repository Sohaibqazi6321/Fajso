-- Keep relationship state recoverable when Auth account deletion cascades a
-- membership row without first calling the app's unpair RPC.
create or replace function private.reconcile_couple_after_member_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Never reuse a couple UUID after one membership disappears. Storage paths
  -- are scoped by that UUID, so reuse could expose an orphaned old object to a
  -- future partner.
  perform 1 from public.couples c where c.id = old.couple_id for update;
  update public.pair_invites
  set revoked_at = coalesce(revoked_at, now())
  where couple_id = old.couple_id and consumed_at is null;
  delete from public.current_partner_photos where couple_id = old.couple_id;
  delete from public.locations where couple_id = old.couple_id;
  delete from public.couple_members where couple_id = old.couple_id;
  update public.couples
  set status = 'dissolved', created_by = null, pair_code = null
  where id = old.couple_id;
  return old;
end;
$$;

drop trigger if exists reconcile_couple_after_member_delete on public.couple_members;
create trigger reconcile_couple_after_member_delete
after delete on public.couple_members
for each row execute function private.reconcile_couple_after_member_delete();

revoke execute on function private.reconcile_couple_after_member_delete() from public, anon, authenticated;
