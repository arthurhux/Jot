# UI regression checks

Jot includes a developer-only UI lab that uses the production workspace, native notes browser, note store, and bundled WebKit editor. It has a separate bundle identifier and preferences, disposable note directories, and no global shortcut registration. Release builds exclude its fixtures, controls, and entry point.

Build the editor, then launch the lab on macOS:

```sh
npm --prefix Editor run build
./scripts/run-break-ui.sh
```

Add `--audit` to write machine-readable results into the temporary fixture directory printed by the app. The audit disables interactive controls while running.

The controls offer Demo data, Worst case, Empty, One, 1,284 notes, and Read error datasets. They also select Editor/Notes/Settings, window width, 200% WebKit zoom, and an exploratory RTL layout. Option–Command–K opens the controls; Option–Command–J returns to the notes window. Closing the controls returns focus to notes; closing the notes window quits the lab.

The Material control previews each production surface on one Mac: Liquid Glass (macOS 26+), macOS 14–15, and Reduce Transparency. Bright backdrop places a high-luminance, high-detail window behind the panel, the worst case for glass and material legibility. Reference type previews the alternate type scale. The Tone, Active, and Inactive controls tune `WindowAppearance.standard`, the shipped values, which have no user-facing setting. Copy values puts the Swift for them on the clipboard. `--tone=#RRGGBB`, `--transparency=0.45`, and `--inactive-transparency=0.6` preset them for a run. The snapshot matrix also covers the Actions modal, the inactive window (controls hidden), and the native link field. A launch can occasionally fail to capture; frames are retried, but run the matrix again if `done.txt` lists fewer than 23. It opens the glass formatting strip at 480 and 360 pt, and it draws controls as in the key window, because a background launch can't take focus. Option–Command–S saves a composited snapshot of the panel. Launch with `--snapshot-dir=<folder>` to capture every material × Editor/Notes/Settings, with and without the bright backdrop, and then quit. This uses the window server's own-window capture, so it needs no Screen Recording permission. For README and release images, `--hero=<file.png>` loads the Showcase notes over a soft gradient with the formatting strip open, and captures the window with its shadow and a 64 pt margin. It also writes `<file>.browse.png`. `docs/images/jot-1.1.png` was made this way, from fixtures, not personal notes.

## Cases covered

| Surface | Regression checks |
| --- | --- |
| Notes browser | Stable identities through pin/unpin and filtering; separate pinned/ordinary/trash sections; arrow/Return navigation; complete native accessibility collection; first/last-note actions; virtualization |
| Search | Displayed `Untitled` fallback, blank/whitespace titles, body and Markdown, diacritic-aware matching, active/trash filtering |
| Editor controls | Find count/actions and link address/Apply/Remove/Cancel at 320, 360, 480, and screen-wide widths, at 100% and 200% WebKit zoom; visible keyboard focus on both inputs |
| Metadata | Singular word/note/character counts, localized numbers, older date years, New Year time-zone boundary |
| Content and storage | Save/reload of every dataset, Unicode/emoji, long titles/URLs, literal code, a 172,740-character transcript, read-only trash, unreadable-file preservation |

The 16 October 2026 run on macOS 27.0.1 passed 24 first/last-note action pairs across narrow/broad/empty queries. The full library exposed 1,286 accessibility rows (1,284 notes plus two headers), with 2–7 row views realized. All 19 worst-case notes preserved their text through the editor, all six datasets survived persistence round-trips, and the 16 find/link width/zoom cases kept controls visible with labels fitting inside buttons. Native external accessibility Scroll Up/Down actions, pin/unpin, and arrow/Return opening were also checked.

## Automated tests and limits

```sh
swift test --scratch-path /tmp/JotTests --disable-sandbox
npm --prefix Editor test
./dist/Jot.app/Contents/MacOS/Jot --smoke-test
```

The native tests include browser regressions for fallback-title search, table identities, and date boundaries. The separate Swift correctness probes record an existing known issue: failed WebKit snapshots are not surfaced through `EditorController.failure`. That issue remains outside the UI fixes. Complete strict-concurrency migration also remains separate; the shipping package uses Swift 5 language mode.

The packaged smoke test uses disposable notes. Quit normal Jot first so the test can register its exclusive global shortcut. It verifies accessory activation policy, panel hide/reopen, shortcut registration, native search focus/commands, modal edit protection, titles, formatting, autosave, switching, find, pin, trash, and restore.

The shipping minimum is 360pt; 320pt is an extra stress probe. WebKit zoom affects the editor, not native text sizes, and is not a shipping user preference. The endpoint audit invokes native custom-action handlers and inspects native accessibility rows; it is not a complete VoiceOver session or certification across supported macOS versions. The lab does not test notarization, launch-at-login, physical global shortcuts across Spaces, or a fully localized RTL interface.
