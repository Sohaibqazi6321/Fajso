-- Standardize pairing lock order and keep spent invitations compatible with
-- Auth account deletion.

alter table public.pair_invites
  drop constraint if exists pair_invites_consumption_check;

alter table public.pair_invites
  add constraint pair_invites_consumption_check check (
    consumed_at is not null or consumed_by is null
  );

create or replace function public.join_pair_invite(p_invite_code text)
returns table(result_status text, result_couple_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  normalized_code text := regexp_replace(upper(coalesce(p_invite_code, '')), '[^A-Z0-9]', '', 'g');
  formatted_code text;
  target_couple_id uuid;
  invite_row public.pair_invites%rowtype;
  existing_couple_id uuid;
  member_total integer;
begin
  if caller_id is null then
    raise exception using errcode = '28000', message = 'authentication_required';
  end if;

  if length(normalized_code) <> 12 then
    return query select 'invalid_invite', null::uuid;
    return;
  end if;
  formatted_code := substr(normalized_code, 1, 6) || '-' || substr(normalized_code, 7, 6);

  perform pg_advisory_xact_lock(hashtextextended(caller_id::text, 0));

  select pi.couple_id into target_couple_id
  from public.pair_invites pi where pi.code = formatted_code;
  if target_couple_id is null then
    return query select 'invalid_invite', null::uuid;
    return;
  end if;

  -- Every pairing mutation locks couple then invite to avoid lock inversion.
  perform 1 from public.couples c where c.id = target_couple_id for update;
  select pi.* into invite_row
  from public.pair_invites pi
  where pi.code = formatted_code and pi.couple_id = target_couple_id
  for update;
  if not found then
    return query select 'invalid_invite', null::uuid;
    return;
  end if;

  select cm.couple_id into existing_couple_id
  from public.couple_members cm where cm.user_id = caller_id;
  if existing_couple_id is not null then
    if existing_couple_id = invite_row.couple_id and invite_row.consumed_by = caller_id then
      return query select 'paired', existing_couple_id;
    else
      return query select 'already_paired', existing_couple_id;
    end if;
    return;
  end if;

  if invite_row.revoked_at is not null then
    return query select 'invalid_invite', null::uuid;
    return;
  end if;
  if invite_row.consumed_at is not null then
    return query select 'used_invite', null::uuid;
    return;
  end if;
  if invite_row.expires_at <= now() then
    return query select 'expired_invite', null::uuid;
    return;
  end if;
  if invite_row.created_by = caller_id then
    return query select 'own_invite', null::uuid;
    return;
  end if;
  if not exists (
    select 1 from public.couples c
    where c.id = invite_row.couple_id and c.status = 'pending'
  ) then
    return query select 'used_invite', null::uuid;
    return;
  end if;

  select count(*)::integer into member_total
  from public.couple_members cm where cm.couple_id = invite_row.couple_id;
  if member_total >= 2 then
    return query select 'invite_full', null::uuid;
    return;
  end if;

  insert into public.profiles(id, display_name, role)
  select caller_id,
    coalesce(nullif(split_part(au.email, '@', 1), ''), 'Partner'), null
  from auth.users au where au.id = caller_id
  on conflict (id) do nothing;

  insert into public.couple_members(couple_id, user_id, role)
  values (invite_row.couple_id, caller_id, null);

  update public.pair_invites
  set consumed_at = now(), consumed_by = caller_id
  where id = invite_row.id;
  update public.couples set status = 'active' where id = invite_row.couple_id;

  return query select 'paired', invite_row.couple_id;
end;
$$;

revoke execute on function public.join_pair_invite(text) from public, anon;
grant execute on function public.join_pair_invite(text) to authenticated;
