# App languages

The app includes 12 languages: English, Simplified Chinese, Traditional Chinese, Japanese, Korean, German, French, Spanish, Brazilian Portuguese, Italian, Russian, and Danish.

Each language contains 298 interface strings, plus microphone and local-network permission descriptions. Coverage includes Home, servers, messages, audio settings, initial setup, certificates, access tokens, connection errors, and accessibility labels. Foundation supplies public-server country names in the app's selected language; continent names use app translations. Server and user names, messages, and server-provided rejection reasons remain in their original language. License notices retain their original text.

Xcode packages the language resources through `Localizable.strings` and `InfoPlist.strings` variant groups. The development language is `en`, and `UIPrefersShowingLanguageSettings` enables the system's per-app language setting. The app uses Foundation's standard language selection and follows the system's preferred languages by default. It does not write `AppleLanguages` or add a custom language override.

Some shared terminology is adapted from Mumble's upstream translations. The license is stored in `Resources/Mumble-Translations-LICENSE.txt`, and the same notice is included in `Legal.html`. New iOS-specific interface strings are translated separately.

## Validation

- `python3 Scripts/check-localizations.py` uses `genstrings` to extract source strings and checks complete key coverage, nonempty translations, format arguments, and permission descriptions for every language.
- Translations omit desktop shortcut suffixes such as `(D)`; the checker rejects these remnants. Parentheses with meaningful explanatory text are retained.
- `python3 Scripts/check-localizations.py --app /path/to/Mumble.app` also validates the language resources and system language setting in an actual build product.
- iPhone Release and isolated Simulator Debug builds passed without app build warnings.
- `Scripts/test-ui-interface.sh` was run with `MU_UI_TEST_LANGUAGE=zh-Hans`, `ja`, and `de`. Foundation selected the requested language, and checks passed for password prompts, setup, certificates, settings, servers, and messages, including accessibility text sizes. Screenshots of the main pages in Chinese, Japanese, and German were also inspected.
- The device build was installed and launched. Language-switching tests use an isolated Simulator app without changing the user's device language or data.
- On iOS 27, Settings → Apps → Mumble → Language displayed the native language selector with all 12 languages listed above.

Language launch arguments are used only by the isolated test app. Test binaries and screenshots are kept in temporary directories and are not tracked by Git.
