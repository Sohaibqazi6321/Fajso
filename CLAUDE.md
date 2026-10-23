# Fajso: instructions for Claude Code

Fajso is a private iOS app for two people (Sohaib & Fajr): a Lock Screen distance widget, a Home Screen shared-photo widget, and a warm app around them that grows feature by feature.

**Design docs live in the Obsidian vault at `C:\Users\sohai\OneDrive\Documents\Fajso`.** Read `00 Fajso Home.md` there first. Keep the vault up to date: tick items in `10 Roadmap.md`, and append decisions to `11 Decision Log.md`.

## Hard constraints
- **No Mac.** Development happens on Windows. Native builds run only on GitHub Actions (`.github/workflows/ios-build.yml`). Never claim a native build works based on reading the code; say it is unverified until CI passes.
- **$0.** Free Apple IDs plus sideloading (Sideloadly/AltStore), Supabase free tier. Flag anything that needs the paid Apple Developer Program (push notifications, TestFlight, Sign in with Apple, CloudKit, WeatherKit).
- **CI minutes are scarce:** about 200 macOS minutes a month. The iOS workflow is manual (`workflow_dispatch`) or runs on `v*` tags. Don't make it run on every push.

## Layout
- `project.yml`: XcodeGen definition and the source of truth. `Fajso.xcodeproj`, the Info.plists and the entitlements are generated, so edit `project.yml` instead.
- `Config/Fajso.xcconfig`: Supabase host, publishable key, App Group ID.
- `App/`: entry point and Home screen.
- `Core/DesignSystem/`: colour/type tokens and components. Also compiled into the widget.
- `Core/Feature/`: the `FajsoFeature` protocol and `FeatureRegistry`. New features register here.
- `Features/<Name>/`: one folder per feature.
- `Shared/`: code compiled into both the app and the widget.
- `Shared/Core/`: Foundation-only logic, also built by `Package.swift` and tested on Linux CI with `swift test`. Keep it free of UIKit, SwiftUI and CoreLocation.
- `Widgets/`: WidgetKit extension.
- `supabase/migrations/`: SQL already applied to project `lwiedqlmzddwxhivubfa`. Never edit an applied migration; add a new timestamped file.

## Rules
- Widgets fetch from Supabase themselves on their timeline (the app may also be closed). The App Group is a cache, not the only data path.
- Put pure logic in `Shared/Core` and add tests in `Tests/FajsoCoreTests`.
- Use the colours, fonts and components from `Core/DesignSystem`. Don't add ad-hoc colours.
- Never commit the Supabase `service_role` key. The publishable key in `Config/` is meant to be public; RLS protects the data.
- Use the supabase skills in `.claude/skills/` for any migration or RLS change.
