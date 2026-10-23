-- Concurrent app refreshes must not let an older CLLocation overwrite a newer
-- captured position.
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

revoke execute on function private.prevent_stale_location_update()
from public, anon, authenticated;
