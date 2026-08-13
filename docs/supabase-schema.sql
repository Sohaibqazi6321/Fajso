-- LEGACY BASELINE ONLY
--
-- Together V1 is defined by all files in supabase/migrations, applied in
-- filename order. The first file bootstraps or upgrades this legacy baseline.
--
-- Do not use this legacy role/permanent-code schema for a new deployment. It is
-- retained only to document the pre-V1 database that the V1 migration upgrades.
-- Never paste service_role or secret keys into the iOS app.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  role text not null check (role in ('sohaib', 'fajr')),
  created_at timestamptz not null default now()
);

create table if not exists public.couples (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Sohaib + Fajr',
  pair_code text unique,
  created_at timestamptz not null default now()
);

create table if not exists public.couple_members (
  couple_id uuid not null references public.couples(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('sohaib', 'fajr')),
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

alter table public.photos add column if not exists receiver_saved_at timestamptz;
alter table public.photos add column if not exists storage_deleted_at timestamptz;

create index if not exists couple_members_user_id_idx on public.couple_members(user_id);
create index if not exists locations_couple_id_updated_at_idx on public.locations(couple_id, updated_at desc);
create index if not exists messages_couple_id_created_at_idx on public.messages(couple_id, created_at desc);
create index if not exists photos_couple_id_created_at_idx on public.photos(couple_id, created_at desc);

alter table public.profiles enable row level security;
alter table public.couples enable row level security;
alter table public.couple_members enable row level security;
alter table public.locations enable row level security;
alter table public.messages enable row level security;
alter table public.photos enable row level security;

create or replace function public.is_couple_member(target_couple_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.couple_members
    where couple_id = target_couple_id
      and user_id = auth.uid()
  );
$$;

create or replace function public.is_self_couple_member(target_couple_id uuid, target_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.couple_members
    where couple_id = target_couple_id
      and user_id = target_user_id
      and user_id = auth.uid()
  );
$$;

create or replace function public.is_uuid(value text)
returns boolean
language sql
immutable
as $$
  select value ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
$$;

create or replace function public.setup_together_member(
  selected_role text,
  selected_display_name text,
  selected_pair_code text
)
returns table(result_couple_id uuid, result_user_id uuid, result_role text)
language plpgsql
security definer
set search_path = public
as $$
declare
  target_couple_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required.';
  end if;

  if selected_role not in ('sohaib', 'fajr') then
    raise exception 'Invalid role.';
  end if;

  insert into public.couples (name, pair_code)
  values ('Sohaib + Fajr', selected_pair_code)
  on conflict (pair_code) do update set name = excluded.name
  returning id into target_couple_id;

  insert into public.profiles (id, display_name, role)
  values (auth.uid(), selected_display_name, selected_role)
  on conflict (id) do update set
    display_name = excluded.display_name,
    role = excluded.role;

  insert into public.couple_members (couple_id, user_id, role)
  values (target_couple_id, auth.uid(), selected_role)
  on conflict (user_id) do update set
    couple_id = excluded.couple_id,
    role = excluded.role;

  return query
  select target_couple_id, auth.uid(), selected_role;
end;
$$;

drop policy if exists "Users can insert their profile" on public.profiles;
create policy "Users can insert their profile"
on public.profiles for insert
with check (id = auth.uid());

drop policy if exists "Users can view their profile and partner profile" on public.profiles;
create policy "Users can view their profile and partner profile"
on public.profiles for select
using (
  id = auth.uid()
  or exists (
    select 1
    from public.couple_members mine
    join public.couple_members theirs on theirs.couple_id = mine.couple_id
    where mine.user_id = auth.uid()
      and theirs.user_id = profiles.id
  )
);

drop policy if exists "Users can update their profile" on public.profiles;
create policy "Users can update their profile"
on public.profiles for update
using (id = auth.uid())
with check (id = auth.uid());

drop policy if exists "Authenticated users can create a couple" on public.couples;
create policy "Authenticated users can create a couple"
on public.couples for insert
to authenticated
with check (true);

drop policy if exists "Couple members can view their couple" on public.couples;
create policy "Couple members can view their couple"
on public.couples for select
using (public.is_couple_member(id));

drop policy if exists "Couple members can view memberships" on public.couple_members;
create policy "Couple members can view memberships"
on public.couple_members for select
using (public.is_couple_member(couple_id) or user_id = auth.uid());

drop policy if exists "Users can join as themselves" on public.couple_members;
create policy "Users can join as themselves"
on public.couple_members for insert
with check (user_id = auth.uid());

drop policy if exists "Couple members can view locations" on public.locations;
create policy "Couple members can view locations"
on public.locations for select
using (public.is_couple_member(couple_id));

drop policy if exists "Users can insert their location" on public.locations;
create policy "Users can insert their location"
on public.locations for insert
with check (public.is_self_couple_member(couple_id, user_id));

drop policy if exists "Users can update their location" on public.locations;
create policy "Users can update their location"
on public.locations for update
using (public.is_self_couple_member(couple_id, user_id))
with check (public.is_self_couple_member(couple_id, user_id));

drop policy if exists "Couple members can view messages" on public.messages;
create policy "Couple members can view messages"
on public.messages for select
using (public.is_couple_member(couple_id));

drop policy if exists "Couple members can send their messages" on public.messages;
create policy "Couple members can send their messages"
on public.messages for insert
with check (public.is_self_couple_member(couple_id, sender_user_id));

drop policy if exists "Couple members can view photos" on public.photos;
create policy "Couple members can view photos"
on public.photos for select
using (public.is_couple_member(couple_id));

drop policy if exists "Couple members can add their photos" on public.photos;
create policy "Couple members can add their photos"
on public.photos for insert
with check (public.is_self_couple_member(couple_id, sender_user_id));

drop policy if exists "Couple members can update photo transfer state" on public.photos;
create policy "Couple members can update photo transfer state"
on public.photos for update
using (public.is_couple_member(couple_id))
with check (public.is_couple_member(couple_id));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'partner-photos',
  'partner-photos',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Couple members can view partner photos" on storage.objects;
create policy "Couple members can view partner photos"
on storage.objects for select
to authenticated
using (
  bucket_id = 'partner-photos'
  and public.is_uuid((storage.foldername(name))[1])
  and public.is_couple_member((storage.foldername(name))[1]::uuid)
);

drop policy if exists "Users can upload their partner photos" on storage.objects;
create policy "Users can upload their partner photos"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'partner-photos'
  and public.is_uuid((storage.foldername(name))[1])
  and public.is_uuid((storage.foldername(name))[2])
  and public.is_couple_member((storage.foldername(name))[1]::uuid)
  and (storage.foldername(name))[2]::uuid = auth.uid()
);

