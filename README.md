# Together

Together is a private iPhone app for Sohaib and Fajr.

Phase 1 is a sideloading proof of concept:

- Install the app privately on two iPhones.
- Show a Distance widget.
- Show a Partner Photo widget.
- Keep both widgets in one WidgetKit extension.
- Avoid backend, camera, authentication, and real location sharing until sideloading is proven.

The project is currently prepared for a Windows-first workflow. Most source edits can happen here, then GitHub Actions or a Mac with Xcode handles the native iOS build, signing, and sideloading tests.

Start here:

- [GitHub Actions build](docs/github-actions-build.md)
- [Windows-first workflow](docs/windows-first-workflow.md)
- [Phase 1 sideloading test](docs/phase-1-sideloading.md)
- [Xcode setup](docs/xcode-setup.md)

Preferred Windows-first route: push this repo to a private GitHub repo and run the `iOS unsigned IPA` workflow to produce `Together-unsigned.ipa` for SideStore testing.

If GitHub Actions or SideStore packaging hits a wall, use your friend's Mac. If the Mac can install XcodeGen, use `project.yml` to generate the Xcode project automatically. If not, create the Xcode project manually with the setup guide.
