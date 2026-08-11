# Supabase Setup

Use Supabase for the real synced version: accounts, pair membership, locations, messages, and partner photos.

## 1. Create Project

1. Create a Supabase project.
2. In `Project Settings -> API`, copy:
   - Project URL
   - Publishable key
3. Do not copy the `service_role` key into the iOS app or GitHub.

Supabase's Swift client initializes with the Project URL and publishable key. Supabase documents that frontend apps should use the publishable key with Row Level Security enabled, and that service role or secret keys must not be exposed.

## 2. Run Schema

1. Open Supabase SQL Editor.
2. Paste and run [supabase-schema.sql](supabase-schema.sql). Run it again after pulling the photo-sync changes so the new photo transfer fields, update policy, and storage delete policy are present.
3. Confirm these tables exist:
   - `profiles`
   - `couples`
   - `couple_members`
   - `locations`
   - `messages`
   - `photos`
4. Confirm Storage has a private bucket named `partner-photos`.

The schema enables RLS on app tables. For files, photo uploads use this storage path shape:

```text
partner-photos/{couple_id}/{user_id}/{photo_id}.jpg
```

## 3. Auth Choice

For just Sohaib and Fajr, start with Supabase email OTP / magic link:

- Sohaib signs in with his email.
- Fajr signs in with her email.
- The app links both users into one couple using a private pair code.

Phone OTP is possible later, but email OTP is easier to start with.

In Supabase Auth settings, add this redirect URL before testing magic links on iPhone:

```text
together://auth-callback
```

The iOS app registers the `together://` URL scheme and sends magic links with that redirect URL.

## 4. Local iOS Config

The repo now includes Supabase keys in `ios/Together/Info.plist`:

```text
SUPABASE_URL = https://lwiedqlmzddwxhivubfa.supabase.co
SUPABASE_PUBLISHABLE_KEY = sb_publishable_...
```

Safe to commit:

- Project URL, if you want convenience
- Publishable key, if RLS is correct

Never commit:

- service role key
- database password
- JWT secret
- personal email OTP links

## 5. Pair Sohaib and Fajr

The app now includes a pair-code setup path after sign-in:

1. Sohaib signs in with email.
2. Sohaib enters `SOHAIB-FAJR-2026`.
3. Sohaib taps `I am Sohaib`.
4. Fajr signs in with email.
5. Fajr enters `SOHAIB-FAJR-2026`.
6. Fajr taps `I am Fajr`.

That calls `setup_together_member`, which creates or joins the couple, creates the profile, and inserts the membership row.

You can still seed manually if needed:

```sql
insert into public.couples (id, name, pair_code)
values ('00000000-0000-0000-0000-000000000001', 'Sohaib + Fajr', 'SOHAIB-FAJR-2026');

insert into public.couple_members (couple_id, user_id, role)
values
  ('00000000-0000-0000-0000-000000000001', 'SOHAIB_AUTH_USER_ID', 'sohaib'),
  ('00000000-0000-0000-0000-000000000001', 'FAJR_AUTH_USER_ID', 'fajr');
```

Replace the placeholder UUIDs with real auth user IDs.

## 6. App Work Next

Next implementation steps:

1. Add sign-in screen with email OTP.
2. Add "I am Sohaib / I am Fajr" setup.
3. Add pair-code join screen.
4. Sync location rows.
5. Sync messages.
6. Upload selected/taken photos to `partner-photos`.
7. Save the latest synced distance/photo/message into App Group cache for widgets.

## 7. Live Distance Requirements

Live distance works after:

1. Sohaib and Fajr both sign in.
2. Both auth users are present in `couple_members`.
3. Each phone grants location permission.
4. Each phone taps `Sync Now` at least once.

The app uploads only the current user's own location row. It then reads both rows, calculates distance on device, and writes the latest distance into App Group cache for the widgets.

For battery efficiency, the app uses:

- one-shot location requests for manual refresh
- `startMonitoringSignificantLocationChanges()` for background-friendly updates
- a 500 meter distance filter
- cached widget rendering instead of direct widget network calls

## 8. Photo Sync Requirements

The native iOS app now includes the first real Partner Photo sync path:

1. Open `Partner Photo` from the app, or tap the Partner Photo widget.
2. Choose `Take Picture` or `Upload Photo`.
3. The app compresses the image to JPEG.
4. The app uploads the temporary transfer file to:

```text
partner-photos/{couple_id}/{user_id}/{photo_id}.jpg
```

5. The app inserts a lightweight row in `photos`.
6. The partner opens the app/photo screen or taps `Refresh`.
7. The partner downloads the latest photo where `sender_user_id` is not their own user id.
8. The app caches that image in App Group storage so the widget can show it locally.
9. The app asks for Photos add permission and saves the received photo to the iPhone Photos app once.
10. The app marks `receiver_saved_at` after the save succeeds.
11. Cleanup deletes the temporary Supabase Storage file after `receiver_saved_at` is at least 24 hours old, then marks `storage_deleted_at`.

The `photos` database row stays as small history/metadata. The full image is meant to live permanently on the receiver's iPhone after it is saved to Photos, not in Supabase.

Widgets do not call Supabase directly. The Partner Photo widget reads the locally cached App Group image first, then falls back to the bundled test image.
