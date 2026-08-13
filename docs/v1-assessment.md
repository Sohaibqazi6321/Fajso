# Together V1 Repository Assessment

Assessment date: 2026-08-13

## Confirmed architecture

- `project.yml` is the canonical XcodeGen definition for one SwiftUI app and one
  WidgetKit extension.
- `ios/Shared` is compiled into both targets.
- Supabase access exists only in the app. Widgets read App Group state and a
  locally cached photo.
- The backend stores one current location row per couple member and uses a
  private `partner-photos` bucket.
- GitHub Actions regenerates the Xcode project and builds the app and embedded
  widget extension on macOS. Windows source inspection and the browser preview
  are not native verification.

## Requirement status before V1 work

| Area | Assessment | Evidence summary |
| --- | --- | --- |
| Authentication | Partially complete | Email magic link and deep-link handling existed, but signed-out, loading, unpaired, and paired state were not modeled separately. |
| Pairing | Implemented incorrectly | The app used self-selected Sohaib/Fajr roles and a committed permanent code. The RPC could move an existing member and direct REST inserts could bypass it. |
| Pairing failure | Confirmed root cause | The deployed RPC returned `user_id` as a PL/pgSQL output variable, which conflicted with `ON CONFLICT (user_id)`. The deployed function had not been dropped/recreated with the repository's renamed result columns. |
| Two-person authorization | Partially complete | `unique(user_id)` and role uniqueness limited ordinary inserts, but there was no atomic invite, invite consumption, or serialized two-seat join. |
| Location ownership | Mostly complete | RLS limited location writes to the authenticated member, and the table held one row per member. Freshness and offline display semantics were incorrect or missing. |
| Distance cache/widget | Partially complete | App-to-App-Group-to-widget flow existed, but missing data displayed a demo distance and the timestamp described local calculation time rather than the older source location. |
| Developer mode | Missing | No immutable-account gate or local test-distance override existed. |
| Partner photo | Partially complete | Private upload/download and local cache existed, but the model was transfer history, metadata updates/deletes were overly broad, and fallback content could look like a real photo. |
| Cache cleanup | Partially complete | Photo writes were atomic, but there was no single versioned relationship state or complete sign-out/unpair cleanup. |
| UI | Obsolete | The main screen was a dark proof-of-concept exposing backend and demo controls. |
| Messages | Obsolete for V1 | Schema/model existed but no native product behavior used it. Retaining it unused is safer than destructive removal. |
| Automated tests | Missing | No XCTest or database integration tests existed. |
| Native verification | Available but not yet run | `.github/workflows/ios-build.yml` is the authoritative macOS build route. |

## V1 sequencing

1. Replace role/code setup with atomic, expiring invitation RPCs and remove
   direct membership writes.
2. Tighten table, function, and Storage authorization.
3. Introduce a versioned App Group state with explicit relationship, freshness,
   offline, and missing states.
4. Correct current-location synchronization and distance freshness.
5. Add an immutable-user-ID-gated, local-only developer distance override.
6. Publish one current photo per sender and safely stage partner cache updates.
7. Replace proof-of-concept app/widget UI with the focused light lavender V1.
8. Run database assertions/advisors, independent security/test/code review, and
   native GitHub Actions verification.
