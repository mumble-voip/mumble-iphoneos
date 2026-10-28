# Liquid Glass app icon

The primary icon uses `Resources/AppIcon.icon`, packaged through Xcode's Icon Composer compilation pipeline. The foreground is a scalable white Mumble headset with glass material explicitly enabled; the background uses a dark automatic gradient. The native material supplies lighting, highlights, and light, dark, clear, and tinted appearances.

The headset outline comes from Mumble's official `icons/mumble_small.svg`, created by Martin Skilnand (2009) and distributed under its BSD license. The original painted lighting and background were removed, preserving the vector geometry so the system can generate the effects. Attribution and the license are included in `Legal.html`.

The mark's size and center were adjusted: its visible width is approximately 70% of the canvas and its height approximately 75%, slightly smaller than the preceding version. The M-shaped top has smooth corners, the earcups form rounded outlines without the old internal gaps, and the microphone is a rounded capsule. The foreground is a single compound outline with consistently directed subpaths, allowing adjoining parts to receive continuous glass lighting. These proportions are visual choices for this mark, not percentages mandated by Apple. The mark leaves space around the rounded icon edges; the source canvas remains an uncropped 1024 × 1024 square.

`ASSETCATALOG_COMPILER_APPICON_NAME` points to `AppIcon`. The old manually maintained icon lists and `UIPrerenderedIcon` were removed, allowing Xcode to write the primary icon metadata. The minimum iOS version remains 18.0, and the compiler generates static fallback icons for older supported systems.

The old `icon.png`, `icon@2x.png`, `icon7@2x.png`, `icon7@3x.png`, `iconpad.png`, `iconpad@2x.png`, and unused `iTunesArtwork.png` were deleted. Their Xcode file references, resource-copy entries, empty legacy Apple artwork group, and URL configuration entry referring to the old `Icon` file were also removed. The `mumble` URL scheme remains available. The sole design source for the current app icon is `AppIcon.icon/Assets/Mumble.svg`.

## Validation

- Apple's `ictool` exported default, dark, and clear appearances successfully; the actual exports were inspected.
- iPhone Release and Simulator Debug builds passed without app build warnings.
- The device package identifies its primary icon as `AppIcon`. `Assets.car` contains native `IconGroup`, `IconImageStack`, and vector foreground assets rather than only flat PNGs.
- The icon build was installed on an iPhone. Exported previews and build products are kept in temporary directories.
