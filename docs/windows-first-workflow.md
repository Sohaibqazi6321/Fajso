# Windows-First Workflow

Use this repo on the Windows laptop as the source of truth. Use the Mac only when Xcode is required.

## On Windows

1. Edit Swift files, docs, and future backend plans here.
2. Keep the repo folder synced with the Mac using Git, OneDrive, USB, or a zip file.
3. Do not expect Windows to compile the real iPhone app or WidgetKit extension.

## On the Mac

1. Install Xcode from the Mac App Store.
2. Optional but recommended: install XcodeGen with Homebrew:

```bash
brew install xcodegen
```

3. Open Terminal in this repo and run:

```bash
xcodegen generate
open Together.xcodeproj
```

4. In Xcode, select the Together project and set the signing team for both targets.
5. Build and run on a plugged-in iPhone once before trying SideStore.

## If XcodeGen Is Not Installed

Create the Xcode project manually using [xcode-setup.md](xcode-setup.md). The `project.yml` file still documents the intended target structure:

- `Together`: app target
- `TogetherWidgets`: one WidgetKit extension target
- `ios/Shared`: included in both targets

## App Group Toggle

The default `project.yml` does not enable App Group entitlements automatically, because free Apple signing may reject them.

After the basic app and widgets build:

1. Try enabling App Groups on both targets in Xcode.
2. Use `group.com.sohaib.together`.
3. If Xcode accepts it, set each target's entitlements file:
   - App: `ios/Together/Together.entitlements`
   - Widget extension: `ios/TogetherWidgets/TogetherWidgets.entitlements`
4. Rebuild and use the app's `Write Demo Cache` button.
5. If Xcode rejects it, keep Phase 1 focused on proving sideloaded widgets render.

