# LovelySkyBlue source update

## Changes in this revision
- Added backend catalog category metadata for Gift, CP, Lucky Gift, Flag, and Exclusive.
- Added 16 additional catalog entries across CP, Lucky Gift, Flag, and Exclusive.
- Connected all five Gift Store tabs to the backend catalog filter instead of showing a "coming soon" placeholder.
- Selecting a different category clears the previous gift selection to avoid accidentally sending an item from a hidden category.
- Added `build_release.sh` for dependency resolution, Flutter analysis, release APK build, and copying the APK to Android Downloads.

## Important before production
The added gift names, emoji, and coin prices are provisional sample catalog data because the supplied source did not include the original gift catalog/assets. Confirm the exact names, artwork/animations, and prices against the reference app before enabling real coin deductions in production. This update does not recreate proprietary original artwork or claim exact visual parity.

## Build
From the project root in Termux:
    bash build_release.sh

The script requires a working Flutter + Android SDK setup and network access for dependencies.
