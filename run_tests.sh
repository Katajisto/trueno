#!/bin/bash
# Runs every test tier and exits nonzero if any of them fail.
#
#   ./run_tests.sh              # everything that can run here
#   ./run_tests.sh unit         # compile-time tests only (no display needed)
#   ./run_tests.sh engine       # engine tiers only
#   ./run_tests.sh game         # game tiers only
#
# Tiers:
#   test_engine    engine unit tests   compile-time #run, builds against test_game/
#   test_game      game unit tests     compile-time #run, builds against game/
#   test_exe_engine  engine exe tests  builds then runs ./first against test_game/
#   test_exe_game    game exe tests    builds then runs ./first against game/
#
# The unit tiers report through the compiler's exit code. The exe tiers run the
# real app, so they need a display and are wrapped in a hard timeout.

set -uo pipefail
cd "$(dirname "$0")"

JAI="${JAI:-$HOME/bin/jai/bin/jai-linux}"
EXE_TIMEOUT="${EXE_TIMEOUT:-180}"   # seconds per exe-test binary, kills a true freeze

FILTER="${1:-all}"

if [ ! -x "$JAI" ]; then
    echo "error: Jai compiler not found at '$JAI' (override with JAI=/path/to/jai)" >&2
    exit 1
fi

# The game/ directory is not in the repo, so the game tiers are skipped rather
# than failed on a checkout that does not have it.
HAVE_GAME=0
[ -f game/game.jai ] && HAVE_GAME=1

# Exe tests open a real window. Prefer a live display, fall back to Xvfb.
XVFB=()
NO_DISPLAY=0
if [ -z "${DISPLAY:-}" ]; then
    if command -v xvfb-run >/dev/null 2>&1; then
        XVFB=(xvfb-run -a)
    else
        NO_DISPLAY=1
    fi
fi

PASSED=(); FAILED=(); SKIPPED=()

want() {
    case "$FILTER" in
        all)    return 0 ;;
        unit)   [[ "$1" != *exe* ]] ;;
        engine) [[ "$1" == *engine* ]] ;;
        game)   [[ "$1" == *game* && "$1" != *engine* ]] ;;
        *)      echo "error: unknown filter '$FILTER' (use all|unit|engine|game)" >&2; exit 1 ;;
    esac
}

run_unit_tier() {
    local flag="$1"
    echo ""
    echo "=============================================================="
    echo "  $flag (compile-time)"
    echo "=============================================================="
    if "$JAI" first.jai - "$flag"; then
        PASSED+=("$flag")
    else
        FAILED+=("$flag")
    fi
}

run_exe_tier() {
    local flag="$1"
    echo ""
    echo "=============================================================="
    echo "  $flag (builds, then runs the app)"
    echo "=============================================================="

    if ! "$JAI" first.jai - "$flag"; then
        echo "[$flag] build failed"
        FAILED+=("$flag (build)")
        return
    fi

    timeout --foreground "$EXE_TIMEOUT" "${XVFB[@]}" ./first
    local status=$?
    if [ $status -eq 0 ]; then
        PASSED+=("$flag")
    elif [ $status -eq 124 ]; then
        echo "[$flag] hung and was killed after ${EXE_TIMEOUT}s"
        FAILED+=("$flag (hung)")
    else
        echo "[$flag] exited $status"
        FAILED+=("$flag")
    fi
}

for flag in test_engine test_game; do
    want "$flag" || continue
    if [ "$flag" = "test_game" ] && [ "$HAVE_GAME" -eq 0 ]; then
        SKIPPED+=("$flag (no game/ directory)")
        continue
    fi
    run_unit_tier "$flag"
done

for flag in test_exe_engine test_exe_game; do
    want "$flag" || continue
    if [ "$NO_DISPLAY" -eq 1 ]; then
        SKIPPED+=("$flag (no DISPLAY and no xvfb-run)")
        continue
    fi
    if [ "$flag" = "test_exe_game" ] && [ "$HAVE_GAME" -eq 0 ]; then
        SKIPPED+=("$flag (no game/ directory)")
        continue
    fi
    run_exe_tier "$flag"
done

echo ""
echo "=============================================================="
echo "  Summary"
echo "=============================================================="
for t in ${PASSED[@]+"${PASSED[@]}"};  do echo "  PASS     $t"; done
for t in ${SKIPPED[@]+"${SKIPPED[@]}"}; do echo "  SKIP     $t"; done
for t in ${FAILED[@]+"${FAILED[@]}"};  do echo "  FAIL     $t"; done

if [ ${#FAILED[@]} -ne 0 ]; then
    echo ""
    echo "${#FAILED[@]} tier(s) failed."
    exit 1
fi

# A run where everything was skipped is not a pass.
if [ ${#PASSED[@]} -eq 0 ]; then
    echo ""
    echo "Nothing ran."
    exit 1
fi

echo ""
echo "All ${#PASSED[@]} tier(s) passed."
