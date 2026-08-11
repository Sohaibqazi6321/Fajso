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
2. Paste and run [supabase-schema.sql](supabase-schema.sql). Sohaib ran this already.
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

## 4. Local iOS Config

The repo now includes placeholder keys in `ios/Together/Info.plist`:

```text
SUPABASE_URL = YOUR_SUPABASE_URL
SUPABASE_PUBLISHABLE_KEY = YOUR_SUPABASE_PUBLISHABLE_KEY
```

Before a real synced build, replace those placeholders locally in Xcode or with a local `.xcconfig` file that is not committed.

Safe to commit:

- Project URL, if you want convenience
- Publishable key, if RLS is correct

Never commit:

- service role key
- database password
- JWT secret
- personal email OTP links

## 5. First Manual Seed

For the first real test, do this manually in Supabase after both accounts have logged in once:

1. Find Sohaib's auth user ID in Supabase Auth.
2. Find Fajr's auth user ID.
3. Insert one row in `couples`.
4. Insert two rows in `couple_members`.
5. Insert two rows in `profiles`.

Example values:

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
