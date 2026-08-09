/opt/homebrew/bin/bash: warning: setlocale: LC_ALL: cannot change locale (C.UTF-8): No such file or directory
# DualView

DualView is a minimal one- or two-display image presenter for macOS. It creates one borderless
black window on each selected display and always fits the whole image without cropping or
stretching.

Version 0.6.0 is a prerelease. Mixed landscape-and-portrait displays, large JPEG files, and
deep recursive input have been used interactively. See
[`Packaging/RELEASE_NOTES.md`](Packaging/RELEASE_NOTES.md) for the remaining test boundaries.

## Requirements

- macOS 10.15 or later on Intel
- macOS 11 or later on Apple Silicon
- One or more active displays

The release archive contains one universal application for both Intel and Apple Silicon.

## Install a release build

1. Download `DualView-0.6.0-universal.zip` and verify it against `SHA256SUMS`.
2. Unzip it and move `DualView.app` wherever you want to keep it.
3. On first launch, Control-click the app in Finder, choose **Open**, then confirm **Open**.

The prerelease is ad-hoc signed, not Apple-notarized, so a normal double-click may initially be
blocked by Gatekeeper. It has no installer and requires no administrator access.

## Build from source

Only Apple Command Line Tools are required. A local executable can be built with:

```sh
swift build -c release
```

It is written to `.build/release/dualview`. Run the self-contained checks with:

```sh
swift run dualview-checks
```

To include a metadata-read check for specific local images, append their paths to that command.

To build the universal app, release zip, and SHA-256 checksum:

```sh
Scripts/build-app.sh
```

The results are written below `dist/`. `./bin/dualview` launches the app built there, preserving
the Dock icon and Command-Tab presence.

## Usage

```text
dualview [OPTIONS] [INPUT ...]
```

Examples:

```sh
dualview --fill ~/Pictures/Presentation
dualview --fill --show-path ~/Pictures/Presentation
dualview --fill opening.jpg part1/ slides.txt -
dualview --fill --loop ~/Pictures/Presentation
dualview --show-path --path-font-size 24 --path-font Menlo slides.txt
dualview --rotate cw --progress --progress-bar ~/Pictures/Portraits
dualview --rotate-to-fill ccw ~/Pictures/MixedOrientations
dualview -a -t 2.5 --loop ~/Pictures/Slideshow
dualview --fill slides.txt
cat slides.txt | dualview --fill -
```

Options:

```text
  --fill                 Initially fill both displays when possible.
  --show-path            Show an input-relative path at bottom-left.
  --progress             Prefix the path with its source ordinal, such as [1/383].
  --progress-bar         Show traversal progress as a thin bar on the first display.
  --path-font-size N     Set path size in points; implies --show-path.
  --path-font NAME       Set path font face; implies --show-path.
  --rotate cw|ccw        Rotate displayed images by one quarter turn.
  --rotate-to-fill cw|ccw
                         Rotate only when image and screen orientations differ.
  --click-nav            Left-click advances; right/Shift-click goes back.
  --loop, --circular     Wrap navigation at the first and last states.
  -a, --auto-advance     Advance automatically (default delay: 5 seconds).
  -t, --delay SECONDS    Set the delay and enable automatic advance.
  -V, --version          Show the program version.
  -h, --help             Show help.
```

Each `INPUT` may be a directory, one supported image, a UTF-8 text file containing one image or
directory path per line, or `-` for standard input. Multiple inputs are concatenated in argument
order and duplicates are preserved. `-` may appear once, at the point where its lines should be
inserted. With no input, redirected standard input is read automatically. Relative paths in a
list file are based on that file's directory; paths from standard input are based on the current
working directory.

A directory, whether supplied directly or through a list, is always expanded recursively at that
position in the combined stream. Images within it use natural full-relative-path order.

Supported formats are JPEG, PNG, HEIC, and the first frame of GIF. For compatibility with older
commands, `--list` and `-r`, `-R`, or `--recursive` remain accepted as no-ops during this
prerelease cycle.

## Display behavior

With one display, every source image is shown sequentially. `--fill` has no additional effect in
this mode. `--rotate cw` or `--rotate ccw` rotates the image and its overlays together, allowing
a laptop to be held on its side without changing the source files.

`--rotate-to-fill cw` or `--rotate-to-fill ccw` applies that quarter turn only when the current
image's EXIF-corrected orientation differs from the native orientation of its screen. A portrait
image therefore rotates on a landscape screen while a landscape image remains unrotated; the
rule is reversed on a portrait screen. The path and progress overlays rotate with the image.

When the two displays have different orientations, landscape and portrait images update their
matching display. When both displays have the same orientation, images update the two displays
alternately. `--fill` initially fills both displays when possible.

On one display or two displays with the same orientation, DualView does not scan every image's
metadata before showing the first image. On mixed-orientation displays it shows the first usable
image, then indexes metadata with bounded parallel work before enabling navigation. Pressing `R`
during that short indexing phase toggles whether random mode will start when indexing completes.

`--loop` or `--circular` makes navigation endless: previous from the first state wraps to the
last, and next from the last wraps to the first. Navigation is defined by the current
presentation state; forward and backward traversal need not produce identical image-pair
histories.

If more than two displays are connected, DualView uses the first two ordered left-to-right, then
top-to-bottom.

`--progress` implies `--show-path` and prefixes each displayed file with its original source
position, for example `[1/383]`. `--progress-bar` is independent of the path label and draws the
current traversal position along the bottom of the first display.

`-a` or `--auto-advance` advances every five seconds. `-t SECONDS` or `--delay SECONDS` selects a
positive integer or decimal delay and also enables automatic advance. A manual navigation key or
click restarts the countdown. At the final state it stops unless circular mode is enabled.

## Controls

- Previous: Left, Up, Page Up, Backspace, or Shift-Space
- Next: Right, Down, Page Down, Space, Return, or keypad Enter
- Random permutation: R toggles on or off
- Auto-advance: S starts or stops it without changing the delay
- Auto-advance delay: 1–9 select that many seconds; 0 selects 10 seconds
- Quit: Escape or Command-Q

Changing the delay while auto-advance is running restarts the countdown with the new value.
Changing it while stopped only stores the value; the slideshow remains stopped until `S` is
pressed.

When random mode is enabled, the current state remains first and all remaining states are
shuffled without repetition. Pressing `R` again restores sorted traversal at the same state. On
one display, states correspond one-to-one with images; on two displays, the generated image-pair
states are permuted.

`--click-nav` maps left-click to next and right-click or Shift-click to previous. Most USB
presentation remotes already emit Page Up/Page Down or arrow keys. A programmable USB footswitch
can be assigned those same pairs. Media-volume buttons are intentionally left as system controls.

Only one macOS window can be the keyboard's key window at a time. Click either presentation
window to transfer keyboard control to it. Command-Tab can bring Terminal or another application
in front; the windows are not kept at an always-on-top level. Command-Option-Escape remains an
emergency fallback.

## License

DualView is released under the [MIT License](LICENSE).
