# Native interface audit and updates

This audit covers Home, Settings, public/favourite/LAN server lists, the channel tree, messages and recipient selection, image details, audio settings, certificate management and import/export, access tokens, legal notices, and server errors. The app version remains 1.5.0.

| Screen or component | Implementation and changes |
| --- | --- |
| Home / Settings | Native `UITabBarController`, `UINavigationController`, grouped lists, and expansion behavior. Retains the Favorites → Public → LAN order, five-item previews, and footer version. |
| Ordinary settings and lists | UIKit cells, Dynamic Type, self-sizing rows, and scrollable content. Settings subpages retain small navigation titles. |
| Favourite-server and certificate-generation forms | Native `UITextField`, `UIStackView`, and Auto Layout. Labels and fields stack vertically at accessibility sizes; `UITableViewController` handles keyboard avoidance. |
| Public-server search | Native `UISearchController` preserves the navigation title and back button; stale search results are discarded. |
| Channel tree, members, and message recipients | Native `UIListContentConfiguration` sizes and positions text. Channels remain neutral, speaking indicators remain green, and symbols have a fixed size cap. Channel/member changes are coalesced; hidden pages do not refresh. |
| Mic / Audio | Native Liquid Glass buttons with large centered symbols and labels underneath. Retains red mute indicators and Self-Deafen behavior. |
| Message input | Native `UITextView`, photo picker, send controls, keyboard layout guide, and touch targets of at least 44 pt. |
| Image details | System `QLPreviewController` provides preview, paging, zoom, and sharing. Temporary image files are prepared in the background and cleaned up when the viewer closes. |
| Certificate list | Native list content replaces a fixed nib. Names, email addresses, issuers, and expiry details can wrap. Reuse resets expiry styling, and dates follow the system locale. |
| Certificate-generation progress | Native activity indicator and a scrollable Auto Layout screen replace the fixed nib. |
| Certificate import / export | System Files picker, native empty-content configuration for import, and cleanup of export files after completion or cancellation. |
| Voice detection / Sidetone | Native progress bars, status text, and full-width sliders replace custom colored backgrounds and narrow accessory sliders. |
| Unread messages / navigation | Native segmented-control text displays unread counts. Navigation uses `UIBarButtonItem`, replacing a custom 32 pt close button. |
| Errors / menus | Native alerts, button menus, and action sheets. Errors no longer disappear after only 0.3 seconds; iPad sheets have presentation anchors. |
| Legal | Native `WKWebView` with safe-area constraints, system fonts, wrapping content, and light/dark colors replaces small text on a black background. |

Message-bubble outlines remain app-drawn vector masks. UIKit provides text display, selection, list scrolling, and menu interaction. The app still manages channel-tree data, voice state, and the messaging protocol; no private Apple APIs are used.

The custom `MUServerButton` drawing, flip transition, third-party unread badge, custom section headers, and replaced nibs were removed from the app build. The later [legacy cleanup](legacy-cleanup.md) also removed their source files and project references.

## Validation

- Simulator Debug and iPhone Release builds.
- General interface checks: ordinary/accessibility-size forms, certificate-cell reuse, settings scrolling, self-sizing rows, search ordering, Files selection, unread counts, and native alerts.
- Message checks: multiline input, consecutive sends, photo selection/cancellation, draft removal, captions, server limits, Quick Look preview/paging/size changes, and keyboard/page transitions.
- Channel-list checks: initialization, out-of-order channel state, member moves/departures, channel removal, hidden-page updates, reconnects, and speaking state.

Test sources and runners are in `Tests/UIInterface`, `Tests/ServerList`, and `Scripts`. Generated test apps and build products remain in temporary directories or Simulator containers.

These builds and automated checks passed during the initial audit. Device installation was initially deferred because the iPhone was offline; subsequent device checks are recorded below.

## Voice detection and Access Tokens fixes (2026-10-13)

