#!/bin/bash
# Bump Snackbar version

VERSION=$1

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version> (e.g., 1.0.1)"
    exit 1
fi

# Update version in project.pbxproj
sed -i '' "s/MARKETING_VERSION = .*/MARKETING_VERSION = $VERSION;/" Snackbar.xcodeproj/project.pbxproj

# Commit and tag
git add Snackbar.xcodeproj/project.pbxproj
git commit -m "chore: bump version to $VERSION" --trailer "Co-authored-by: Junie <junie@jetbrains.com>"
git tag "v$VERSION"
git push origin main --tags

echo "✅ Version bumped to $VERSION, tag v$VERSION created"
