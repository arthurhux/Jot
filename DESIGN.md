# Jot interface and motion

Jot is a frequently used writing utility. Its design prioritizes fast capture, legible text, familiar macOS controls, and confidence that edits are saved.

The native shell uses AppKit windows, system typography, Lucide icons, standard menu commands, a menu-bar item, and native import/export sheets. The app stays dark as requested. The supplied tweakcn tokens define near-black writing surfaces, white controls, neutral secondary surfaces, and an indigo current-note indicator. The window shows the current note without a sidebar. Browse Notes opens in a searchable modal with pinning, deletion, and restoration; Settings opens in a separate modal with shortcut recording and window controls. The footer reveals formatting controls on demand.

Motion follows Interface Craft's readable storyboard and named settings, Emil Kowalski's frequency-based animation decisions, and Apple's feedback, spatial consistency, and accessibility guidance. These principles are implemented in SwiftUI/AppKit and CSS, matching each surface's native framework.

Modal depth follows the supplied Raycast references: a 38% black scrim dims the sharp note; native in-window material frosts only the card. A dark theme tint, a fine light rim, and a short shadow define the surface without a full-window blur. Browse Notes and Settings share `ModalStyle` and `ModalSurface`. Reduce Transparency replaces the card material with a solid theme surface while retaining the dimmed note for context.

Browse Notes groups matching pinned items above other notes. Pointer hover and arrow navigation share one immediate highlight, with actions revealed on that row; only keyboard navigation scrolls the selection into view. The native search field remains ready to type with a caret and no blue rectangle. Settings uses 17-point titles, 13-point control labels, and 12-point section labels and captions, centralized in `ModalTypography`. Native point sizes fit this compact desktop utility; browser-specific font units are not applied to these AppKit/SwiftUI surfaces. Captions that wrap use added line spacing, changing numbers use monospaced digits, and truncated note titles have a full-title tooltip. Settings controls share a trailing edge, keyboard symbols have six-point spacing, and named keys remain intact. There is no appearance category while dark is the only mode.

Lucide icons share a 16-point control canvas and a 1.5-point rendered stroke. Native template images draw generated Core Graphics paths at the requested point size; the editor uses SVG with non-scaling strokes. Native menu labels require the image representation, so all native controls use the same vector-backed NSImage renderer. The source geometry comes from the same pinned Lucide package. This replaces resized PNG templates and the previous 14/15/16/17-point control sizes, which changed stroke thickness and raster sampling. Decorative empty-state icons may use a larger canvas while retaining the same stroke weight.

| Before refinement | Final behavior | Reason |
| --- | --- | --- |
| Every disclosure could share animated behavior | Keyboard commands, panel opening, note switching, and typing are immediate | Frequent actions should stay fast |
| Scattered timing choices | `MotionTokens` and CSS variables define motion with storyboard comments | Values remain easy to review and tune |
| Static pointer controls | Immediate 0.97 press feedback with a short, critically damped settle | A press receives clear feedback without bounce |
| Sudden pointer-triggered layout changes | Compact-window transitions finish in about 180 ms; modals open immediately | Keep frequent browsing and keyboard actions fast |
| Motion assumed available | Native Reduce Motion and web media queries remove spatial effects | Respect system accessibility preferences |
| Failures only visible as save status | A failed write offers retry; quitting requires an explicit choice if edits remain unsaved | Preserve the user's work |

The rendered native app, Browse Notes, and Settings were visually inspected in dark appearance. Search filtering and arrow-key/Return navigation were checked, and the native recorder captured and saved Control–Option–J. Automated native WebKit checks cover document editing and bridging; editor tests cover per-note undo, stale native snapshots, and Markdown round trips. Reduced-motion CSS is implemented. This review did not change the user's system accessibility or appearance settings. Cross-app testing found a conflict with the initial shortcut; the packaged smoke test confirms exclusive registration of the replacement shortcut, but physical cross-app invocation of that replacement remains unverified. The non-activating panel is configured to join other apps and full-screen Spaces.

References: [Apple motion guidelines](https://developer.apple.com/design/human-interface-guidelines/motion), [macOS design guidelines](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), and the locally requested Interface Craft, Emil Design Engineering, and Apple Design skills.

The notes browser uses a virtualized AppKit table with stable, flat section/note identities and SwiftUI row content. Native accessibility provides the full library and first/last-note actions. Narrow find/link bars place the input above fixed-size actions; the footer uses singular word counts, and older modification dates include the year. See [UI regression checks](docs/ui-regression-checks.md) for the developer lab and validation limits.
