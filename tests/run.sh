#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT=$ROOT/bin/disc-ingest
FAKE=$ROOT/tests/fake-makemkvcon
WORK=$(mktemp -d)
trap 'rm -rf -- "$WORK"' EXIT
pass=0 fail=0

run_case() {
    local name=$1 input=$2 mode=${3:-positive} expected=${4:-0}
    local case_root="$WORK/$name" output rc
    mkdir -p "$case_root/movies" "$case_root/tv"
    : > "$case_root/device"
    set +e
    # A normal session remains open after each action; finish it explicitly.
    output=$(printf '%b' "${input}8\\n" | FAKE_MODE="$mode" DISC_INGEST_MAKEMKV="$FAKE" DISC_INGEST_DEVICE="$case_root/device" DISC_INGEST_MOVIES_ROOT="$case_root/movies" DISC_INGEST_TV_ROOT="$case_root/tv" DISC_INGEST_STATE_HOME="$case_root/state" DISC_INGEST_CACHE_HOME="$case_root/cache" "$SCRIPT" 2>&1)
    rc=$?
    set -e
    if [[ $rc == "$expected" ]]; then
        pass=$((pass + 1))
    else
        printf 'FAIL %s: expected rc %s, got %s\n%s\n' "$name" "$expected" "$rc" "$output" >&2
        fail=$((fail + 1))
    fi
    CASE_ROOT=$case_root CASE_OUTPUT=$output
}

assert_contains() { [[ $CASE_OUTPUT == *"$1"* ]] || { printf 'FAIL missing: %s\n' "$1" >&2; fail=$((fail + 1)); }; }
assert_file() { [[ -e "$1" ]] || { printf 'FAIL missing file: %s\n' "$1" >&2; fail=$((fail + 1)); }; }
assert_absent() { [[ ! -e "$1" ]] || { printf 'FAIL unexpected path: %s\n' "$1" >&2; fail=$((fail + 1)); }; }

run_case empty '4\n' empty 0; assert_contains 'No readable video disc detected'
run_case missing '4\n' missing 0; assert_contains 'did not return one valid TCOUNT'
run_case malformed '4\n' malformed 0; assert_contains 'did not return one valid TCOUNT'
run_case inspect '4\n' positive 0; assert_contains 'ID 0'; assert_contains 'duration 1:30:00'
run_case cancel '8\n' positive 0; assert_file "$CASE_ROOT/state/sessions"

music_fake="$WORK/music-ingest"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" > "$DISC_INGEST_TEST_ARGS"\n' > "$music_fake"
chmod +x "$music_fake"
mkdir -p "$WORK/audio/movies" "$WORK/audio/tv"
: > "$WORK/audio/device"
DISC_INGEST_TEST_ARGS="$WORK/audio/args" DISC_INGEST_MUSIC_INGEST="$music_fake" DISC_INGEST_MAKEMKV="$FAKE" DISC_INGEST_DEVICE="$WORK/audio/device" DISC_INGEST_MOVIES_ROOT="$WORK/audio/movies" DISC_INGEST_TV_ROOT="$WORK/audio/tv" "$SCRIPT" <<< $'3\nb\n'
[[ $(<"$WORK/audio/args") == *"--rip-profile bounded"* ]] || { printf 'FAIL bounded audio delegation\n' >&2; fail=$((fail + 1)); }

set +e
status_output=$(DISC_INGEST_MAKEMKV="$FAKE" DISC_INGEST_DEVICE="$WORK/status-device" "$SCRIPT" status 2>&1)
status_rc=$?
set -e
[[ $status_rc == 0 && $status_output == *'MakeMKV: available ('* ]] || { printf 'FAIL MakeMKV availability status\n%s\n' "$status_output" >&2; fail=$((fail + 1)); }

