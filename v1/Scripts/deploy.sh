#!/bin/bash

# deploy.sh
# Deploy Snackbar to Applications folder

set -e

echo "🚀 Deploying Snackbar..."

# Build the app
./Scripts/build-snackbar.sh

# Copy to Applications folder
cp -r build/Release/Snackbar.app /Applications/

echo "🎉 Snackbar deployed to /Applications/Snackbar.app"
