# Security

SimaRun is meant to be small enough to audit yourself before you run it.

## What the app does and doesn't do

- **No network access.** There is no networking code, no analytics and no update check.
- **No dependencies.** Only Apple system frameworks are linked (AppKit, Foundation, CoreGraphics, QuartzCore, ImageIO, ServiceManagement).
- **No special permissions or entitlements.** CPU load is read with the public Mach call `host_processor_info`.
- **Files it touches:**
  - its own preferences (`UserDefaults`, domain `local.simarun.SimaRun`)
  - `~/Library/Application Support/SimaRun/Runners/` — read only, and only if you add custom images there
- **Login item:** registered with `SMAppService` only when you turn on "Launch at login".

## Checking a build yourself

```bash
otool -L SimaRun.app/Contents/MacOS/SimaRun
```

```bash
nm -u SimaRun.app/Contents/MacOS/SimaRun | grep -iE 'socket|connect|URLSession|CFNetwork|nw_'
```

The first should list only system libraries; the second should print nothing.

## Reporting a problem

Please open an issue on the repository. For anything sensitive, use GitHub's private vulnerability reporting on the repository's Security tab.
