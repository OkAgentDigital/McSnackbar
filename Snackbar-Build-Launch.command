#!/bin/bash

# Snackbar Build and Launch Wrapper
# This script builds and launches Snackbar

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Launch Snackbar with building
"$SCRIPT_DIR/launch.sh" --build
