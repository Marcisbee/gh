# dl.sh

#!/bin/bash

# Ensure TMP_DIR is cleaned up on exit
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Validate repo name function
validate_repo_name() {
  if [[ ! "$1" =~ ^[^/]+/[^/]+$ ]]; then
    echo "Invalid repo name. It should be in the format 'owner/repo'."
    exit 1
  fi
}

# Parse arguments
REPO=""
RELEASE_TAG="latest"
BINARY_NAME_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --repo)
      REPO="$2"
      shift 2
      ;;
    --tag)
      RELEASE_TAG="$2"
      shift 2
      ;;
    --name)
      BINARY_NAME_OVERRIDE="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

# Validate repo name
if [[ -z "$REPO" ]]; then
  echo "Repo name is required. Use --repo <owner/repo>."
  exit 1
fi
validate_repo_name "$REPO"

# Set API URL
if [[ "$RELEASE_TAG" == "latest" ]]; then
  API_URL="https://api.github.com/repos/$REPO/releases/latest"
else
  API_URL="https://api.github.com/repos/$REPO/releases/tags/$RELEASE_TAG"
fi

OUTPUT_DIR="$(pwd)"
BINARY_NAME="$(basename "$REPO")"
if [[ -n "$BINARY_NAME_OVERRIDE" ]]; then
  BINARY_NAME="$BINARY_NAME_OVERRIDE"
fi
TMP_DIR=$(mktemp -d -t sh-installer-0-1-0-XXXX)

# Detect platform and architecture
PLATFORM="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$ARCH" in
  x86_64|amd64) ARCH="(x86_64|amd64)" ;;
  armv7*) ARCH="armv7" ;;
  aarch64|arm64) ARCH="(aarch64|arm64)" ;;
  *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$PLATFORM" in
  darwin) PLATFORM="(darwin|mac|macos)" ;;
  linux) PLATFORM="linux" ;;
  *) echo "Unsupported platform: $PLATFORM"; exit 1 ;;
esac

# Fetch release information
echo "Looking for $REPO ($RELEASE_TAG)"
RELEASE_INFO=$(curl -sSL -H "Accept: application/vnd.github.v3+json" "$API_URL")

if [[ $(echo "$RELEASE_INFO" | jq -r '.message') == "Not Found" ]]; then
  echo "Release not found for $REPO with tag $RELEASE_TAG."
  exit 1
fi

# Extract the asset download URL
echo "Searching for binary"
ASSET_URL=$(echo "$RELEASE_INFO" | grep -Eo '"browser_download_url": "[^"]+"' \
  | grep -iE "$PLATFORM" \
  | grep -iE "$ARCH" \
  | grep -E 'https://.+/(.+\.(tar\.xz|tar\.bz|tar\.bz2|tar\.gz|tgz|gz|bz2|zip)\b[^.]|[^.]+$)' \
  | sed -E 's/.*"(https:[^"]+)".*/\1/' \
  | awk '{ print length, $0 }' | sort -n | cut -d" " -f2- | head -n 1)

if [[ -z "$ASSET_URL" ]]; then
  echo "No compatible binary found for platform: $PLATFORM, architecture: $ARCH"
  exit 1
fi

if [[ $(echo "$ASSET_URL" | wc -l) -ne 1 ]]; then
  echo "Multiple or no valid assets detected. Ensure only one matching asset exists."
  exit 1
fi

echo "Downloading $ASSET_URL"

# Extract file name from URL
FILE_NAME=$(basename "$ASSET_URL")

# Download the asset
curl --fail -# -L -o "$TMP_DIR/$FILE_NAME" "$ASSET_URL"

# Handle compressed files quietly
case "$FILE_NAME" in
  *.tar.bz|*.tar.bz2)
    tar -xjvf "$TMP_DIR/$FILE_NAME" -C "$TMP_DIR" &>/dev/null || { echo "Failed to extract $FILE_NAME"; exit 1; }
    rm "$TMP_DIR/$FILE_NAME" &>/dev/null
    ;;
  *.tar.gz|*.tgz)
    tar -xzvf "$TMP_DIR/$FILE_NAME" -C "$TMP_DIR" &>/dev/null || { echo "Failed to extract $FILE_NAME"; exit 1; }
    rm "$TMP_DIR/$FILE_NAME" &>/dev/null
    ;;
  *.tar.xz)
    tar -xJvf "$TMP_DIR/$FILE_NAME" -C "$TMP_DIR" &>/dev/null || { echo "Failed to extract $FILE_NAME"; exit 1; }
    rm "$TMP_DIR/$FILE_NAME" &>/dev/null
    ;;
  *.bz2)
    bzip2 -d "$TMP_DIR/$FILE_NAME" &>/dev/null || { echo "Failed to extract $FILE_NAME"; exit 1; }
    rm "$TMP_DIR/$FILE_NAME" &>/dev/null
    ;;
  *.gz)
    gzip -d "$TMP_DIR/$FILE_NAME" &>/dev/null || { echo "Failed to extract $FILE_NAME"; exit 1; }
    rm "$TMP_DIR/$FILE_NAME" &>/dev/null
    ;;
  *.tar)
    tar -xvf "$TMP_DIR/$FILE_NAME" -C "$TMP_DIR" &>/dev/null || { echo "Failed to extract $FILE_NAME"; exit 1; }
    rm "$TMP_DIR/$FILE_NAME" &>/dev/null
    ;;
  *.zip)
    unzip -o "$TMP_DIR/$FILE_NAME" -d "$TMP_DIR" &>/dev/null || { echo "Failed to unzip $FILE_NAME"; exit 1; }
    rm "$TMP_DIR/$FILE_NAME" &>/dev/null
    ;;
  *)
    echo "Unknown file type for $FILE_NAME, assuming binary."
    ;;
esac

# Find the largest file and treat it as the binary
DOWNLOADED_BINARY=$(find "$TMP_DIR" -type f -print0 | xargs -0 du | sort -n | tail -n 1 | cut -f 2-)
if [[ -n "$DOWNLOADED_BINARY" ]]; then
  mv "$DOWNLOADED_BINARY" "$OUTPUT_DIR/$BINARY_NAME"
  chmod +x "$OUTPUT_DIR/$BINARY_NAME"
else
  echo "Failed to locate the downloaded binary."
  exit 1
fi

echo "Installation complete."
echo "Binary located at $OUTPUT_DIR/$BINARY_NAME"
