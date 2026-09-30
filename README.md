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

`disc-ingest --verbose` shows raw MakeMKV robot lines. Normal inspect-only mode performs no writes. Confirmed rip operations are appended to `$XDG_STATE_HOME/disc-ingest/operations.tsv` (or `~/.local/state/disc-ingest/operations.tsv`).

## Validation

Run `tests/run.sh`. It uses a fake `makemkvcon` and temporary paths only. Also run:

```bash
bash -n bin/disc-ingest tests/run.sh tests/fake-makemkvcon
shellcheck bin/disc-ingest tests/run.sh tests/fake-makemkvcon
```

ShellCheck is optional locally because it is not currently installed, but is a pre-release check when available. No real disc is required for the test suite.
