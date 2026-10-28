# Legacy code and resource cleanup

This audit checked project references, compiled sources, packaged resources, runtime entry points, and actual call sites. Obsolete implementations were removed; code that still supports protocol compatibility, user-data migration, or active functionality was retained.

## Removals and replacements

- Removed 46 obsolete files: six nib/storyboard files, eight PaintCode drawings, the old numeric badge component, custom server drawing button, flip transition, and unused background, color, and table-header helpers.
- Removed the unreachable mixer debug screen and remote-control functionality that no build configuration enabled. Internal audio diagnostic snapshots remain available to recovery tests; the normal interface does not create debug timers.
- Removed the obsolete SenTestingKit/OCUnit target, runner, and test-bundle configuration. Valid message-link and escaping checks were migrated to an executable Foundation test.
- Removed the old GeoIP country/continent tables and Python 2 generator. Foundation provides country names, while continent names use existing translations. Public-server grouping, deduplication, the offline snapshot, and downloaded cache remain functional. Unused duplicate XML loading and the retained deduplication set were removed.
- Removed the obsolete HTTP public-list refresh script and localization updater that could overwrite English translations. The app's HTTPS list refresh and complete localization checks remain available.
- Removed the unused orange accent color and empty asset catalog. Xcode directly compiles the native `AppIcon.icon` document and generates fallback icons for older systems.
- Removed duplicate AppStore/BetaDist configurations, unused macros, a former maintainer's signing identity, macOS deployment settings, and Bitcode settings. The project retains Debug and Release; Archive uses Release.
- Removed resource references to the old main window and launch storyboard. SceneDelegate creates the interface, and the launch screen uses the system's `UILaunchScreen` configuration.
- Retained only the implemented `audio` background mode. Removed declarations for PushKit VoIP, system PushToTalk, and CoreBluetooth central services, which the app does not implement.
- Migrated five certificate files to ARC, removing manual retain/release calls and dual ARC/MRC branches. Copy results from Security.framework transfer ownership explicitly to ARC; borrowed references use explicit bridging. Fixed strong reference cycles and unsafe references in certificate import dialogs.
- Removed the old password-handling branch replaced by the dedicated retry dialog, write-only fields, unused image methods, and the old two-pass image-mask drawing. Thumbnails use `UIGraphicsImageRenderer`.
- Removed license-screen sections for the retired badge and artwork. Notices for the current icon, translations, FMDB, and library dependencies remain included.
- Removed four translations used only by deleted screens. Each of the 12 languages contains 299 active interface strings; system language selection and permission descriptions remain available.

The project lost 68 obsolete objects. All 264 remaining objects are reachable from the project root, with no dangling file references or empty groups. All 57 app source files belong to the build target, and all runtime resources under Resources are included in the packaging paths.

## Retained compatibility code

- Audio-session and interface API branches for iOS 18–26.
- Older Mumble servers' Opus packet format, public-server ping format, and TCP voice fallback.
- Existing databases, favourites, settings, and certificate identities, including migration of old codec preferences to Opus.
- Active message HTML/data-URL processing and the public-server offline snapshot. The orientation-only iPad entry point was later removed by the [iPhone Duo adaptation](iphone-duo.md), which shares the adaptive Home implementation across window sizes.
- The pinned libmumble source snapshot and licenses. Existing FMDB integration changes are replayed through the checked-in patch rather than resetting the submodule's working contents.

## Repeatable checks

```sh
python3 Scripts/check-project-integrity.py
python3 Scripts/check-localizations.py
bash Scripts/test-text-messages.sh
bash Scripts/test-libmumble.sh
```

The project checker validates references, object reachability, compilation of every app source, and resource packaging. It runs in GitHub Actions, alongside the message-conversion tests.

Additional interface regressions cover public-list grouping, system country names, duplicate/missing fields, cache refresh, details backed by actual Keychain identities, and controller deallocation. Audio and interface test apps are generated in temporary directories with an isolated bundle identifier; they are not tracked by Git.

## Validation results

- iPhone Release and isolated Simulator Debug builds passed without app build warnings. A fresh iPhone build directory verified complete resource packaging.
- Both packages contain the native icon, generated fallback icons, the `mumble` URL scheme, and the audio background mode. The obsolete window, launch storyboard, country tables, and legacy PNGs are absent. Source and package checks passed for all 12 languages, each with 299 strings and permission descriptions.
- The complete English interface audit passed. The final code passed the complete Chinese audit, covering certificate generation/import/details deallocation, password retry/save, public lists, tokens, voice detection, forms, accessibility layout, messages, system image previews, and navigation menus.
- Final audio lifecycle, capture recovery, mute/deafen, media coexistence, and channel-list regressions passed. Both backend tests and the message-conversion tests passed.
- The same Simulator package launched to the initial welcome page on iOS 18.6 and remained running. This startup check does not replace physical-device audio or energy measurements.

Generated regression apps, dynamic libraries, screenshots, and reports are kept in temporary directories and are not added to the repository.
