# DualView 0.6.0 prerelease

This is an early public build intended for practical testing.

## New in 0.6.0

- Multiple image, directory, list-file, and standard-input arguments concatenate into one stream
  in argument order, with duplicates preserved.
- Direct directory arguments now recurse automatically. The former recursion and force-list
  switches remain accepted as compatibility no-ops for this prerelease.
- One-screen and same-orientation display configurations skip the eager whole-library metadata
  pass. Mixed-orientation configurations show a preview while metadata is indexed with at most
  four concurrent operations.
- Pressing `R` while mixed-display indexing is in progress toggles a pending random-mode request.

## New in 0.5.1

- Directory lines in list-file or standard-input sources expand recursively in place, with
  natural full-relative-path sorting inside each directory.
- `--rotate-to-fill cw|ccw` rotates a presentation canvas only when its image orientation differs
  from that screen's native orientation.

## Verified

- Builds for both Apple Silicon and Intel and combines them into one application.
- Automated navigation, orientation, EXIF, circular-mode, multi-input, input-list, parallel
  metadata-ordering, and sorting checks pass.
- Automated one-display sequencing and random-permutation invariants pass.
- The ImageIO metadata path reads macOS-supplied JPEG, PNG, HEIC, and GIF files without warnings.
- Mixed landscape-and-portrait displays have been used interactively.
- Dual-monitor Apple Silicon and a single-monitor Intel laptop running macOS Catalina have been
  used successfully in interactive testing.
- Large JPEG files and deeply nested recursive directory input have been used interactively.

## New in 0.5.0

- One-screen Macs show every image sequentially.
- `--rotate cw` and `--rotate ccw` rotate the image, path label, and progress bar together.
- `--progress` prefixes path labels with the source ordinal; `--progress-bar` draws traversal
  progress along the first display's bottom edge.
- `R` toggles a random permutation while keeping the current state first.
- `-a`/`--auto-advance` advances every five seconds by default; `-t`/`--delay` accepts positive
  decimal seconds and also enables automatic advance.
- `S` pauses or resumes auto-advance without losing its delay; number keys set a 1–10 second
  delay, with `0` selecting 10 seconds.

## Still needing wider hardware testing

- Two landscape displays and two portrait displays.
- Physical one-screen rotation and the new progress overlays.
- HEIC, PNG, and animated GIF input in a full presentation.
- USB footswitches and presentation remotes from different vendors.

## Signing

The downloadable application is ad-hoc signed, not Apple-notarized. macOS may block its first
launch. In Finder, Control-click `DualView.app`, choose **Open**, then confirm **Open**. After
that, it should launch normally for the same copy.

No network access, background service, installer, or elevated privilege is used by DualView.
