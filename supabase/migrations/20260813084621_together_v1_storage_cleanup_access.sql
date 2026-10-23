-- Supabase Storage deletion also evaluates SELECT visibility. Keep superseded
-- objects private from the partner while allowing the sender to remove their
-- own orphaned upload during the active relationship.
drop policy if exists "Current members can view partner photos" on storage.objects;
create policy "Current members can view partner photos"
on storage.objects for select to authenticated
using (
  bucket_id = 'partner-photos'
  and (
    (select private.is_current_partner_photo(name))
    or (select private.is_self_couple_member(
      private.try_uuid((storage.foldername(name))[1]),
      private.try_uuid((storage.foldername(name))[2])
    ))
  )
);