drop policy if exists "Users can update their partner photos" on storage.objects;
create policy "Users can update their partner photos"
on storage.objects for update
to authenticated
using (
  bucket_id = 'partner-photos'
  and public.is_uuid((storage.foldername(name))[1])
  and public.is_uuid((storage.foldername(name))[2])
  and public.is_couple_member((storage.foldername(name))[1]::uuid)
  and (storage.foldername(name))[2]::uuid = auth.uid()
)
with check (
  bucket_id = 'partner-photos'
  and public.is_uuid((storage.foldername(name))[1])
  and public.is_uuid((storage.foldername(name))[2])
  and public.is_couple_member((storage.foldername(name))[1]::uuid)
  and (storage.foldername(name))[2]::uuid = auth.uid()
);

drop policy if exists "Couple members can delete transferred partner photos" on storage.objects;
create policy "Couple members can delete transferred partner photos"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'partner-photos'
  and public.is_uuid((storage.foldername(name))[1])
  and public.is_couple_member((storage.foldername(name))[1]::uuid)
);

grant select, insert, update on public.profiles to authenticated;
grant select, insert on public.couples to authenticated;
grant select, insert on public.couple_members to authenticated;
grant select, insert, update on public.locations to authenticated;
grant select, insert on public.messages to authenticated;
grant select, insert, update on public.photos to authenticated;
grant execute on function public.is_couple_member(uuid) to authenticated;
grant execute on function public.is_self_couple_member(uuid, uuid) to authenticated;
grant execute on function public.is_uuid(text) to authenticated;
grant execute on function public.setup_together_member(text, text, text) to authenticated;
