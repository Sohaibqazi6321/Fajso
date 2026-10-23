# Fajso 💛

A private iPhone app for Sohaib & Fajr: how far apart you are, on the Lock Screen, and each other's latest photo, on the Home Screen.

Built on Windows with no Mac and no paid accounts:

1. Write Swift on Windows.
2. GitHub Actions (macOS) builds `Fajso.ipa`. Go to **Actions → iOS build → Run workflow**, then download the `Fajso-ipa` artifact.
3. Sideload the IPA with Sideloadly or AltStore using a free Apple ID, and refresh it every 7 days.

Pure logic in `Shared/Core` is tested with `swift test`, on Linux CI or on Windows with the Swift toolchain.

Design docs, roadmap and decisions live in the Obsidian vault (`OneDrive/Documents/Fajso`). Notes for coding agents are in [CLAUDE.md](CLAUDE.md).

## Status: Phase 0 (prove the pipeline)
Install the build on both phones, add both widgets, then open **Diagnostics** in the app:
- **App Group: Available** plus **Widget wrote: ✓** means app ↔ widget sharing works on free signing.
- **Widget network: OK** means widgets can fetch from Supabase by themselves.

The widgets show the same results as `AG ✓/✗` and `NET ✓/✗`.

The backend schema (`supabase/migrations`) comes from the earlier "Together" prototype and is already deployed.
