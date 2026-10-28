# iPhone Duo adaptation

The conversation adapts to the current window and safe area instead of checking a device name, screen size, or interface idiom. Build with Xcode 27.1 to enable the native arrangement APIs. The deployment target remains iOS 18; earlier systems retain the single-pane Server/Messages interface.

References: Apple's [Duo design guidelines](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo), [Duo preparation guide](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo) and [adaptive layout tech talk](https://developer.apple.com/videos/play/tech-talks/111463/).

## Conversation layout

The initial arrangement is resolved in `viewIsAppearing:` using the scene's installed traits, safe area and reserved regions. Layout updates remain enabled during presentation, so entering a server does not briefly show the compact interface before adapting. The fixture checks this before the presentation animation finishes.

On iOS 27.1, one `UIArrangementViewController` owns the existing channel and message controllers throughout the connection. Navigation lives in a container around the arrangement. Auto Layout constrains the arrangement's actual bounds to the content safe area and visible keyboard space; pane visibility and the bottom constraint are reconciled together so a keyboard resize does not prematurely hide the focused pane. `UISplitArrangement` supports horizontal and vertical arrangements and uses system division regions to keep panes clear of an active fold.

- Without an active division, regular-width layouts follow the native arrangement's axes: wide content shows two panes side by side (280 points per pane and 280 points of height); tall content stacks them (360 points of width and 240 points per pane). Keyboard compression collapses to the selected conversation when both panes no longer fit. These are content minima, not device or screen dimensions.
- With a horizontal division, Server shows channels above the fold and the conversation below it when there are at least 360 points of usable width and 260 points on each side. Voice controls remain in the shared lower-right rail.
- With a vertical division (book posture), Server remains in the leading pane and Messages in the trailing pane, with native equal regions around the fold. Admission uses the same 280-point width minimum for each pane as the native split and at least 280 points of usable height. The reading order follows the interface language.
- Smaller windows show the selected Server or Messages pane across the available area. Native placement dimensions collapse the other pane without transferring its controller to a different parent.
- Every two-pane layout shows accessible, Dynamic Type pane headings instead of a shared Server/Messages selector over the fold. Compact layouts use a segmented title in horizontal navigation bars and a native symbol menu in vertical bars, where custom title views are unavailable. The menu includes both destinations and their selection state. The composer stays in its pane and above the system keyboard. Typing keeps both panes where space permits. If the keyboard occupies the lower half in tabletop layout, Messages temporarily fills the usable upper area; dismissing the keyboard restores the channel/message split and lower controls. Unfolded and book layouts similarly retain both panes whenever the visible keyboard space still meets their content minima.
- The connection, server model, recipient, draft text, and pending image are reused. Layout changes do not start or restart audio capture. An active message field keeps its focus when the layout changes.
- A pane with zero area skips channel-tree refreshes and message insertion animations. Channels catch up when their pane expands again.

Navigation and tab bars remain UIKit controls, including their system-managed vertical placement. On iOS 27.1 server actions use the navigation item's native overflow menu. The Server heading and summary measure and constrain against their own safe area, including when system controls occupy the leading side. The native split axis is explicit for book/tabletop and the resolved posture participates in layout invalidation. Portrait and both landscape orientations are supported. The obsolete orientation-only iPad welcome wrapper was removed; Home uses the same adaptive table implementation in every window.

## Controls and presentation

Voice buttons use SF Symbols without Mic/Audio captions on every device; accessibility labels and muted-state announcements remain available. Ordinary iPhone layouts retain their floating controls and wide PTT bar.

The side rail uses 44-by-44-point buttons with 20-point symbols, 12 points between buttons, and 10 points of container padding. This keeps their scale consistent with nearby navigation controls while preserving a full touch target. Ordinary floating controls use 22-point symbols.

When UIKit places bars vertically, Self-Mute and Self-Deafen are standard, high-priority toolbar items with symbols and titles. The navigation controller places them in its lower system bar group and manages their glass background, spacing, camera avoidance and overflow. There is no additional content rail or horizontal content inset in these layouts. Muted items use red slash symbols, retain server restrictions, and update from the same model callbacks as the floating controls.

PTT uses a separate hold-to-speak target because a native vertical bar item exposes a click action, not the custom button's press/release events. Its bottom content region is at least 96 points tall, grows with Dynamic Type, reserves layout space, stays above the keyboard and remains available in Messages. In book layout it stays on the system-bar side of the fold. Releasing, dragging away, cancellation and geometry changes end transmission. The toolbar microphone continues to control Self-Mute independently.

When bars remain horizontal in a regular-width layout, the existing scene-level glass rail stays at the lower right, clear of the keyboard and reserved regions. Eligibility uses traits and active divisions, not screen-size tests. Server actions always use the native navigation overflow menu, including inner portrait; there is no separate custom ellipsis button. These layouts reuse the connection, server model and audio owner.

The message composer is centered with a maximum width of 720 points and follows the enclosing navigation controller's keyboard guide. Short windows put a 44-point image thumbnail beside the text instead of a 96-point preview above it. Text scrolls when it exceeds the remaining height, and message reflow preserves the reader's visible history anchor.

Resizing the channel pane, switching the selected pane, or deactivating its scene releases PTT. These actions do not stop a connected voice-activated conversation. Certificate alerts and queued server notices use their originating controller and scene instead of searching globally for a key window.