- Voice-detection progress bars and threshold sliders have at least 20 pt of horizontal padding, while retaining native UIKit controls and accessibility text sizes.
- Mode and threshold changes update the audio queue immediately. The SNR detector is created/released on demand without restarting the microphone, resetting voice packet sequence numbers, or altering transmitted PCM.
- Access Tokens loads its data when the editor initializes and retains drafts across appearances. Keyboard dismissal, Return, and Done use consistent completion handling, preventing empty-array bounds errors and lost input.
- Simulator/iPhone builds, SNR noise/voice response tests, empty-list add/edit/delete/save/reappearance checks, progress readings, and ordinary/accessibility-size inset checks passed.
- The builds had no app compilation warnings. Xcode's issue list and console were inspected after the Mac was unlocked; findings and follow-up work are recorded below.

## Apple references

- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)
- [UITableViewController](https://developer.apple.com/documentation/uikit/uitableviewcontroller)
- [QLPreviewController](https://developer.apple.com/documentation/quicklook/qlpreviewcontroller)

## Xcode warning cleanup (2026-10-13)

- Removed seven app build-phase entries referring to deleted objects. Parsing confirmed that all local project references resolve, and Xcode's project-integrity warning disappeared.
- Applied Xcode's recommended settings to the app and FMDB: platform deployment targets, dead-code stripping, module verification, script sandboxing, string-catalog symbols, and parallel builds. The app's minimum iOS version remains 18.0.
- Preserved the project format and existing edits, and added the shared UI header to the Classes group. FMDB configuration edits were initially held in the submodule working directory and needed to be preserved for publication; the current build replays them through the checked-in patch described in the README.
- Xcode's issue navigator was empty. Simulator Debug and iPhone Release builds passed without compilation warnings.
- The console included system keyboard, input-method, network, and native-alert diagnostics. An isolated stack inspection of an alert's internal cell showed UIKit setting its own Auto Layout properties during initialization/reuse; app code did not manipulate that cell. The Simulator did not reproduce the same device warning. Device reproduction remained necessary, and the coordinate-conversion and `unsafeForcedSync` messages lacked sufficient stacks to establish a cause.
- The build was installed and launched on the iPhone through Xcode.

## Device summary-layout fix and follow-up (2026-10-13)

- A device reproduction captured conflicting server-summary constraints: the table temporarily assigned a height of zero, conflicting with 16 pt top/bottom padding and three labels.
- The summary is measured using actual native `UILabel` sizes and assigned a valid height before being handed to `UITableView`. Its bottom constraint permits temporary transition sizes; content or text-size changes trigger height recalculation.
- Added checks for initial height and accessibility-size margins. Channel-list tests passed; Simulator/iPhone builds passed without compilation warnings, and Simulator logs had no Auto Layout conflicts.
- The fix launched on the iPhone. The subsequent device log contained zero summary-layout conflicts and zero empty-array bounds errors, but nine `UIScreen` coordinate-conversion diagnostics and one internal UIKit alert-cell diagnostic. The latter two were still unresolved.
- Temporary diagnostic LLDB breakpoints were removed. The first condition was rejected by the debugger; a corrected single diagnostic attempt also failed to capture the relevant warning stack.

## Stalled-capture recovery (2026-10-13)

- A device previously reported a running audio engine, session, and input tap while the PCM sequence remained stuck at 23050. Checking only the engine's running flag cannot detect this failure.
- Input callbacks and successfully processed PCM buffers are counted separately. A running engine is checked every two seconds with 0.5 seconds of scheduling tolerance. Recovery requires more than four seconds without progress; silent PCM and intentional mute do not cause false positives. Automatic recovery is limited to three attempts per 30 seconds.
- Recovery asynchronously drains the audio queue before rebuilding the session, preserving increasing packet sequence numbers for the same connection. Voice-detection previews recover on foreground return, release capture when they end, and transfer capture ownership to a connected conversation.
- Added one-time logs for the first callback and first processed PCM buffer of each capture start. They contain no audio and do not log every frame. Simulator regressions passed for silence, stopped callbacks, stalled conversion, recovery limits, foreground return, and preview exit. Sustained capture during a real connection still required device verification at this stage.

## Push-to-talk layout and quick transmission selection (2026-10-13)

- Push-to-talk uses a wide horizontal control and a separate 64 pt speaker button with native glass styling and press feedback. The wide control follows available width and supports accessibility text sizes. Press, release, cancellation, and leaving the page continue to control transmission. The speaker button invokes the existing Self-Deafen toggle.
- The server's upper-right native menu includes a Transmission submenu with Voice Activated, Push-to-talk, and Continuous. A single checkmark reflects the active mode. Settings and the menu share the same switching entry point, updating audio and bottom controls without restarting capture.
- Transmission and Quality update existing cell checkmarks and preserve UIKit's selection fade instead of replacing feedback with a full reload. Voice-detection rows use native insertion/deletion animations, and quality changes apply immediately.
- Simulator interface tests passed for repeated changes, selection feedback, immediate mode application, menu checks, ordinary/accessibility layouts, press cancellation, Self-Deafen, and releasing PTT when changing mode. Audio lifecycle tests and Simulator Debug/iPhone Release builds passed without app compilation warnings. The fix was installed on the iPhone.
- All three modes align their bottom controls to the actual speaker button; Mic/Audio labels no longer shift the buttons upward. Screenshots and window-coordinate checks on the tested device found speaker buttons at `y=753`, `height=64` in all three modes. Interface tests passed, and the aligned build was installed and launched on the iPhone.

## Consistent favourite-server connection sheets (2026-10-13)

- Selecting a server in Manage Favourites uses the same native action-sheet presentation as LAN / Show All. The selected cell and its bounds provide the anchor; UIKit chooses the arrow and position, and the title always shows the server name.
- Removed the fixed screen-center anchor and forced arrow suppression. Selection fades immediately, matching the LAN list.
- Public servers use the same selected-row anchor, UIKit's default arrow/position, and immediate deselection feedback. Their connection menus match LAN presentation.
- Simulator Debug and iPhone Release builds passed without app compilation warnings.

## Native certificate navigation buttons (2026-10-13)

- Certificate-chain navigation uses `UIBarButtonItem` directly, removing the segmented control and nested toolbar that produced two glass layers. The navigation bar also directly hosts actions for editable certificate chains.
- The down arrow advances to the next numbered certificate; the up arrow returns to the previous one. End buttons disable automatically, and handlers also check bounds. Added native accessibility labels and a fixed small title, with correct lifetime management for replaced titles and certificate arrays.
- Interface regressions passed for repeated navigation, matching fields/numbers, safe endpoint actions, hidden navigation for a single read-only certificate, and actions for editable chains without nested custom views. Screenshots confirmed a single native navigation-bar glass layer.
- Simulator Debug and iPhone Release builds passed without app compilation warnings. The fix was installed and launched on the iPhone.

## Audio coexistence and interruption recovery

- The PlayAndRecord session enables MixWithOthers so music/video playback can coexist with conversation input/output. VoiceChat, Bluetooth HFP, and the existing speaker route remain enabled. The app asks the system to avoid interruptions caused only by alerts or ringtones.
- Native VoiceIO dynamically ducks other media based on local and remote voice activity at a medium level; it does not continuously apply DuckOthers for the entire connection.
- On iOS 27, session-deactivation and resumption-recommendation notifications distinguish app-requested deactivation from system interruptions. A system-deactivated session is not deactivated again. A resumption recommendation can also retry a previously rejected activation; healthy sessions and concurrent requests do not cause duplicate activation.
- Connected conversations attempt to restore input/output after an interruption even without the media-player ShouldResume flag. Standalone previews still honor resumption hints. Explicit disconnection or a delegate veto prevents restoration. Interruptions release PTT state so recovery cannot resume unintended transmission.
- Asynchronous and compatibility-API audio tests passed for media coexistence, voice ducking, connected recovery without a hint, modern notifications, recovery after rejected activation, disconnect cancellation, delegate veto, and PTT release. Existing interface tests passed. Simulator, iPhone, and older-SDK branch builds passed without app compilation warnings.
- The fix was installed and launched through Xcode on the iPhone. Startup logs confirmed PlayAndRecord / VoiceChat, option value 13 including MixWithOthers, native voice processing, and input callbacks. After an idle connected interval, the user played media in another app and returned, confirming both listening and speaking worked. Console inspection still showed input callbacks and PCM startup records, with no system-deactivation or resumption-recommendation messages. This verified media coexistence, not every possible device interruption. Startup and interruption/recovery logs are event-based rather than per-frame.

## Readability with dense channel lists (2026-10-14)

- The bottom glass-button container uses `UIScrollEdgeElementContainerInteraction` and the native soft scroll-edge effect, including status and Mic/Audio labels in the protected fade area. iOS 18–25 uses a system-material background. Button positions and external labels remain consistent across modes; text uses dynamic primary-label colors and a slightly heavier font.
- Channels use SF Symbols' `speaker.wave.2`, with a filled variant for the current channel. Server and message-recipient pages share the symbols. Channels remain neutral, and speaking-user indicators remain green.
- Device logs previously showed a temporary current-channel accessory conflict: a 14.33 pt height could not contain an 18 pt symbol. Accessories use measured native-label sizes and a plain `UIView` around their internal stack, preventing temporary table accessory sizes from directly constraining the symbols.
- Light, dark, and PTT screenshots with 40 dense channels were inspected; bottom labels had a clear fade backdrop. Interface/channel-list regressions and Simulator Debug/iPhone Release builds passed without app compilation warnings. The build was installed and running on the iPhone.
- Xcode's average energy breakdown from launch to observation was Overhead 46.9%, Network 46.9%, CPU 6.1%, and GPU/Display 0%. These are relative contributions to that interval's energy, not CPU utilization or a steady idle measurement. They do not establish that voice apps must have High impact or that Low impact was achieved.
- After the media-switching test, Xcode showed instantaneous CPU at 1%, network at Zero KB/s, and Energy Impact still High. The average energy breakdown was Overhead 47.8%, Network 47.9%, and CPU 4.3%. The sample included connection, media playback, page changes, and keyboard activity; it was not an isolated quiet interval and did not confirm Low impact.

## Transmission-status readability (2026-10-14)

- The upper Voice Activated / Speaking / mute status uses its own native rounded SystemMaterial backdrop. Padding increased, and Caption1 changed to bold Footnote, retaining dynamic light/dark colors, red mute, and green speaking indicators.
- The backdrop is centered and permits wrapping at large text sizes. Existing Mic/Audio and PTT button dimensions, bottom positions, and label layout are unchanged.
- Dense-channel light/dark and accessibility-size screenshots were inspected. Interface regressions and Simulator/iPhone builds passed without app compilation warnings. The build was launched through Xcode on the iPhone.

## Immediate certificate refresh and first-launch setup (2026-10-14)

- Successful identity generation/import posts a certificate-change notification on the main thread. The list no longer relies solely on `viewWillAppear`: it reloads Keychain data even while a sheet covers it. Setup uses the same notification to update completion readiness. Successful saves still notify observers if the sheet was dismissed before generation finished.
- Generation failures retain the form and show an error, including duplicate identities and other system save failures. Completion waits for existing navigation transitions, avoiding concurrent progress-page pushes and dismissal. Certificate lookup rejects empty references early and releases copied Security objects correctly.
- Fresh installations show a native three-step flow: Welcome to Mumble, a VAD/PTT/Continuous choice, and certificate generation/import. Mode selection uses the app's shared setting entry point. Setup cannot finish without an identity, and cancelling generation/import does not mark it complete. Native back navigation, Dynamic Type, and scrolling are supported; completion opens Home/Settings.
- Setup-started and setup-completed flags persist separately, so exiting after database creation does not imply completion. Existing installations open their usual home screen. Mumble links received during setup wait until completion; repeated Finish taps execute completion only once.
- Interface/certificate validation uses an Xcode-signed isolated Simulator build with its own simulated Keychain identity. An initial unsigned copy returned -34018 and was not treated as evidence of a device save failure; actual signed generation and import subsequently passed. Tests delete only their UUID-named certificates. Apps and screenshots remain in temporary directories/Simulator storage, outside Git.
- Full interface checks passed for actual generation and password-protected import with immediate list refresh; fresh/upgrade/interrupted setup; transmission choices; cancellation; incomplete-identity gating; repeated Finish protection; and reachable actions at the largest accessibility size. Screenshots of all three pages and large-text scrolling were inspected. Signed Simulator and iPhone Release builds passed without app compilation warnings. The fix launched through Xcode on the iPhone.

Validation entry points:

```sh
xcodebuild -project Mumble.xcodeproj -scheme Mumble -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/mumble-onboarding-test CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- PRODUCT_BUNDLE_IDENTIFIER=com.blakebill.mumble.audio-lifecycle-tests build
bash Scripts/test-ui-interface.sh /tmp/mumble-onboarding-test/Build/Products/Debug-iphonesimulator/Mumble.app
```

## Fixed bottom glass actions in setup (2026-10-14)

- Continue / Finish uses native `prominentGlassButtonConfiguration`, with a blue primary action and white text. iOS 18–25 uses the native filled configuration.
- Setup uses a regular `UIViewController` containing a separate table and fixed bottom action area. Buttons and page indicators on all three pages anchor to the bottom safe area; explanatory content, mode choices, and certificate state scroll independently. Content and scroll indicators reserve space for the bottom controls.
- The glass action area participates in the native scroll-edge fade, protecting readability as content moves underneath. Dynamic Type changes the button's required height; body or certificate-name length does not move the action area.
- Interface regressions confirmed identical button window coordinates across the three pages at ordinary text sizes. At the largest accessibility size, scrolling did not move the buttons, and certificate details could scroll fully above them. Screenshots were inspected; signed Simulator/iPhone builds passed without app compilation warnings.
- The build installed on the iPhone and launched through the device tool. Xcode reported an untrusted developer certificate for this attempt, but direct installation and launch of the same package succeeded. The user was not asked to change trust settings, and this did not establish that Xcode's debugging warning was fixed.

## Missing server-password prompt and saving (2026-10-14)

- Fixed an alert race when a server rejects a connection: rejection previously appeared while Connecting was still dismissing. Presentation now waits for existing presentation/dismissal transitions; retries use the same entry point. Each alert is checked against the connection attempt and current dialog so stale attempts cannot replace a new connection's prompt.
- Missing or incorrect server passwords show native secure input with Cancel / Connect Once / Save and Connect. Rejected passwords are not prefilled, and empty input disables connection actions. User-password/certificate authentication failures also allow password retry, retaining advice to check the certificate.
- Save and Connect persists credentials only after the server confirms a successful join. Home and favourite management pass the selected favourite's primary key; saving updates only that record's password, preserving other accounts at the same address and other edited fields. Saving an unlisted address creates a password-bearing favourite after successful authentication. One-time connection, cancellation, rejection, and a new connection request do not carry forward the save intent.
- Simulator regressions use an isolated database, a network-free connection stub, and authentication callbacks. Checks passed for immediate rejection during Connecting, secure input, empty-input protection, wrong-password retry, authenticated saving to the selected favourite, preservation of another account at the same address, Connect Once, and cancellation. Full interface checks and Simulator/iPhone builds passed without app compilation warnings. The complete flow had not yet been tested against a real password-protected server.
- Password-prompt screenshots were inspected. The build installed and launched successfully on the iPhone.
