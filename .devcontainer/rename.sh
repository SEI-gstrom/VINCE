#!/bin/bash
# rename.sh - Rename this dev container project (folder + Docker resources)
# Run from the HOST terminal (outside the container).
#
# Usage: .devcontainer/rename.sh <new-name>

# --- Helpers ---

usage() {
    echo "Usage: $(basename "$0") <new-name>"
    echo ""
    echo "  Renames the project folder and deletes the old Docker container"
    echo "  and volumes. They will be recreated when you reopen in VS Code."
    echo ""
    echo "  Must be run from the host terminal (outside the container)."
    exit 1
}

# --- Argument parsing ---

if [ $# -ne 1 ]; then
    usage
fi

NEW_NAME="$1"

# Validate folder name
if [ -z "$NEW_NAME" ] \
    || [[ "$NEW_NAME" == *"/"* ]] \
    || [[ "$NEW_NAME" == .* ]] \
    || [[ "$NEW_NAME" == -* ]] \
    || [[ "$NEW_NAME" == *" "* ]]; then
    echo "Error: '$NEW_NAME' is not a valid folder name."
    echo "  Must not contain '/' or spaces, or start with '-' or '.'"
    exit 1
fi

# Check docker is available
if ! command -v docker &>/dev/null; then
    echo "Error: 'docker' is not in PATH. This script must be run from the host."
    exit 1
fi

# --- Derive names ---

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OLD_NAME="$(basename "$PROJECT_DIR")"
PARENT_DIR="$(dirname "$PROJECT_DIR")"
NEW_PROJECT_DIR="${PARENT_DIR}/${NEW_NAME}"

if [ "$OLD_NAME" = "$NEW_NAME" ]; then
    echo "New name is the same as the current name. Nothing to do."
    exit 0
fi

OLD_CONTAINER="$OLD_NAME"
OLD_VOL_CLAUDE="${OLD_NAME}-claude-data"
OLD_VOL_HISTORY="${OLD_NAME}-shell-history"

# --- Pre-flight checks ---

if [ -e "$NEW_PROJECT_DIR" ]; then
    echo "Error: '$NEW_PROJECT_DIR' already exists."
    exit 1
fi

if docker inspect --type container "$NEW_NAME" &>/dev/null; then
    echo "Error: A Docker container named '$NEW_NAME' already exists."
    exit 1
fi

for vol in "${NEW_NAME}-claude-data" "${NEW_NAME}-shell-history"; do
    if docker volume inspect "$vol" &>/dev/null; then
        echo "Error: Docker volume '$vol' already exists."
        exit 1
    fi
done

# Probe which old resources exist
CONTAINER_EXISTS=false
docker inspect --type container "$OLD_CONTAINER" &>/dev/null && CONTAINER_EXISTS=true

VOL_CLAUDE_EXISTS=false
docker volume inspect "$OLD_VOL_CLAUDE" &>/dev/null && VOL_CLAUDE_EXISTS=true

VOL_HISTORY_EXISTS=false
docker volume inspect "$OLD_VOL_HISTORY" &>/dev/null && VOL_HISTORY_EXISTS=true

# --- Confirmation prompt ---

echo ""
echo "This will:"
echo "  Rename folder: $OLD_NAME -> $NEW_NAME"

if [ "$CONTAINER_EXISTS" = true ]; then
    echo "  Delete container: $OLD_CONTAINER"
fi
if [ "$VOL_CLAUDE_EXISTS" = true ]; then
    echo "  Delete volume: $OLD_VOL_CLAUDE"
fi
if [ "$VOL_HISTORY_EXISTS" = true ]; then
    echo "  Delete volume: $OLD_VOL_HISTORY"
fi

echo ""
echo "The container and volumes will be recreated when you reopen in VS Code."
echo ""
read -r -p "Proceed? [y/N] " response
case "$response" in
    [yY]|[yY][eE][sS]) ;;
    *)
        echo "Aborted."
        exit 0
        ;;
esac

echo ""

# --- Delete Docker resources (before folder rename so we can exit cleanly on failure) ---

if [ "$CONTAINER_EXISTS" = true ]; then
    # Stop if running
    CONTAINER_STATUS="$(docker inspect --format='{{.State.Status}}' "$OLD_CONTAINER" 2>/dev/null)"
    if [ "$CONTAINER_STATUS" = "running" ]; then
        echo "Stopping container '$OLD_CONTAINER'..."
        if ! docker stop "$OLD_CONTAINER" &>/dev/null; then
            echo "Error: Failed to stop container '$OLD_CONTAINER'."
            exit 1
        fi
    fi

    echo "Removing container '$OLD_CONTAINER'..."
    if ! docker rm "$OLD_CONTAINER" &>/dev/null; then
        echo "Error: Failed to remove container '$OLD_CONTAINER'."
        exit 1
    fi
fi

if [ "$VOL_CLAUDE_EXISTS" = true ]; then
    echo "Removing volume '$OLD_VOL_CLAUDE'..."
    if ! docker volume rm "$OLD_VOL_CLAUDE" &>/dev/null; then
        echo "Error: Failed to remove volume '$OLD_VOL_CLAUDE'."
        exit 1
    fi
fi

if [ "$VOL_HISTORY_EXISTS" = true ]; then
    echo "Removing volume '$OLD_VOL_HISTORY'..."
    if ! docker volume rm "$OLD_VOL_HISTORY" &>/dev/null; then
        echo "Error: Failed to remove volume '$OLD_VOL_HISTORY'."
        exit 1
    fi
fi

# --- Rename folder (last step) ---

echo "Renaming folder: $OLD_NAME -> $NEW_NAME"
if ! mv "$PROJECT_DIR" "$NEW_PROJECT_DIR"; then
    echo "Error: Failed to rename folder."
    echo "Docker resources were already deleted. They will be recreated"
    echo "when you reopen the project in VS Code."
    exit 1
fi

# --- Done ---

echo ""
echo "Renamed: $OLD_NAME -> $NEW_NAME"
echo ""
echo "Open the project in VS Code to create the new container:"
echo ""
echo "  code $NEW_PROJECT_DIR"
echo ""
