#!/bin/bash

# Snackbar Launch Wrapper
# This script launches Snackbar without building

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Launch Snackbar without building
"$SCRIPT_DIR/launch.sh"
