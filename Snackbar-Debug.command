#!/bin/bash

# Snackbar Debug Wrapper
# This script launches Snackbar in debug mode

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Launch Snackbar in debug mode
"$SCRIPT_DIR/launch.sh" --debug
