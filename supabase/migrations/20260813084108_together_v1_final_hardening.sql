-- Limit downloads to the authoritative current photo, and revalidate invite
-- creation after its couple lock so concurrent unpair cannot create an invite
-- for a dissolved relationship.
create or replace function private.is_current_partner_photo(target_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.current_partner_photos cpp
    join public.couple_members cm on cm.couple_id = cpp.couple_id
    where cpp.storage_path = target_path
      and cm.user_id = (select auth.uid())
  );
$$;

drop policy if exists "Current members can view partner photos" on storage.objects;
create policy "Current members can view partner photos"
on storage.objects for select to authenticated
using (
  bucket_id = 'partner-photos'
  and (select private.is_current_partner_photo(name))
);

revoke execute on function private.is_current_partner_photo(text)
from public, anon;
grant execute on function private.is_current_partner_photo(text) to authenticated;

create or replace function public.create_pair_invite(p_regenerate boolean default false)
returns table(
  result_status text,
  result_couple_id uuid,
  result_invite_code text,
  result_expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  caller_couple_id uuid;
  couple_row public.couples%rowtype;
  invite_row public.pair_invites%rowtype;
  new_code text;
begin
  if caller_id is null then
    raise exception using errcode = '28000', message = 'authentication_required';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(caller_id::text, 0));
  select cm.couple_id into caller_couple_id
  from public.couple_members cm where cm.user_id = caller_id;

  if caller_couple_id is not null then
    select c.* into couple_row from public.couples c
    where c.id = caller_couple_id for update;
    if couple_row.status <> 'pending'
      or couple_row.created_by <> caller_id
      or not exists (
        select 1 from public.couple_members cm
        where cm.couple_id = caller_couple_id and cm.user_id = caller_id
      ) then
      return query select 'relationship_changed', caller_couple_id, null::text, null::timestamptz;
      return;
    end if;
    if not p_regenerate then
      select pi.* into invite_row from public.pair_invites pi
      where pi.couple_id = caller_couple_id and pi.consumed_at is null
        and pi.revoked_at is null and pi.expires_at > now()
      order by pi.created_at desc limit 1;
      if found then
        return query select 'invite_ready', caller_couple_id,
          invite_row.code, invite_row.expires_at;
        return;
      end if;
    end if;
  else
    insert into public.couples(name, created_by, status, pair_code)
    values ('Together', caller_id, 'pending', null)
    returning id into caller_couple_id;
    insert into public.profiles(id, display_name, role)
    select caller_id, coalesce(nullif(split_part(au.email, '@', 1), ''), 'Partner'), null
    from auth.users au where au.id = caller_id on conflict (id) do nothing;
    insert into public.couple_members(couple_id, user_id, role)
    values (caller_couple_id, caller_id, null);
  end if;

  update public.pair_invites pi set revoked_at = now()
  where pi.couple_id = caller_couple_id
    and pi.consumed_at is null and pi.revoked_at is null;
  loop
    new_code := upper(substr(encode(extensions.gen_random_bytes(6), 'hex'), 1, 6)
      || '-' || substr(encode(extensions.gen_random_bytes(6), 'hex'), 1, 6));
    exit when not exists (select 1 from public.pair_invites pi where pi.code = new_code);
  end loop;
  insert into public.pair_invites(couple_id, code, created_by, expires_at)
  values (caller_couple_id, new_code, caller_id, now() + interval '72 hours')
  returning * into invite_row;
  return query select 'invite_ready', caller_couple_id,
    invite_row.code, invite_row.expires_at;
end;
$$;

revoke execute on function public.create_pair_invite(boolean) from public, anon;
grant execute on function public.create_pair_invite(boolean) to authenticated;
