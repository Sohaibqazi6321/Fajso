# Phase 1 Sideloading Test

## Goal

Prove that Together can be installed privately on Sohaib's and Fajr's iPhones using free development signing and SideStore before building the full backend, location, camera, or photo-sync systems.

## Build Contents

The Phase 1 app contains:

- A minimal SwiftUI app named Together.
- One WidgetKit extension named TogetherWidgets.
- Two widget kinds inside that single extension:
  - Distance Widget for Home Screen and Lock Screen
  - Partner Photo Widget

The widgets use hardcoded demo data:

- Distance: `Sohaib + Fajr`, `7,846 mi apart`
- Partner photo: a bundled valid PNG test image with a small `Together` overlay

## SideStore Test Order

Before using a free Apple ID or SideStore slot, open `preview/together-preview.html` on Windows and test:

- Sohaib view and Fajr view
- Distance changes when either person's coordinates change
- Browser location button, if permission is available
- Small message sending
- Partner photo selection from the app controls
- Tapping the photo widget to open the larger photo view
- Take Picture and Upload Photo controls inside the larger photo view
- Home Screen and Lock Screen widget previews

Test on Sohaib's iPhone first.

1. Build Together on the Mac in Xcode.
2. Create a signed app/IPA for development use.
3. Install through SideStore.
4. Launch Together.
5. Confirm the Distance Widget appears in the iOS widget picker.
6. Confirm the Partner Photo Widget appears in the iOS widget picker.
7. Place both widgets on the Home Screen.
8. Add the Distance Widget to the Lock Screen.
9. Confirm the Lock Screen distance layouts appear in inline, circular, or rectangular form.
10. Confirm the Partner Photo Widget renders its test image.
11. Use the app's "Write Demo Cache" button.
12. Confirm the app writes to the shared App Group container successfully.
13. Refresh/re-sign Together with SideStore.
14. Confirm Together still launches after refresh.
15. Confirm existing Home Screen and Lock Screen widgets still render after refresh.

Repeat the same test on Fajr's iPhone.

## Pass Criteria

Phase 1 passes only if both phones can:

- Install the app privately.
- Launch the app.
- Add the Distance widget to the Lock Screen.
- Add both widgets to the Home Screen.
- Render the photo widget.
- Survive SideStore refresh without removing or breaking the widgets.

## Fallback Order

If SideStore fails, test these before considering paid Apple distribution:

1. AltStore
2. Sideloadly
3. Direct Xcode installation

## Known Risk

WidgetKit itself is normal iOS functionality, but shared App Group storage may be limited by the signing profile available to a free Apple account. The Phase 1 app includes a simple shared-storage test so this risk is discovered early.
