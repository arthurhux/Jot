# Mac App Store readiness

Audit of Jot against Apple's current guidance, done 9 November 2026 on macOS 27.0.1 with Xcode 27.2. Sources: [HIG Materials](https://developer.apple.com/design/human-interface-guidelines/materials), [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass), [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views), [HIG Color](https://developer.apple.com/design/human-interface-guidelines/color), [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) (updated 16 October 2026), [App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox), and [required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api).

## Liquid Glass

| HIG rule | Jot |
| --- | --- |
| Liquid Glass is for controls and navigation, not the content layer; content backgrounds use standard materials | The note and window use a behind-window `NSVisualEffectView` under a near-black tone. It's darker while Jot is in use and more see-through when another app is active, like Raycast Notes. Glass is used for the toolbar group, footer toggle, find bar, banners, the editor failure card, and the Browse Notes and Settings cards |
| Use it sparingly; avoid glass on glass | Controls inside glass cards (close, Recently deleted, rows, shortcut keycap) use vibrant fills, not more glass |
| Regular glass for text-heavy surfaces; clear glass needs dimming | Regular glass everywhere. The modal scrim stays at 38% black |
| Tint only for status or primary actions | Orange tint on the failed-save banner only. The empty state's New note uses `.glassProminent` |
| Group custom glass in `GlassEffectContainer` | The toolbar capsule is in a container. Other glass shapes stand alone |
| Remove custom backgrounds, borders, and shadows from glass | Glass cards drop the hand-drawn rim and shadow; the system supplies both |
| Accessibility settings may remove or change effects; test custom elements | Reduce Transparency switches every surface to opaque theme colors on all macOS versions. The editor page also drops its translucent class |
| Builds on earlier systems | macOS 14–15 keep the shipped look: opaque note and frosted modal card |

The window is a near-black tone (`#0A0A0A`) over the blurred desktop. It ships as `WindowAppearance.standard`: 60% transparency while Jot is active, and 85% while another app is active and the pointer is elsewhere. Both values were chosen by eye in the UI Lab. There's no user setting; the UI Lab tunes the values, and its Copy values button produces the Swift. Measured on composited UI Lab snapshots over a bright white, yellow, cyan, and pink backdrop. The figures use the 90th-percentile luminance behind text. WCAG AA needs 4.5:1 for text up to 17 pt.

Secondary text (captions, counts, hints, placeholders, quiet icons) is no longer a fixed `#A1A1A1`. `WindowAppearance.secondaryText` picks the darkest gray that keeps 4.8:1 against the worst background measured for the current transparency. Glass modal cards sit about 0.026 lighter than the window, so they get their own gray. A modal also keeps the darker active backdrop while it's open.

