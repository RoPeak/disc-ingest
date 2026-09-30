# disc-ingest

A deliberately small interactive Bash wrapper around MakeMKV for acquiring video-disc titles into Incoming. It does not identify media, organise libraries, invoke Jellyfin or `video-ingest`, transcode, or remove source media.

## Install

Keep the checkout in a location you control, then expose `bin/disc-ingest` on
your `PATH` (for example with a symlink from `~/.local/bin/disc-ingest`).

The optical drive, disc source, movie and TV Incoming roots, MakeMKV command,
and state location are configurable through `DISC_INGEST_DEVICE`,
`DISC_INGEST_DISC`, `DISC_INGEST_MOVIES_ROOT`, `DISC_INGEST_TV_ROOT`,
`DISC_INGEST_MAKEMKV`, and `DISC_INGEST_STATE_HOME`. Configure the two Incoming
roots explicitly for a new deployment. The state file follows XDG state storage
by default.

`disc-ingest` presents one physical-media menu: Movie DVD/video disc, TV DVD/video disc, Audio CD, inspection, and status. It does not advertise Blu-ray capability. Audio-CD selection performs a lightweight drive check and delegates to `music-ingest cd --device …`; it does not duplicate Whipper or music publication logic.

Inspection and ripping translate MakeMKV's `PRGT`/`PRGC` phase titles and `PRGV:current,total,max` progress records into concise status with truthful elapsed time. A percentage is shown only when `total` is positive. Normal output never dumps robot records; `--verbose` adds meaningful backend messages and `--debug` also prints raw records. Every MakeMKV operation retains raw output under `$XDG_STATE_HOME/disc-ingest/logs/` (or `~/.local/state/disc-ingest/logs/`).

A short-lived inspection cache under `$XDG_CACHE_HOME/disc-ingest/` stores structured metadata only. It is reused only after a new lightweight MakeMKV identity probe agrees; `R` or `--rescan` forces a full scan. Confirmed rip operations are appended to `$XDG_STATE_HOME/disc-ingest/operations.tsv`.

## Validation

Run `tests/run.sh`. It uses a fake `makemkvcon` and temporary paths only. Also run:

```bash
bash -n bin/disc-ingest tests/run.sh tests/fake-makemkvcon
shellcheck bin/disc-ingest tests/run.sh tests/fake-makemkvcon
```

ShellCheck is optional locally because it is not currently installed, but is a pre-release check when available. No real disc is required for the test suite.
