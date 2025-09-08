#!/bin/bash -e
# This script downloads the latest WordPress, validates its version against a
# pinned major version, and creates separate deployment packages for each tier.

# --- Environment Setup ---
# Use a temporary directory for clean extraction and packaging.
WORK_DIR=$(mktemp -d)
echo "--- Using temporary directory: $WORK_DIR ---"

# The GITHUB_WORKSPACE variable is provided by GitHub Actions. We default to '.'
# for local testing and set the output directory for the final artifacts.
DIST_DIR="${GITHUB_WORKSPACE:-.}/dist"
PINNED_VERSION_FILE="${GITHUB_WORKSPACE:-.}/.wp-version"
mkdir -p "$DIST_DIR"


# --- Version Validation ---
echo "--- Fetching and Validating WordPress Version ---"
if [ ! -f "$PINNED_VERSION_FILE" ]; then
    echo "Error: Pinned version file not found at $PINNED_VERSION_FILE" >&2
    exit 1
fi
PINNED_MAJOR_VERSION=$(cat "$PINNED_VERSION_FILE")
echo "--- Approved Major Version is Pinned to: $PINNED_MAJOR_VERSION.x ---"

LATEST_VERSION=$(curl -s https://api.wordpress.org/core/version-check/1.7/ | jq -r '.offers[0].version')

if [ -z "$LATEST_VERSION" ]; then
  echo "Error: Could not determine latest WordPress version from API." >&2
  exit 1
fi
echo "--- Latest available WordPress version is: $LATEST_VERSION ---"
LATEST_MAJOR_VERSION=$(echo "$LATEST_VERSION" | cut -d'.' -f1)

# THE SAFETY CHECK: Halt the pipeline if the latest version is a new major release.
if [ "$LATEST_MAJOR_VERSION" != "$PINNED_MAJOR_VERSION" ]; then
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
  echo "!!                      APPROVAL REQUIRED                   !!" >&2
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
  echo "Error: Latest WordPress version ($LATEST_VERSION) is a new major release." >&2
  echo "This pipeline is pinned to major version $PINNED_MAJOR_VERSION.x." >&2
  echo "To approve this upgrade, a developer must update the '.wp-version' file in the repository." >&2
  exit 1
else
  echo "--- Version check passed. Proceeding with minor/patch update. ---"
fi

# Save the discovered version to a file for the Terraform pipeline to use.
echo "$LATEST_VERSION" > "$DIST_DIR/cms_version.txt"
echo "--- Saved version $LATEST_VERSION to dist/cms_version.txt ---"


# --- Download & Extract ---
echo "--- Downloading WordPress v$LATEST_VERSION ---"
wget "https://wordpress.org/wordpress-$LATEST_VERSION.tar.gz" -O "$WORK_DIR/wordpress.tar.gz"
tar -xzf "$WORK_DIR/wordpress.tar.gz" -C "$WORK_DIR"
cd "$WORK_DIR/wordpress"


# --- Create Tier-Specific Packages ---
echo "--- Creating Web Tier Package (web_package.tar.gz) ---"
# This package contains only the 'wp-content' directory.
tar -czf "$WORK_DIR/web_package.tar.gz" wp-content
echo "Web package created."

echo "--- Creating App Tier Package (app_package.tar.gz) ---"
# This package contains all core PHP files, excluding 'wp-content'.
tar -czf "$WORK_DIR/app_package.tar.gz" --exclude='wp-content' .
echo "App package created."


# --- Finalize ---
echo "--- Moving final packages to $DIST_DIR ---"
mv "$WORK_DIR/web_package.tar.gz" "$DIST_DIR/"
mv "$WORK_DIR/app_package.tar.gz" "$DIST_DIR/"

# Clean up the temporary working directory
rm -rf "$WORK_DIR"

echo "--- Packaging complete. Artifacts are ready in the dist/ directory. ---"
