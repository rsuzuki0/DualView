# Changelog

## 0.6.0 — 2026-08-09 (prerelease)

- Concatenate multiple image, directory, list-file, and standard-input sources in argument order.
- Make direct directory inputs recursive by default; retain the old recursion and list switches as
  compatibility no-ops.
- Avoid an eager whole-library metadata scan on one-screen and same-orientation displays.
- Show a preview while mixed-orientation metadata indexing runs with bounded parallel work.
- Queue `R` random-mode toggles made during background indexing.

## 0.5.1 — 2026-08-09 (prerelease)

- Expand directory entries in list-file and standard-input sources recursively in place.
- Add `--rotate-to-fill cw|ccw` for per-screen orientation-mismatch rotation.

## 0.5.0 — 2026-08-07 (prerelease)

- Add true one-display operation with a sequential single-image presentation.
- Add clockwise and counterclockwise quarter-turn viewing, including overlays and progress.
- Add source-number prefixes and a first-display progress bar.
- Add runtime `R` toggling of a nonrepeating random permutation.
- Add automatic advance with a configurable fractional-second delay.
- Add runtime `S` pause/resume and number-key delay selection (`0` means 10 seconds).

## 0.4.1 — 2026-08-07 (prerelease)

- Present images across two displays with fit-only rendering and a black background.
- Route images by display orientation, or alternate when displays share an orientation.
- Accept a directory, one image, a path-list file, or a path list on standard input.
- Add recursive natural sorting by complete relative path.
- Add initial fill, circular navigation, optional path labels, and click navigation.
- Support JPEG, PNG, HEIC, and the first frame of GIF through macOS ImageIO.
- Add a normal Dock/Command-Tab application presence and responsive cached decoding.
- Add a universal macOS release build and command-line self-checks.

Known prerelease test boundaries are documented in `Packaging/RELEASE_NOTES.md`.
