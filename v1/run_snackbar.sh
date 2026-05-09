#!/bin/zsh

# 🎯 Snackbar Launcher (Default: Silent Mode)
# By default, launches Snackbar without showing a Terminal window.
# Uses the SnackbarSilent.app wrapper (LSUIElement = true) for a clean experience.
#
# Usage:
#   ./run_snackbar.sh              # Build (if needed) and launch silently
#   ./run_snackbar.sh --verbose    # Launch with terminal visible (debug mode)
#   ./run_snackbar.sh --stop       # Kill all Snackbar processes

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

case "${1:-start}" in
    start|--silent)
        exec "$SCRIPT_DIR/run_snackbar_silent.sh" start
        ;;
    verbose|--verbose|--raw)
        exec "$SCRIPT_DIR/run_snackbar_verbose.sh"
        ;;
    stop|--stop)
        exec "$SCRIPT_DIR/run_snackbar_silent.sh" stop
        ;;
    *)
        echo "Usage: $0 {start|--silent|verbose|--verbose|stop|--stop}"
        exit 1
        ;;
esac
