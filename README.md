# SkyTrack GNSS Explorer — Windows (.exe) build

Ref: QUO-2026-GNSS-REV3. This is the **exe-scope** slice of the full spec
(Android/.apk work — internal GPS, BLE/SPP, background service, skyplot,
statistics, Google Maps subscription — is explicitly out of scope for this
package per your notes and is not included here).

## What's implemented in this drop (Phase 1–2 of the 25-day plan)

- **Project architecture** matching spec section 7 (`core/`, `domain/`,
  `data/`, `features/`).
- **NMEA 0183 parser** (`lib/data/parser/nmea_parser.dart`): GGA, RMC, GSA,
  GSV, VTG, GLL; XOR checksum validation; talker IDs GP/GN/GL/GA/GB/BD;
  knots→km/h conversion; heading normalization; RMC-date + GGA-time
  combination; impossible-coordinate rejection; diagnostics counters.
- **Stream framer** (`NmeaFramer`): handles split sentences across chunks,
  multiple sentences per chunk, mixed line endings, noise before `$`.
- **Simulation source** (`lib/data/sources/simulation_source.dart`): plays
  back a `.txt`/`.nmea` sample file with Start/Pause/Resume/Finish and
  0.5x/1x/2x/5x speed — this is what the whole app is being verified
  against per the feasibility terms.
- **Windows COM source** (`lib/data/sources/windows_com_source.dart`): port
  enumeration, configurable baud rate (4800–115200, default 9600),
  8-N-1 framing — matches the HC-05 slave-mode profile in your notes.
- **CSV logger** (`lib/data/logging/csv_logger.dart`): fixed header, RFC4180
  escaping, `—`/empty for missing values (never zero), 1s/5s/10s sampling,
  30min/1hr/daily rotation via `.partial` → rename, 5-second flush,
  crash-recovery of orphaned `.partial` files, and a `save()` (locks the
  file — no further writes) vs `clear()` (discard) pair per your notes.
- **Riverpod session controller** wiring source → parser → dashboard state →
  logger, one active source at a time, 5-second stale-data flag.
- **UI (exe scope only, per your notes)**: single Dashboard screen with
  live metrics grid, north-pointing bearing indicator, Start/Pause/Finish
  path controls, optional "enclose in polygon" checkbox, a top-right
  **Select GNSS device** dialog (External receiver / Simulation), and a
  3-dot menu → Settings (logging, sampling, rotation, Clear/Save, theme)
  + Share location entry point. Fully responsive via `lib/features/
  responsive.dart` (relative width/height, not fixed pixels, across
  phone/tablet/laptop).
- **Two themes**: Red & White, and Blue/White/Black, toggleable in Settings.
- **Sample dataset** (`sample_data/`): 100 synthetic samples — 8 seconds of
  no-fix warm-up followed by valid-fix GGA+RMC pairs — as both
  `gnss_sample_100.csv` (normalized format) and `gnss_sample_100.nmea`
  (raw sentences with correct checksums, at 9600-baud pacing) for you to
  forward/check per your note, and for QA to drive the simulation source.

## Not yet built (next phases, per the 25-day plan)

- OpenStreetMap tile rendering on the Dashboard (currently a labeled
  placeholder — package choice for `flutter_map` + OSM tiles needs to be
  pinned and tested next).
- Actual COM-port serial round-trip test against a real/virtual HC-05.
- Raw `.nmea` side-file logging toggle wiring (UI exists, writer pending).
- Share-location and Export wiring beyond placeholders.
- 50-key licensing/token validation engine (v1, hardcoded/fetched).
- Automated unit tests (checksum, sentence types, framing, CSV rotation)
  called for in spec section 12 — recommended before Windows integration
  phase closes.

## IMPORTANT — about the actual `.exe` file

I cannot compile a real Windows executable from this environment: there is
no Flutter SDK or Visual Studio C++ toolchain here, and this sandbox's
network egress doesn't reach `pub.dev`, so Flutter packages can't even be
fetched. A genuine Flutter Windows build **must** be produced on a Windows
10/11 x64 machine. This matches the spec's own note (section 3.1) that a
standard Flutter Windows release is an executable **plus** supporting DLLs
and a data directory — not a single portable file — unless a separate
packaging tool (e.g. Inno Setup, or bundling via `msix`) is added to scope.

### To build the real `.exe` yourself (or hand this to whoever has a Windows dev box):

1. Install Flutter (stable channel) and enable Windows desktop support:
   ```
   flutter channel stable
   flutter upgrade
   flutter config --enable-windows-desktop
   ```
2. Install **Visual Studio 2022** with the "Desktop development with C++"
   workload (required by Flutter's Windows build, not optional).
3. From this project folder:
   ```
   flutter pub get
   flutter build windows --release
   ```
4. The output appears under `build/windows/x64/runner/Release/` — zip that
   whole folder (per your note, ZIP delivery is fine) for handoff/testing.

Once you (or the client) have a Windows machine with Flutter set up, I can
walk through this build step by step, or continue building out the
remaining features (map, raw logging, licensing) so the next handoff is
closer to feature-complete.

flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080