| Surface (Black) | Background | Secondary text | Body text (#FAFAFA) |
| --- | --- | --- | --- |
| Window, 60% active | 0.046 | `#B0B0B0`: 5.05:1 | 11.9:1 |
| Glass modal, 60% active | 0.072 | `#C5C5C5`: 4.98:1 | 8.2:1 |
| Window, 85% inactive | 0.076 | `#C7C7C7`: 4.93:1 | 7.9:1 |
| Increase Contrast | 0.012 | `#FAFAFA`: 16.2:1 | 16.2:1 |

With the old fixed `#A1A1A1`, captions measured 4.14:1 at 60% and 3.15:1 at 85%.

- **Increase Contrast** (System Settings › Accessibility › Display) caps transparency at 20% and makes secondary text white. The editor page's existing `prefers-contrast` styles still apply.
- **The page's muted text** (placeholder, quotes, done tasks) is set from the same native value.
- **Links** in Settings stay white with an underline, because accent-blue text measures about 2.4:1 on bright glass.
- **Lab check:** the UI Lab's Increase Contrast toggle previews the mode, and its snapshot matrix captures it (`contrast-bright-editor.png`).

## Sizes, spacing, and controls (HIG)

| HIG rule | Jot |
| --- | --- |
| macOS controls are 28×28 pt by default, 20×20 pt minimum (Accessibility) | Every borderless control is at least 28×28 pt. Toolbar items are 32×28 pt, and glass icon buttons are 30 pt |
| Highlight controls within a Liquid Glass group; make the hit regions contiguous (Pointing devices) | The toolbar items touch, with no gaps, inside the glass capsule. Each item gets its own capsule hover highlight, 4 pt inside the group so the radii stay concentric. The Actions menu has the same highlight |
| Toolbar items have no bezel; at most three groups; every item is also a menu command | One borderless group. Browse Notes (⌘P), New Note (⌘N), and Settings (⌘,) are all in the menu bar |
| Default text is 13 pt, minimum 10 pt (Typography) | The window title is 13 pt semibold (Headline), labels 13 pt, captions 12 pt, the footer 11 pt |
| Respect the person's accent color (Color) | Switches, the slider, links, and the prominent action use `controlAccentColor` (blue by default) |
| A toggle button shows its state with its background (Toggles) | Recently Deleted keeps a filled background while it's the current view. VoiceOver reads it as selected, with a hint and the deleted-note count |
| Hover-only controls need another way in (Pointing devices) | Pin, delete, restore, and delete-permanently appear on hover, and they're also in each row's context menu |
| Follow the person's scroll bar setting (`NSScroller.preferredScrollerStyle`) | The notes list keeps the system style, but draws only the knob, inset from the card's corners |
| Window shape | The window content is clipped to 26 pt continuous (squircle) corners on a clear titled window, so the standard window buttons, resizing, and shadow are kept |
| Modals and motion (Motion; animation decisions from Emil Kowalski's rules) | Browse Notes, Actions, and Settings scale from 0.96 and fade in over 220 ms (strong ease-out) when opened with the pointer, and leave in 160 ms. With ⌘P, ⌘J, ⌘,, Esc, or Return they open and close instantly. Reduce Motion fades only |
| Hidden controls (Pointing devices) | Like Raycast, the toolbar, window buttons, and T fade out while another app is active and the pointer is elsewhere. They return on hover or focus, and every command stays in the menu bar |
| Text fields | Links are edited in a native rounded field, with Apply, Remove (for an existing link), and Close or Esc. Bare domains get https://, and email addresses get mailto:. Anything other than web, email, or phone links is refused with an inline message |
| Avoid placing controls at the bottom of a macOS window (Layout) | **Deliberate exception:** the formatting strip opens from the footer's T button, as requested. Every command is also in the Format menu, and ⌘B, ⌘I, and ⌘K work |

The status-item menu, alerts, the open and save panels, and the switches in Settings are standard AppKit/SwiftUI components. They adopt Liquid Glass automatically when built with the macOS 26+ SDK.

## Verified on this Mac

- `swift build` passes in debug and release with no warnings.
- `swift test`: 20 tests pass. There is one known issue, recorded before this change: failed WebKit snapshots aren't surfaced.
- `npm --prefix Editor test` hung idle on this Mac, both inside and outside the tool sandbox, so it was stopped without a result. Those tests don't load `editor.css`, which is the only editor file this change touched. The editor's translucency was checked visually in the snapshots instead.
- The UI Lab snapshot matrix captured Liquid Glass, macOS 14–15, and Reduce Transparency across Editor, Browse Notes, and Settings, each with and without a bright, busy backdrop behind the panel. It also captured the glass formatting strip open at 480 pt (all nine commands) and at 360 pt (six commands plus a More menu).
- Hover states and the strip's motion need a pointer and real time, so they were not captured in snapshots. Check them by hand in the UI Lab.
- The packaged smoke test passed inside the App Sandbox: `scripts/build-app-store.sh`, then `--smoke-test`. It covered the menu-bar policy, hide and reopen, global shortcut registration, WebKit, modal edit protection, titles, Markdown, autosave, switching, find, pin, trash, and restore.
- Without `com.apple.security.network.client`, the sandboxed editor never loads, so the entitlement is required. Carbon `RegisterEventHotKey` works in the sandbox.

## What's in place

- `AppStore/Jot.entitlements` has three entitlements: sandbox, user-selected read/write, and network client (needed for WebKit, see above).
- `AppStore/PrivacyInfo.xcprivacy` declares no tracking and no collected data. Its only required-reason API is UserDefaults (`CA92.1`). Apple doesn't yet enforce privacy manifests on macOS, but the file is included anyway.
- `Info.plist` sets `ITSAppUsesNonExemptEncryption = NO` and `JotPrivacyPolicyURL`.
- The ⌘ toolbar button and ⌘J open a searchable Actions modal. It mirrors the menu bar: Note, Window, and File commands.
- Settings links to the privacy policy and states that Jot collects no data, as guideline 5.1.1(i) requires. The policy text is in `PRIVACY.md`.
- About now reads its version from the bundle. It previously showed the hard-coded value 1.0.
- `scripts/build-app-store.sh` builds a sandboxed app at `dist/AppStore/Jot.app`. The developer `dist/Jot.app` is left untouched.
  - Ad hoc by default, for local testing.
  - With `JOT_SIGN_IDENTITY`, `JOT_TEAM_ID`, `JOT_PROVISIONING_PROFILE`, and `JOT_INSTALLER_IDENTITY` set, it embeds the profile, adds the team and application identifiers, and writes a signed `Jot.pkg`.

## Still needed before submitting

1. **Apple Developer Program membership.** You also need an App ID matching the bundle ID (`com.arthur.jot`), a Mac App Store provisioning profile, and Apple Distribution and Mac Installer Distribution certificates.
2. **Xcode archive (recommended).** Guideline 2.4.5(ii) asks for Xcode packaging, and App Store Connect lists Mac builds as built with Xcode. Create a macOS app target that uses these sources, entitlements, privacy manifest, and Info.plist, then use Product › Archive › Distribute App. The `pkg` path in the script uses Apple's `productbuild` and Transporter, but an Xcode archive is Apple's documented route. Note that `dist/Xcode-Production/Jot.swift` predates this Liquid Glass work and must be regenerated before you use it.
3. **Publish `PRIVACY.md`** at the URL in `JotPrivacyPolicyURL` (or change the key). Enter the same URL in App Store Connect, and answer the privacy questions with Data Not Collected.
4. **Existing notes move into the sandbox container.** A sandboxed Jot reads `~/Library/Containers/com.arthur.jot/…/Application Support/Jot`, not `~/Library/Application Support/Jot`. Someone who already uses the DMG build would start empty. Apple's `container-migration.plist` can move or copy the old folder on first launch. Decide before release.
5. **App icon.** Make a layered Icon Composer `.icon` (1024 × 1024) for the macOS 26+ look. Xcode generates the older sizes. The current bitmap still works, but the system will split it into layers itself.
6. **App Review notes.** Explain the menu-bar-only design (LSUIElement), where to find the status item, the global shortcut (⌃⌥J), and why network-client is requested (WebKit only; Jot makes no requests). Guideline 2.3.1(a) asks for features to be described there.
7. **Screenshots** at Mac App Store sizes, a support URL, and a category (Productivity is already set in Info.plist).

## Low-risk items to know about

- `NativeEditor` makes the web view transparent with `setValue(false, forKey: "drawsBackground")`. Key-value coding reaches a private WebKit setter. Many shipping App Store apps use this, and it links no private symbol, but it isn't a public API.
- The `--smoke-test`, `--inspect-editor`, and `JOT_DATA_DIR` hooks remain in release builds. They can't be reached from Finder or any UI, so they don't count as hidden features under guideline 2.5.19, but they could be compiled out of an App Store configuration later.
