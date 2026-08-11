# Xcode Setup

These steps are for your friend's Mac. If XcodeGen is available, prefer [windows-first-workflow.md](windows-first-workflow.md), because it generates the target structure from `project.yml`.

## 1. Create the App Project

1. Open Xcode.
2. Choose `File > New > Project`.
3. Select `iOS > App`.
4. Product Name: `Together`
5. Interface: `SwiftUI`
6. Language: `Swift`
7. Minimum iOS: iOS 17 or newer is recommended.
8. Save the project in this repo.

## 2. Add the Widget Extension

1. Choose `File > New > Target`.
2. Select `Widget Extension`.
3. Product Name: `TogetherWidgets`
4. Do not create a separate extension for each widget.
5. Keep both widgets in the same WidgetKit extension.

The final app should look roughly like:

```text
Together.app
  Together
  PlugIns/
    TogetherWidgets.appex
```

## 3. Add These Source Files

Copy or drag the files from `ios/` into the matching Xcode targets:

- `ios/Together/TogetherApp.swift` -> Together app target
- `ios/Together/ContentView.swift` -> Together app target
- `ios/Shared/TogetherShared.swift` -> both app and widget targets
- `ios/TogetherWidgets/TogetherWidgetsBundle.swift` -> widget target
- `ios/TogetherWidgets/DistanceWidget.swift` -> widget target
- `ios/TogetherWidgets/PartnerPhotoWidget.swift` -> widget target

## 4. Configure Signing

1. In Xcode, open project settings.
2. Select the Together app target.
3. Set Team to the free Apple account.
4. Use a unique bundle id, for example `com.sohaib.together`.
5. Select the TogetherWidgets extension target.
6. Set Team to the same free Apple account.
7. Use a matching extension bundle id, for example `com.sohaib.together.widgets`.

## 5. App Group Test

Try enabling App Groups for both targets:

```text
group.com.sohaib.together
```

If Xcode refuses App Groups with the free account, leave App Groups disabled for Phase 1 and record that result. The widget rendering test can still continue, but the final app may need a different shared-cache strategy or a paid developer account later.

## 6. Build and Sideload

1. Build once in Xcode.
2. Export or locate the built app for SideStore packaging.
3. Install through SideStore.
4. Run the checklist in [Phase 1 sideloading test](phase-1-sideloading.md).
