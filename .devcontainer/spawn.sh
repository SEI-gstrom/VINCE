#!/bin/bash

ARCHIVE_URL="https://code-alt.sei.cmu.edu/bitbucket/rest/api/latest/projects/CWD/repos/claude-dev/archive?format=zip"

# --- Argument parsing ---
TARGET_DIR=""
INIT_GIT=false

for arg in "$@"; do
    case "$arg" in
        --git|-g)
            INIT_GIT=true
            ;;
        -*)
            echo "Unknown option: $arg"
            echo "Usage: $(basename "$0") <target-directory> [--git]"
            exit 1
            ;;
        *)
            if [ -z "$TARGET_DIR" ]; then
                TARGET_DIR="$arg"
            else
                echo "Error: Unexpected argument '$arg'"
                echo "Usage: $(basename "$0") <target-directory> [--git]"
                exit 1
            fi
            ;;
    esac
done

# Print usage if no target directory provided
if [ -z "$TARGET_DIR" ]; then
    echo "Usage: $(basename "$0") <target-directory> [--git]"
    echo "Downloads a fresh copy of the claude-dev repo into the target directory."
    echo ""
    echo "Options:"
    echo "  --git, -g    Initialize a Git repository after download"
    exit 1
fi

# Check required tools
for cmd in curl unzip; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' is required but not installed."
        exit 1
    fi
done

# Only check git identity if --git is used
if [ "$INIT_GIT" = true ]; then
    if ! command -v git &>/dev/null; then
        echo "Error: 'git' is required when using --git but is not installed."
        exit 1
    fi
    if [ -z "$(git config --global user.name)" ] || [ -z "$(git config --global user.email)" ]; then
        echo "Git identity not configured. Please set your name and email:"
        echo "  git config --global user.name \"Your Name\""
        echo "  git config --global user.email \"username@sei.cmu.edu\""
        exit 1
    fi
fi

# Check target directory does not already exist
if [ -e "$TARGET_DIR" ]; then
    echo "Error: '$TARGET_DIR' already exists."
    exit 1
fi

# Create target directory
mkdir -p "$TARGET_DIR"

# Download zip to a temporary file
TMPZIP="$(mktemp /tmp/claude-dev-XXXXXX.zip)"
trap 'rm -f "$TMPZIP"' EXIT

echo "Downloading claude-dev..."
if ! curl -fsSL -o "$TMPZIP" "$ARCHIVE_URL"; then
    echo "Failed to download archive from:"
    echo "  $ARCHIVE_URL"
    rmdir "$TARGET_DIR" 2>/dev/null
    exit 1
fi

# Extract into target directory
if ! unzip -q "$TMPZIP" -d "$TARGET_DIR"; then
    echo "Failed to extract archive."
    rm -rf "$TARGET_DIR"
    exit 1
fi

# Run setup
cd "$TARGET_DIR"
.devcontainer/setup.sh

# Optional git init
if [ "$INIT_GIT" = true ]; then
    git init && git add -A && git commit -m "Initial commit"
    echo ""
    echo "claude-dev repo spawned to '$TARGET_DIR' with a clean Git repository."
else
    echo ""
    echo "claude-dev repo spawned to '$TARGET_DIR'."
fi

echo ""
echo "Now launch Visual Studio Code to build your new dev container:"
echo ""
echo "  code $TARGET_DIR"
echo ""
