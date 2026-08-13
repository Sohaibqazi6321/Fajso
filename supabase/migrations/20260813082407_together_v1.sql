-- Together V1: atomic invitations, two-person authorization, current locations,
-- and one current partner-photo pointer per sender.
-- This migration is intentionally forward-only. Legacy role/pair-code columns and
-- the unused messages table remain for compatibility, but V1 no longer uses them.

create extension if not exists pgcrypto;
create schema if not exists private;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  role text check (role in ('sohaib', 'fajr')),
  created_at timestamptz not null default now()
);

create table if not exists public.couples (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Together',
  pair_code text unique,
  created_at timestamptz not null default now()
);

create table if not exists public.couple_members (
  couple_id uuid not null references public.couples(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text check (role in ('sohaib', 'fajr')),
  joined_at timestamptz not null default now(),
  primary key (couple_id, user_id),
  unique (couple_id, role),
  unique (user_id)
);

create table if not exists public.locations (
  couple_id uuid not null references public.couples(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  accuracy_meters double precision,
  updated_at timestamptz not null default now(),
  primary key (couple_id, user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  sender_user_id uuid not null references auth.users(id) on delete cascade,
  text text not null check (char_length(text) between 1 and 160),
  created_at timestamptz not null default now()
);

create table if not exists public.photos (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  sender_user_id uuid not null references auth.users(id) on delete cascade,
  storage_path text not null,
  receiver_saved_at timestamptz,
  storage_deleted_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.profiles
  alter column role drop not null;

alter table public.couple_members
  alter column role drop not null;

alter table public.couples
  add column if not exists created_by uuid references auth.users(id) on delete set null,
  add column if not exists status text not null default 'pending';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'couples_status_check'
      and conrelid = 'public.couples'::regclass
  ) then
    alter table public.couples
      add constraint couples_status_check
      check (status in ('pending', 'active', 'dissolved'));
  end if;
end
$$;

update public.couples c
set created_by = (
  select cm.user_id
  from public.couple_members cm
  where cm.couple_id = c.id
  order by cm.joined_at
  limit 1
)
where c.created_by is null
  and exists (
    select 1 from public.couple_members cm where cm.couple_id = c.id
  );

update public.couples c
set status = case
  when (select count(*) from public.couple_members cm where cm.couple_id = c.id) >= 2
    then 'active'
  else 'pending'
end
where c.status <> 'dissolved';

alter table public.locations
  add column if not exists captured_at timestamptz;

update public.locations
set captured_at = updated_at
where captured_at is null;

alter table public.locations
  alter column captured_at set default now(),
  alter column captured_at set not null;

create table if not exists public.pair_invites (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  code text not null unique,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  consumed_by uuid references auth.users(id) on delete set null,
  revoked_at timestamptz,
  constraint pair_invites_code_format_check
    check (code ~ '^[A-Z0-9]{6}-[A-Z0-9]{6}$'),
  constraint pair_invites_expiry_check check (expires_at > created_at),
  constraint pair_invites_consumption_check check (
    consumed_at is not null or consumed_by is null
  )
);

create unique index if not exists pair_invites_one_open_per_couple_idx
  on public.pair_invites(couple_id)
  where consumed_at is null and revoked_at is null;
create index if not exists pair_invites_created_by_idx
  on public.pair_invites(created_by);
create index if not exists pair_invites_consumed_by_idx
  on public.pair_invites(consumed_by);
create index if not exists couples_created_by_idx
  on public.couples(created_by);

create table if not exists public.current_partner_photos (
  couple_id uuid not null,
  sender_user_id uuid not null,
  photo_id uuid not null,
  storage_path text not null,
  updated_at timestamptz not null default now(),
  primary key (couple_id, sender_user_id),
  unique (photo_id),
  unique (storage_path),
  constraint current_partner_photos_member_fkey
    foreign key (couple_id, sender_user_id)
    references public.couple_members(couple_id, user_id)
    on delete cascade
);

-- The legacy setup RPC could move a membership while leaving its old current
-- location behind. Remove those inaccessible orphan rows before adding the
-- composite ownership foreign key.
delete from public.locations l
where not exists (
  select 1 from public.couple_members cm
  where cm.couple_id = l.couple_id and cm.user_id = l.user_id
);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'locations_member_fkey'
      and conrelid = 'public.locations'::regclass
  ) then
    alter table public.locations
      add constraint locations_member_fkey
      foreign key (couple_id, user_id)
      references public.couple_members(couple_id, user_id)
      on delete cascade;
  end if;
end
$$;

create index if not exists locations_user_id_idx on public.locations(user_id);
create index if not exists photos_sender_user_id_idx on public.photos(sender_user_id);
create index if not exists messages_sender_user_id_idx on public.messages(sender_user_id);
create index if not exists current_partner_photos_sender_idx
  on public.current_partner_photos(sender_user_id);

create or replace function private.is_couple_member(target_couple_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.couple_members cm
    where cm.couple_id = target_couple_id
      and cm.user_id = (select auth.uid())
  );
$$;

create or replace function private.is_self_couple_member(
  target_couple_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select target_user_id = (select auth.uid())
    and exists (
      select 1
      from public.couple_members cm
      where cm.couple_id = target_couple_id
        and cm.user_id = target_user_id
    );
$$;

create or replace function private.try_uuid(value text)
returns uuid
language plpgsql
immutable
set search_path = ''
as $$
begin
  return value::uuid;
exception
  when invalid_text_representation then return null;
end;
$$;

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

create or replace function private.enforce_two_couple_members()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  member_total integer;
begin
  perform 1 from public.couples c where c.id = new.couple_id for update;

  if tg_op = 'INSERT' then
    select count(*)::integer into member_total
    from public.couple_members cm where cm.couple_id = new.couple_id;
  else
    select count(*)::integer into member_total
    from public.couple_members cm
    where cm.couple_id = new.couple_id and cm.user_id <> old.user_id;
  end if;

  if member_total >= 2 then
    raise exception using errcode = 'P0001', message = 'couple_full';
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_two_couple_members on public.couple_members;
create trigger enforce_two_couple_members
before insert or update of couple_id on public.couple_members
for each row execute function private.enforce_two_couple_members();

create or replace function private.reconcile_couple_after_member_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- A membership deletion ends this authorization boundary. Never reuse the
  -- couple UUID for a future relationship, because old private object paths
  -- are couple-scoped.
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

create or replace function private.touch_location_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists touch_location_updated_at on public.locations;
create trigger touch_location_updated_at
before update on public.locations
for each row execute function private.touch_location_updated_at();

create or replace function private.prevent_stale_location_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.captured_at <= old.captured_at then
    return null;
  end if;
  return new;
end;
$$;

drop trigger if exists prevent_stale_location_update on public.locations;
create trigger prevent_stale_location_update
before update on public.locations
for each row execute function private.prevent_stale_location_update();

alter table public.pair_invites enable row level security;
alter table public.current_partner_photos enable row level security;
alter table public.profiles enable row level security;
alter table public.couples enable row level security;
alter table public.couple_members enable row level security;
alter table public.locations enable row level security;
alter table public.messages enable row level security;
alter table public.photos enable row level security;

drop policy if exists "Authenticated users can create a couple" on public.couples;
drop policy if exists "Users can join as themselves" on public.couple_members;

drop policy if exists "Couple members can view their couple" on public.couples;
create policy "Current members can view their couple"
on public.couples for select to authenticated
using ((select private.is_couple_member(id)));

drop policy if exists "Couple members can view memberships" on public.couple_members;
create policy "Current members can view memberships"
on public.couple_members for select to authenticated
using ((select private.is_couple_member(couple_id)));

drop policy if exists "Users can insert their profile" on public.profiles;
drop policy if exists "Users can view their profile and partner profile" on public.profiles;
create policy "Users can view their profile and partner profile"
on public.profiles for select to authenticated
using (
  id = (select auth.uid())
  or exists (
    select 1
    from public.couple_members mine
    join public.couple_members partner on partner.couple_id = mine.couple_id
    where mine.user_id = (select auth.uid())
      and partner.user_id = profiles.id
  )
);

drop policy if exists "Users can update their profile" on public.profiles;
create policy "Users can update their display name"
on public.profiles for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

drop policy if exists "Couple members can view locations" on public.locations;
create policy "Current members can view locations"
on public.locations for select to authenticated
using ((select private.is_couple_member(couple_id)));

drop policy if exists "Users can insert their location" on public.locations;
create policy "Users can insert their current location"
on public.locations for insert to authenticated
with check ((select private.is_self_couple_member(couple_id, user_id)));

drop policy if exists "Users can update their location" on public.locations;
create policy "Users can update their current location"
on public.locations for update to authenticated
using ((select private.is_self_couple_member(couple_id, user_id)))
with check ((select private.is_self_couple_member(couple_id, user_id)));

create policy "Current members can view current partner photos"
on public.current_partner_photos for select to authenticated
using ((select private.is_couple_member(couple_id)));

-- Legacy metadata remains readable to a current couple for compatibility, but V1
-- has no direct write grants and publishes only through current_partner_photos.
drop policy if exists "Couple members can add their photos" on public.photos;
drop policy if exists "Couple members can update photo transfer state" on public.photos;
drop policy if exists "Couple members can view photos" on public.photos;
create policy "Current members can view legacy photo metadata"
on public.photos for select to authenticated
using ((select private.is_couple_member(couple_id)));

drop policy if exists "Couple members can view messages" on public.messages;
drop policy if exists "Couple members can send their messages" on public.messages;
create policy "Current members can view legacy messages"
on public.messages for select to authenticated
using ((select private.is_couple_member(couple_id)));

drop policy if exists "Couple members can view partner photos" on storage.objects;
create policy "Current members can view partner photos"
on storage.objects for select to authenticated
using (
  bucket_id = 'partner-photos'
  and (select private.is_current_partner_photo(name))
);

drop policy if exists "Users can upload their partner photos" on storage.objects;
create policy "Members can upload their own partner photos"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'partner-photos'
  and (select private.is_self_couple_member(
    private.try_uuid((storage.foldername(name))[1]),
    private.try_uuid((storage.foldername(name))[2])
  ))
);

drop policy if exists "Users can update their partner photos" on storage.objects;
create policy "Members can update their own partner photos"
on storage.objects for update to authenticated
using (
  bucket_id = 'partner-photos'
  and (select private.is_self_couple_member(
    private.try_uuid((storage.foldername(name))[1]),
    private.try_uuid((storage.foldername(name))[2])
  ))
)
with check (
  bucket_id = 'partner-photos'
  and (select private.is_self_couple_member(
    private.try_uuid((storage.foldername(name))[1]),
    private.try_uuid((storage.foldername(name))[2])
  ))
);

drop policy if exists "Couple members can delete transferred partner photos" on storage.objects;
create policy "Members can delete their own partner photos"
on storage.objects for delete to authenticated
using (
  bucket_id = 'partner-photos'
  and (select private.is_self_couple_member(
    private.try_uuid((storage.foldername(name))[1]),
    private.try_uuid((storage.foldername(name))[2])
  ))
);

-- The old role/permanent-code setup endpoint is removed. DROP is required because
-- PostgreSQL cannot rename RETURNS TABLE output parameters with CREATE OR REPLACE.
drop function if exists public.setup_together_member(text, text, text);
drop function if exists public.is_couple_member(uuid);
drop function if exists public.is_self_couple_member(uuid, uuid);
drop function if exists public.is_uuid(text);

create or replace function public.get_pairing_state()
returns table(
  result_status text,
  result_couple_id uuid,
  result_created_by uuid,
  result_member_count integer,
  result_partner_display_name text,
  result_invite_code text,
  result_invite_expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  membership public.couple_members%rowtype;
  couple_row public.couples%rowtype;
  member_total integer;
  partner_name text;
  invite_row public.pair_invites%rowtype;
begin
  if caller_id is null then
    raise exception using errcode = '28000', message = 'authentication_required';
  end if;

  select cm.* into membership
  from public.couple_members cm
  where cm.user_id = caller_id;

  if not found then
    return query select 'unpaired', null::uuid, null::uuid, 0,
      null::text, null::text, null::timestamptz;
    return;
  end if;

  select c.* into couple_row from public.couples c where c.id = membership.couple_id;
  select count(*)::integer into member_total
  from public.couple_members cm where cm.couple_id = membership.couple_id;

  select p.display_name into partner_name
  from public.couple_members cm
  left join public.profiles p on p.id = cm.user_id
  where cm.couple_id = membership.couple_id and cm.user_id <> caller_id
  order by cm.joined_at
  limit 1;

  if couple_row.created_by = caller_id and couple_row.status = 'pending' then
    select pi.* into invite_row
    from public.pair_invites pi
    where pi.couple_id = membership.couple_id
      and pi.consumed_at is null
      and pi.revoked_at is null
      and pi.expires_at > now()
    order by pi.created_at desc
    limit 1;
  end if;

  return query select
    case when couple_row.status = 'active' and member_total = 2 then 'paired' else 'pending' end,
    membership.couple_id,
    couple_row.created_by,
    member_total,
    coalesce(partner_name, 'Your partner'),
    invite_row.code,
    invite_row.expires_at;
end;
$$;

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
      or not exists (
        select 1 from public.couple_members cm
        where cm.couple_id = caller_couple_id and cm.user_id = caller_id
      ) then
      return query select 'already_paired', caller_couple_id, null::text, null::timestamptz;
      return;
    end if;

    if couple_row.created_by <> caller_id then
      return query select 'already_paired', caller_couple_id, null::text, null::timestamptz;
      return;
    end if;

    if not p_regenerate then
      select pi.* into invite_row
      from public.pair_invites pi
      where pi.couple_id = caller_couple_id
        and pi.consumed_at is null
        and pi.revoked_at is null
        and pi.expires_at > now()
      order by pi.created_at desc
      limit 1;

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
    select caller_id,
      coalesce(nullif(split_part(au.email, '@', 1), ''), 'Partner'),
      null
    from auth.users au where au.id = caller_id
    on conflict (id) do nothing;

    insert into public.couple_members(couple_id, user_id, role)
    values (caller_couple_id, caller_id, null);
  end if;

  update public.pair_invites pi
  set revoked_at = now()
  where pi.couple_id = caller_couple_id
    and pi.consumed_at is null
    and pi.revoked_at is null;

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
    coalesce(nullif(split_part(au.email, '@', 1), ''), 'Partner'),
    null
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

create or replace function public.revoke_pair_invite()
returns table(result_status text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  caller_couple_id uuid;
begin
  if caller_id is null then
    raise exception using errcode = '28000', message = 'authentication_required';
  end if;

  select c.id into caller_couple_id
  from public.couples c
  join public.couple_members cm on cm.couple_id = c.id
  where cm.user_id = caller_id and c.created_by = caller_id and c.status = 'pending'
  for update of c;

  if caller_couple_id is null then
    return query select 'no_pending_invite';
    return;
  end if;

  update public.pair_invites pi set revoked_at = now()
  where pi.couple_id = caller_couple_id
    and pi.consumed_at is null and pi.revoked_at is null;
  return query select 'invite_revoked';
end;
$$;

create or replace function public.unpair_current_couple()
returns table(result_status text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  caller_couple_id uuid;
begin
  if caller_id is null then
    raise exception using errcode = '28000', message = 'authentication_required';
  end if;

  select cm.couple_id into caller_couple_id
  from public.couple_members cm where cm.user_id = caller_id;
  if caller_couple_id is null then
    return query select 'not_paired';
    return;
  end if;

  perform 1 from public.couples c where c.id = caller_couple_id for update;
  update public.pair_invites set revoked_at = coalesce(revoked_at, now())
    where couple_id = caller_couple_id and consumed_at is null;
  delete from public.current_partner_photos where couple_id = caller_couple_id;
  delete from public.locations where couple_id = caller_couple_id;
  delete from public.couple_members where couple_id = caller_couple_id;
  update public.couples set status = 'dissolved', pair_code = null
    where id = caller_couple_id;

  return query select 'unpaired';
end;
$$;

create or replace function public.publish_current_partner_photo(
  p_photo_id uuid,
  p_storage_path text
)
returns table(result_status text, result_previous_storage_path text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  caller_couple_id uuid;
  path_parts text[];
  previous_path text;
begin
  if caller_id is null then
    raise exception using errcode = '28000', message = 'authentication_required';
  end if;

  select cm.couple_id into caller_couple_id
  from public.couple_members cm where cm.user_id = caller_id;
  if caller_couple_id is null then
    return query select 'not_paired', null::text;
    return;
  end if;

  path_parts := string_to_array(p_storage_path, '/');
  if array_length(path_parts, 1) <> 3
    or path_parts[1]::uuid <> caller_couple_id
    or path_parts[2]::uuid <> caller_id
    or lower(path_parts[3]) <> lower(p_photo_id::text || '.jpg') then
    return query select 'invalid_photo_path', null::text;
    return;
  end if;

  if not exists (
    select 1 from storage.objects so
    where so.bucket_id = 'partner-photos' and so.name = p_storage_path
  ) then
    return query select 'missing_upload', null::text;
    return;
  end if;

  select cpp.storage_path into previous_path
  from public.current_partner_photos cpp
  where cpp.couple_id = caller_couple_id and cpp.sender_user_id = caller_id
  for update;

  insert into public.current_partner_photos(
    couple_id, sender_user_id, photo_id, storage_path, updated_at
  ) values (
    caller_couple_id, caller_id, p_photo_id, p_storage_path, now()
  )
  on conflict (couple_id, sender_user_id) do update set
    photo_id = excluded.photo_id,
    storage_path = excluded.storage_path,
    updated_at = excluded.updated_at;

  return query select 'published', previous_path;
exception
  when invalid_text_representation then
    return query select 'invalid_photo_path', null::text;
end;
$$;

revoke all on public.pair_invites from anon, authenticated;
revoke all on public.current_partner_photos from anon, authenticated;
revoke all on public.couples from anon, authenticated;
revoke all on public.couple_members from anon, authenticated;
revoke all on public.profiles from anon, authenticated;
revoke all on public.locations from anon, authenticated;
revoke all on public.photos from anon, authenticated;
revoke all on public.messages from anon, authenticated;

grant select on public.couples, public.couple_members to authenticated;
grant select on public.profiles to authenticated;
grant update(display_name) on public.profiles to authenticated;
grant select, insert, update on public.locations to authenticated;
grant select on public.current_partner_photos to authenticated;
grant select on public.photos, public.messages to authenticated;

revoke execute on all functions in schema private from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.is_couple_member(uuid) to authenticated;
grant execute on function private.is_self_couple_member(uuid, uuid) to authenticated;
grant execute on function private.try_uuid(text) to authenticated;
grant execute on function private.is_current_partner_photo(text) to authenticated;
revoke execute on function public.get_pairing_state() from public, anon;
revoke execute on function public.create_pair_invite(boolean) from public, anon;
revoke execute on function public.join_pair_invite(text) from public, anon;
revoke execute on function public.revoke_pair_invite() from public, anon;
revoke execute on function public.unpair_current_couple() from public, anon;
revoke execute on function public.publish_current_partner_photo(uuid, text) from public, anon;

grant execute on function public.get_pairing_state() to authenticated;
grant execute on function public.create_pair_invite(boolean) to authenticated;
grant execute on function public.join_pair_invite(text) to authenticated;
grant execute on function public.revoke_pair_invite() to authenticated;
grant execute on function public.unpair_current_couple() to authenticated;
grant execute on function public.publish_current_partner_photo(uuid, text) to authenticated;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values (
  'partner-photos', 'partner-photos', false, 5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
