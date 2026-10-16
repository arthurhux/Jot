# UI regression checks

Jot includes a developer-only UI lab that uses the production workspace, native notes browser, note store, and bundled WebKit editor. It has a separate bundle identifier and preferences, disposable note directories, and no global shortcut registration. Release builds exclude its fixtures, controls, and entry point.

Build the editor, then launch the lab on macOS:

```sh
npm --prefix Editor run build
./scripts/run-break-ui.sh
```

Add `--audit` to write machine-readable results into the temporary fixture directory printed by the app. The audit disables interactive controls while running.

The controls offer Demo data, Worst case, Empty, One, 1,284 notes, and Read error datasets. They also select Editor/Notes/Settings, window width, 200% WebKit zoom, and an exploratory RTL layout. Option–Command–K opens the controls; Option–Command–J returns to the notes window. Closing the controls returns focus to notes; closing the notes window quits the lab.

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
