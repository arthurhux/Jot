# Sharing Jot on GitHub

## How someone installs and opens it

For a packaged release, people do not need Xcode, Node.js, npm, or the repository:

1. Download the Jot **DMG** from the repository's **Releases** page. GitHub's automatically generated **Source code** archives contain the project, not an installable app.
2. Open the disk image and drag `Jot.app` onto the **Applications** shortcut. Eject the disk image afterward.
3. Double-click Jot. A properly Developer ID-signed and notarized release may still show macOS's normal first-launch confirmation for an internet download.
4. Use the menu-bar icon or **Control–Option–J** to open the notes panel from another app. **Command–comma** opens Settings, where the shortcut can be changed.

Closing the notes window hides it and leaves Jot running. Quitting the app or restarting the Mac stops the shortcut until Jot is opened again. Automatic launch at login is not currently built in. Notes are stored on each person's own Mac; the released app does not contain your notes.

## Current release readiness

| Item | Current state |
| --- | --- |
| Minimum system | macOS 14 or later |
| Packaged executable | Apple silicon (`arm64`) only |
| Runtime dependencies | Native system frameworks; editor and icons bundled locally |
| Signature | Ad hoc, for local development |
| Apple notarization | Not configured by the build script |
| Gatekeeper assessment | Current local bundle is rejected by `spctl --assess --type execute` |
| Public GitHub repository/release | [arthurhux/Jot](https://github.com/arthurhux/Jot), with a development preview DMG |
| Source license | No project license has been selected yet |

The current bundle is suitable for local testing. A download from GitHub will be subject to macOS security checks. A public repository alone does not give the app a trusted signature. The normal distribution path is a Developer ID Application certificate, Hardened Runtime, a secure signing timestamp, Apple notarization, and a stapled ticket. This needs an Apple Developer Program membership and the appropriate certificate/credentials. See [Apple's signing and notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

An explicitly labeled unnotarized preview can be shared with testers who understand the limitation. Depending on their Mac's policy, they may be able to approve that specific app in **System Settings → Privacy & Security → Open Anyway** after the first launch attempt. Managed Macs may prevent this. See [Apple's opening instructions](https://support.apple.com/en-us/102445). Do not ask users to disable Gatekeeper or remove system security protections as an installation step.

## Preparing a normal public release

1. Choose a project license and retain the notices for bundled dependencies. Keep signing certificates and credentials outside the repository.
2. Build and test the release app. The current script builds for the Mac's architecture. To support Intel Macs too, add and validate an Intel build or a universal app before advertising Intel support.
3. Sign the final app with a **Developer ID Application** certificate, **Hardened Runtime**, and a secure timestamp. The existing build script only creates an ad hoc signature; it does not perform this step.
4. Package the signed app in the DMG, sign the DMG with Developer ID, submit the DMG using Apple's `notarytool`, wait for an **Accepted** result, then staple and validate its ticket. [Apple's custom workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow) covers these steps.
5. Verify the signature and Gatekeeper assessment, then test the actual downloaded archive on a separate Mac with normal security settings. Verify first launch, editing/saving, reopening, and the shortcut across apps.
6. Attach the final DMG and its SHA-256 checksum to a GitHub Release. Generate the final checksum after signing and stapling, because those steps modify the image. State the version, macOS requirement, architecture, and signing/notarization status in the release notes.

## Build the DMG

```sh
./scripts/build-dmg.sh
```

Or package the existing app without rebuilding or changing its signature:

```sh
./scripts/build-dmg.sh --skip-build
```

The script detects the bundled version and actual executable architecture. It creates a compressed, read-only UDZO image containing Jot, an Applications shortcut, and installation instructions. It verifies the image and app signature and writes a SHA-256 checksum alongside the DMG. The current development DMG is still ad hoc signed at the app level and unnotarized; the container itself does not change Gatekeeper trust.

A ZIP can also be offered as an alternative download:

For a ZIP that preserves the application bundle, use Apple's `ditto` packaging format after the final signing and stapling steps:

```sh
ditto -c -k --sequesterRsrc --keepParent dist/Jot.app dist/Jot-macOS-arm64.zip
shasum -a 256 dist/Jot-macOS-arm64.zip
```

Packaging the current ad hoc app this way does not notarize it. These commands create local artifacts; they do not publish anything.

GitHub source availability and app distribution are separate: developers can build from source using the README today, while ordinary users should get a packaged release. The app has no automatic update system yet; users replace the app with a newer release, and their notes stay in their Application Support folder.