run_case movie_accept '1\nC\n2\n0\nThe Matrix (1999)\nRIP\nA\n' positive 0
assert_file "$CASE_ROOT/movies/The Matrix (1999)/The Matrix (1999).mkv"; assert_file "$CASE_ROOT/state/operations.tsv"
run_case movie_keep "1\nC\n2\n0\nO'Brien\nRIP\nK\n" positive 0
assert_file "$CASE_ROOT/movies/O'Brien/title_t00.mkv"
run_case movie_edit '1\nC\n2\n0\nFilm\nRIP\nE\nFilm [Director Cut].mkv\n' positive 0
assert_file "$CASE_ROOT/movies/Film/Film [Director Cut].mkv"
run_case progress_semantics '1\nC\n2\n0\nSynthetic\nRIP\nA\n' progress_shape 0
assert_contains 'Ripping: 50%'
assert_contains 'Current: Finalizing MKV complete'
[[ $(grep -o 'Current: Finalizing MKV complete' <<<"$CASE_OUTPUT" | wc -l) -eq 1 ]] || { printf 'FAIL duplicate current completion\n' >&2; fail=$((fail + 1)); }
run_case traversal '1\nC\n2\n0\n../escape\n' positive 0; assert_contains 'safe basename'; assert_absent "$CASE_ROOT/movies/escape"

mkdir -p "$WORK/conflict/movies/Exists"
run_case conflict '1\nC\n2\n0\nExists\nX\n' positive 0; assert_contains 'Destination already exists'
run_case multi '1\nC\n3\n0, 1\nCollection\nRIP\nFirst\nSecond\n' positive 0
assert_file "$CASE_ROOT/movies/Collection/First.mkv"; assert_file "$CASE_ROOT/movies/Collection/Second.mkv"
run_case tv '2\nC\n3\n1,2\nBanshee Season 1 Disc 1\nBanshee S01E01\nBanshee S01E02\nRIP\nA\nA\n' positive 0
assert_file "$CASE_ROOT/tv/Banshee Season 1 Disc 1/Banshee S01E01.mkv"; assert_file "$CASE_ROOT/tv/Banshee Season 1 Disc 1/Banshee S01E02.mkv"
run_case all_titles '1\nC\n1\nAll titles\nRIP\nFeature\n\n\n' all 0
assert_file "$CASE_ROOT/movies/All titles/Feature.mkv"; assert_file "$CASE_ROOT/movies/All titles/title_t01.mkv"
run_case zero '1\nC\n2\n0\nZero\nRIP\n' zero 0; assert_contains 'produced 0 new MKVs'; assert_absent "$CASE_ROOT/movies/Zero/title_t00.mkv"
run_case multiple '1\nC\n2\n0\nMultiple\nRIP\n' multiple 0; assert_file "$CASE_ROOT/movies/Multiple/title_a.mkv"; assert_file "$CASE_ROOT/movies/Multiple/title_b.mkv"
run_case failure '1\nC\n2\n0\nFail\nRIP\n' fail 0; assert_contains 'Rip failed while reading title 0'
run_case partial '2\nC\n3\n0,1\nPartial\n\n\nRIP\n\n' partial 0; assert_file "$CASE_ROOT/tv/Partial/title_t01.mkv"
run_case unicode "1\nC\n2\n0\nAmélie & Léon (2001)\nRIP\nA\n" positive 0; assert_file "$CASE_ROOT/movies/Amélie & Léon (2001)/Amélie & Léon (2001).mkv"
run_case eof '1\n' positive 0; assert_contains 'Cancelled. Nothing was ripped.'

missing="$WORK/no-device"
set +e
out=$(printf '3\n' | DISC_INGEST_MAKEMKV="$FAKE" DISC_INGEST_DEVICE="$missing" DISC_INGEST_MOVIES_ROOT="$WORK" DISC_INGEST_TV_ROOT="$WORK" "$SCRIPT" 2>&1); rc=$?
set -e
[[ $rc == 1 && $out == *'Optical drive is unavailable'* ]] || { printf 'FAIL drive unavailable\n' >&2; fail=$((fail + 1)); }

printf 'Passed: %d; failed: %d\n' "$pass" "$fail"
(( fail == 0 ))
