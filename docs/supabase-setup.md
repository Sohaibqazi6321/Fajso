# Supabase Setup

Together uses Supabase for authentication, invitation pairing, current locations,
and private current partner photos. Widgets never connect to Supabase; the app
writes sanitized display state into the App Group cache.

## 1. Create Project

1. Create a Supabase project.
2. In `Project Settings -> API`, copy:
   - Project URL
   - Publishable key
3. Do not copy the `service_role` key into the iOS app or GitHub.

Supabase's Swift client initializes with the Project URL and publishable key. Supabase documents that frontend apps should use the publishable key with Row Level Security enabled, and that service role or secret keys must not be exposed.

## 2. Apply the Versioned Schema

Apply every SQL file in [`supabase/migrations`](../supabase/migrations/) in
filename order through the Supabase CLI migration workflow or the Supabase
migration tool. The first migration bootstraps a new project or upgrades the
legacy database; later migrations are required hardening and recovery changes.
Do not cherry-pick only the first file, and do not rerun the legacy
`supabase-schema.sql` setup.

After applying it, confirm these tables exist:
   - `profiles`
   - `couples`
   - `couple_members`
   - `pair_invites`
   - `locations`
   - `messages`
   - `photos`
   - `current_partner_photos`

Confirm Storage has a private bucket named `partner-photos`. The `messages` and
legacy `photos` tables remain unused in V1 for safe compatibility; they are not
product features.

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

Authentication and pairing are separate. After signing in:

1. Sohaib chooses **Invite Partner**.
2. Together creates a random invitation that expires after 72 hours.
3. Sohaib copies or shares the code.
4. Fajr signs in and chooses **Join Partner**.
5. Fajr enters the invitation code once.

The `join_pair_invite` RPC performs validation, membership insertion, invite
consumption, and activation atomically. Direct client writes cannot create or
move memberships. A user can belong to only one couple and each couple is capped
at two members by both serialized RPC logic and a database trigger.

Do not seed memberships directly. Regenerate or revoke a pending invitation from
the app when a code is lost or expires.

## 6. Sohaib-only Developer Distance

The iOS build contains Sohaib's immutable Supabase Auth user ID as a non-secret
build configuration value. Only that authenticated account sees Developer Mode.
Its distance override is stored locally, is scoped to that account, and changes
the same App Group presentation used by the real Distance Widget. It never writes
coordinates or test distance data to Supabase. Disable it to return immediately
to the real relationship state. Sohaib can enable it while unpaired or while an
invite is pending, which allows the production Distance Widget rendering path to
be verified before Fajr installs Together.

## 7. Live Distance Requirements

Live distance works after:

1. Sohaib and Fajr both sign in.
2. Both auth users are present in `couple_members`.
3. Each phone grants location permission.
4. Each phone opens Together with location permission or uses manual refresh at
   least once.

The app uploads only the current user's own latest location row. It reads the two
current rows, calculates distance on device, and writes only the distance and its
source freshness to the App Group cache. Exact coordinates never enter widget
state.

For battery efficiency, the app uses:

- one-shot location requests at launch, when the app becomes active, and on
  manual refresh
- foreground-only When In Use authorization in V1
- cached widget rendering instead of direct widget network calls

Together does not claim continuous or navigation-grade background tracking.
An explicit opt-in Always/background mode can be added later if two-device
testing shows that foreground refreshes are insufficient.

## 8. Current Partner Photo

The native iOS app now includes the first real Partner Photo sync path:

1. Open `Partner Photo` from the app, or tap the Partner Photo widget.
2. Choose `Take Picture` or `Upload Photo`.
3. The app resizes and compresses the image to JPEG.
4. The app uploads an immutable private object to:

```text
partner-photos/{couple_id}/{user_id}/{photo_id}.jpg
```

5. The authoritative `publish_current_partner_photo` RPC swaps only the sender's
   current pointer.
6. The partner's app downloads and validates that current image.
7. A staged App Group file replaces the old cache only after the new image is
   complete and decodable.
8. The Photo Widget reloads and reads only that local file.

The previous cached image stays visible through offline or failed-download
states. After a successful replacement, the sender removes the superseded
remote object. Unpairing immediately revokes access and clears local caches;
inaccessible orphan objects should be removed by a privileged scheduled
retention job because client RLS intentionally cannot delete a partner's file.
V1 does not expose photo history.

Widgets do not call Supabase directly. The Partner Photo widget reads the
locally cached App Group image first, then shows a friendly placeholder when no
partner photo has synced.
