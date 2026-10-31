# macOS — local development (debug service + app)

This is the mode for working on the code: the service runs as a separate debug
process, and the Flutter client runs from the checkout against it. Nothing is
packaged or installed.

Production installs use the DMG path instead — see [packaging.md](packaging.md).

## 1. Start the service

```bash
tools/run-service.sh --state-root /tmp/sportcut
```

The script builds and starts `sportcut-service`, prints the endpoint and token
file, and waits. The state root holds matches, recordings, artifacts, and the
service log.

Use a **short** state root: the Unix socket path must stay under the 103-byte
`sun_path` limit. Prefer `/tmp/sportcut` over a long path under Documents.

Without `--state-root` the script uses a temporary directory that is removed on
exit, which is useful for a quick run but loses matches when the service stops.

## 2. Start the app

In a second terminal:

```bash
SPORTCUT_STATE_ROOT=/tmp/sportcut tools/run-macos.sh
```

The client resolves its target in this order
(`app/lib/src/bridge/sportcut_engine.dart`):

1. `--dart-define=SPORTCUT_ENDPOINT=…` and `SPORTCUT_TOKEN=…`
2. `SPORTCUT_ENDPOINT` with `SPORTCUT_TOKEN` or `SPORTCUT_TOKEN_FILE`
3. `SPORTCUT_STATE_ROOT`, using `<root>/run/s.sock` and `<root>/run/token`

`tools/run-macos.sh` runs `flutter run -d macos`, so hot reload works.

If Flutter is not on `PATH`, set `SPORTCUT_FLUTTER_BIN` to the directory that
contains `flutter`.

### `Failed to foreground app; open returned 1`

This is `flutter run`, not the app. It launches the binary and then calls `open`,
which can race LaunchServices. The app is running; switch to it with ⌘-Tab.

## 3. Where development data lives

The app reads the state root from the service handshake (`service.hello`), so
both sides agree without extra configuration:

| Path | Contents |
| --- | --- |
| `<state-root>/matches/<id>/` | engine artifacts for the match |
| `<state-root>/recordings/<id>/` | the recording copy the service can read |
| `<state-root>/inbox/` | temporary hand-off for probe and import |
| `<state-root>/logs/service.log` | service log |
| `<state-root>/run/{s.sock,token}` | socket and token |

The catalog is the app's local SQLite database at
`getDatabasesPath()/sportcut.db`. On macOS that can resolve under Documents
(including a synced folder), so development may trigger a macOS privacy prompt
for Documents/OneDrive access. The packaged build avoids this by keeping the
catalog in Application Support.

### Import and analysis order

- **Import** stages the picked file in `<state-root>/inbox/`, probes it, then
  copies it into `<state-root>/recordings/<id>/`. The picked file is never
  modified.
- **Prepare analysis** writes `proxy/`, `audio/`, and `frames/`.
- **Player analysis** writes `tracks/player_tracks.json`.
- **Review & score** (rally suggestions) needs tracks. “Analyze rallies” reports
  `player tracks are unavailable; run player tracking before rally analysis`
  until player analysis has completed.
- **Highlights** and **Export** follow the same match directory.

A release service rejects a client-supplied `matchDir`; the debug service accepts
it for development. The client sends it only outside release builds, so switching
between debug and release does not change the protocol logic you are debugging.

## 4. Debug entitlements

`app/macos/Runner/DebugProfile.entitlements` leaves the sandbox off so the app
can reach the service socket outside its container and read the recordings the
service owns. Do not turn it on to “fix” a debug run; the packaged build has its
own entitlement story in [packaging.md](packaging.md).

## 5. Verify a change

```bash
cd app
flutter analyze
flutter test                 # targeted suites are enough for ordinary work
```

Engine-side changes:

```bash
tools/verify-engine.sh       # fmt, clippy, layering, tests
```

The repository's working agreement does not require new tests for ordinary
changes; use the cheapest check that covers the change.

## 6. Reset development data

Stop both processes, then remove the state root you chose:

```bash
rm -rf /tmp/sportcut
```

The catalog is separate; delete it only if you want the library to forget every
match:

```bash
find ~/Documents ~/Library -name sportcut.db -maxdepth 8
# then remove the file the app was using
```

Deleting the catalog does not delete match artifacts; remove the state root for
that.

## 7. Difference from the installed app

| | Local development | Production DMG |
| --- | --- | --- |
| Service | started manually with `run-service.sh` | started by the app’s supervisor |
| State root | whatever you pass | `~/Library/Application Support/com.sportcut.sportcut/state` |
| Catalog | sqflite databases directory | `~/Library/Application Support/com.sportcut.sportcut/sportcut.db` |
| `matchDir` | sent by the debug client | omitted; service resolves by `matchId` |
| Entitlements | debug profile, unsandboxed | release profile, unsandboxed personal build |
| ffmpeg | from your shell or defaults | explicit `/opt/homebrew/bin` or `/usr/local/bin` paths |
| Hot reload | yes | no |

## See also

- Package a DMG: [packaging.md](packaging.md)
- Engine and service from the command line: [engine-and-service.md](engine-and-service.md)
- Failures: [troubleshooting.md](troubleshooting.md)
