# GitHub Actions Build

Use GitHub Actions as the Mac build machine while keeping development on Windows.

## What This Does

The workflow in `.github/workflows/ios-build.yml`:

- runs on GitHub's hosted `macos-latest` runner
- installs XcodeGen
- generates `Together.xcodeproj` from `project.yml`
- builds the app and WidgetKit extension with code signing disabled
- packages `Together.app` into `Together-unsigned.ipa`
- uploads the IPA and build logs as workflow artifacts

No Apple certificates or provisioning profiles are stored in GitHub for Phase 1.

## Push to a Private GitHub Repo

Create a private GitHub repository, then push this local repo to it.

Example:

```bash
git remote add origin https://github.com/YOUR_USERNAME/together.git
git push -u origin main
```

If your local branch is not named `main`, push the branch you actually use.

## Run the Build

1. Open the private repo on GitHub.
2. Go to `Actions`.
3. Select `iOS unsigned IPA`.
4. Click `Run workflow`.
5. Wait for the build to finish.

The workflow also runs on pushes and pull requests.

## Download the IPA

1. Open the completed workflow run.
2. Scroll to `Artifacts`.
3. Download `Together-unsigned-ipa`.
4. Unzip the artifact download if GitHub gives you a `.zip`.
5. Use the contained `Together-unsigned.ipa` for SideStore testing.

## SideStore Test

Try importing `Together-unsigned.ipa` into SideStore. SideStore should handle signing during install/refresh.

If SideStore rejects the unsigned IPA, use GitHub Actions as a build check only and fall back to your friend's Mac for the first signed device install.

## Expected Phase 1 Checks

After installing on an iPhone:

- Together launches.
- The Distance widget appears in the widget picker.
- The Distance widget can be added to the Lock Screen.
- The Partner Photo widget appears in the widget picker.
- Both widgets can be placed on the Home Screen.
- The Partner Photo widget renders its test image.
- SideStore refresh does not break the app or widgets.

Run the same checks on both Sohaib's and Fajr's iPhones.

## Cost Note

Private repositories use included GitHub Actions minutes first. macOS minutes are more expensive than Linux minutes after the included allowance is used, so keep this workflow manual-first while testing.