The setup wizard constrains its table and header to the content safe area. Its scrollable options end above the fixed glass action rather than scrolling behind it. Continue/Finish is centered, capped at 560 points, and stays eight points above the safe-area bottom. Short-height layouts keep a smaller Welcome hero and omit the repeated hero on Transmission/Certificate, where the native navigation title identifies the step. Taller layouts restore those headers. Choices, certificate status and setup progress remain available.

## Verification

The interactive fixture uses an isolated Simulator bundle and a synthetic channel tree. It presents the server controller with the same full-screen animation used by a real connection, waits for presentation completion, and observes layout without forcing periodic layout passes. Initial half-fold presentation must work without rotating the device. The controller reconciles layout after presentation completes, because intermediate layout passes may run while its transition coordinator is active. It never connects to a server or opens the microphone. Generated applications, injected libraries, screenshots, and result files are outside the repository. Its observation timer exists only in the injected test library.

Build the isolated host:

```sh
xcodebuild -project Mumble.xcodeproj -scheme Mumble -configuration Debug \
  -sdk iphonesimulator -derivedDataPath /tmp/mumble-duo-sim \
  PRODUCT_BUNDLE_IDENTIFIER=com.blakebill.mumble.audio-lifecycle-tests \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build
```

Run against a booted Duo Simulator, specifying its identifier when more than one Simulator is booted:

```sh
MU_TEST_DEVICE="<Duo Simulator identifier>" bash Scripts/test-duo-layout.sh \
  /tmp/mumble-duo-sim/Build/Products/Debug-iphonesimulator/Mumble.app
```

The script prints the fixture's Documents directory. Writing one of `server`, `draft`, `keyboard`, `dismissKeyboard`, `messages`, `vad`, `ptt`, `hold`, `rtl`, `ltr`, or `hiddenUpdate` to `duo-command.txt` triggers that test action. `hiddenUpdate` adds a channel while the channel pane is collapsed. Use Device Hub to change posture and orientation, and enable its software keyboard before validating keyboard avoidance. A first responder alone does not prove that the software keyboard is visible; the fixture requires a system keyboard-frame event as well. Inspect `duo-state.json` after each transition; `failures` must be empty. `duo-layout.png` records the corresponding app layout, while Device Hub's live display is needed to inspect the system keyboard. Stop the test bundle after inspection to end the observation timer.

Set `MU_DUO_TEST_ONBOARDING=1` when running the same script to inspect the real wizard instead of the conversation. Its `next`, `back`, `large` and `standard` commands navigate steps and change text size. The fixture checks that options do not overlap the bottom action, content avoids the system bar, and the action retains its bottom anchor and width limit. Closed portrait/landscape and expanded layouts can be inspected without changing production setup defaults.

Validated on the iOS 27.1 Duo Simulator:

- Closed and open layouts, with text and image drafts preserved.
- Keyboard focus across closing/opening, with voice controls above the keyboard.
- Book posture keeps Server in the leading pane and Messages in the trailing pane, with voice controls at the lower right, with both titles clear of the hinge and side bars. Tabletop keeps channels above and messages/voice controls below; the composer and footer must not overlap. Explicit Messages selection and returning to Server are checked separately.
- First connection without rotating, both landscape directions, keyboard-visible book layout, reading-direction changes, and native overflow menu availability.
- Held PTT released after a geometry change.
- Closed landscape controls avoid the camera, status region and native bar. Inner portrait keeps the system overflow menu without an additional custom menu button.
- Original connection/model identity and no audio start from layout changes.
- Hidden channel updates deferred until the pane becomes visible, then reflected in the table.
- Both portrait and landscape compact chat fill the usable display.
- A real software keyboard with a photo draft remains clear of the send button during closed-landscape, open, and partial-fold transitions. Short-height thumbnail layout and restoration of the shared message/control surface after returning to Server were inspected in Device Hub and checked against system keyboard-frame events.
- A keyboard covering the tabletop lower half temporarily moves Messages into the upper usable area and restores both panes on dismissal. Book posture retains both panes above its split keyboard. RTL changes reverse content order while preserving the physical control edge. Compact vertical navigation exposes a native Server/Messages menu, and every pose retains the system overflow menu.

Ordinary iPhone interface, channel-list, and audio lifecycle regression scripts accept the same `MU_TEST_DEVICE` selector. The compatibility audio test requires a separate build; passing `legacy` to the runner alone does not select that compiled branch. For an SDK-branch test with the current SDK, use a temporary prefix header that imports UIKit, then undefines `__IPHONE_OS_VERSION_MAX_ALLOWED` and defines it as `260000`. Pass its absolute path as `GCC_PREFIX_HEADER` with `GCC_PRECOMPILE_PREFIX_HEADER=NO`. Defining only a command-line macro is insufficient because imported SDK modules can restore the current version. This tests compiled fallback logic, not an actual older SDK or runtime.

Debug Simulator, compatibility-branch, and unsigned iPhone Release builds are checked separately. Simulator layout tests do not validate Duo microphone routing, real network continuity, power consumption, or physical fold behavior. Those require a Duo device. Multiple simultaneous app scenes remain disabled because the application still has one shared connection and audio owner.
