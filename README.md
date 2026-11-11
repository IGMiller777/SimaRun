# SimaRun

CPU activity in the macOS menu bar. A small character runs next to the clock, and the busier your processor is, the faster it runs. An optional percentage sits beside it.

SimaRun exists for people who want this kind of indicator without installing a binary they can't inspect: it is a few hundred lines of Swift, has no dependencies and no network code, and you build it yourself.

## Features

- Animated runner whose speed follows total CPU load
- Optional CPU percentage in the menu bar
- Menu with total load, user / system / idle split, and per-core bars
- Five built-in characters: Cat, Dog, Rabbit, Bird, Fan
- Your own runners from a folder of images or an animated GIF
- Three icon sizes
- Follows light and dark menu bars automatically
- Launch at login
- Uses about 0.3% of one core and under 20 MB of memory

## Requirements

- macOS 27 or later
- Xcode (or the Command Line Tools) with the macOS 27 SDK and Swift 6, to build

## Build and install

```bash
git clone https://github.com/IGMiller777/SimaRun.git
```

```bash
cd SimaRun
```

```bash
./build.sh
```

This compiles a release build, wraps it in `SimaRun.app` in the project folder and ad-hoc signs it for your Mac. Then install and start it:

```bash
cp -R SimaRun.app /Applications/
```

```bash
open /Applications/SimaRun.app
```

There is no Dock icon; look for the runner in the menu bar.

## Using it

Click the runner to open the menu.

| Item | What it does |
| --- | --- |
| CPU / User / System / Idle | Current load, updated every second |
| Per core | A bar and percentage for each core |
| Character | Pick a built-in or custom runner |
| Size | Small, Medium or Large icon |
| Show percentage | Show or hide the number next to the runner |
| Launch at login | Start SimaRun when you log in (the app must be in `/Applications`) |

## Your own runners

Choose **Character → Open Custom Runners Folder**. This opens `~/Library/Application Support/SimaRun/Runners/`. Add either:

- a folder of images, one per frame, played in file-name order — for example `Runners/Fox/01.png`, `02.png`, …
- a single animated GIF — for example `Runners/Fox.gif`

The folder or file name becomes the name in the Character menu. Reopen the menu to see new runners; choose a runner again to reload it after changing its images.

- Images with a transparent background and no colour are tinted to match the menu bar, like the built-in characters.
- Coloured or opaque images are shown as they are.
- PNG, GIF, JPEG, TIFF, HEIC and WebP are accepted. Frames are scaled to the icon size, and at most 120 frames are used.
- Roughly 5–12 frames of a looping motion work best. Animation runs at 4 frames per second when idle and up to 40 at full load.

## Privacy and security

- No network access, analytics or update checks.
- No third-party code; only Apple system frameworks.
- No special permissions. CPU load comes from the public Mach call `host_processor_info`.
- Reads only its own preferences and, if you use it, the custom runners folder.

See [SECURITY.md](SECURITY.md) for how to verify a build yourself.

## How it works

- **Sampling.** Once a second the app reads per-core tick counters from the kernel and compares them with the previous reading. Load is the share of ticks that were not idle.
- **Animation.** Each character is drawn in code and rendered to bitmaps once. The status item shows them through a Core Animation layer; swapping a layer's contents is far cheaper than changing the status item's image many times a second.
- **Speed.** The frame rate scales linearly with a lightly smoothed load value, so short spikes don't make the runner jerk.

## Project layout

| File | Purpose |
| --- | --- |
| `Sources/SimaRun/main.swift` | App start-up |
| `Sources/SimaRun/AppDelegate.swift` | Menu bar item, menu, timers, settings |
| `Sources/SimaRun/CPUMonitor.swift` | Reads CPU tick counters and computes load |
| `Sources/SimaRun/RunnerFrames.swift` | Draws the built-in characters |
| `Sources/SimaRun/CustomRunners.swift` | Loads your own images from the Runners folder |
| `Sources/SimaRun/RunnerView.swift` | Shows the animation and percentage in the menu bar |
| `Resources/Info.plist` | App bundle metadata |
| `build.sh` | Builds and signs `SimaRun.app` |

To add a built-in character, add a case to `RunnerCharacter` in `RunnerFrames.swift` with a title, a canvas size and a drawing function.

## Uninstall

1. Turn off "Launch at login" and choose Quit from the menu.
2. Delete `/Applications/SimaRun.app`.
3. Optionally remove your settings and custom runners:

```bash
defaults delete local.simarun.SimaRun
```

```bash
rm -r ~/Library/Application\ Support/SimaRun
```

## Contributing

Issues and pull requests are welcome. Please keep the project dependency-free and free of network code — that is the point of it.

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
