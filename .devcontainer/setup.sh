#!/bin/bash
# Claude Code Dev Container Setup Script for macOS/Linux

PROFILE="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEVENV="$SCRIPT_DIR/devcontainer.env"

# initial setup
if [ ! -f "$DEVENV" ]; then

    EXAMPLE="$SCRIPT_DIR/profile.env.$PROFILE"

    # select profile if example not valid
    if [ ! -f "$EXAMPLE" ]; then
        echo ""
        echo "  Select Claude Profile"
        echo ""
        profiles=$(find "$SCRIPT_DIR" -maxdepth 1 -name "profile.env.*" | awk -F. '{print $NF}' | sort)
        select profile in $profiles
        do
            EXAMPLE="$SCRIPT_DIR/profile.env.$profile"
            if [ -f "$EXAMPLE" ]; then
                break
            fi
        done
    fi

    cp "$EXAMPLE" "$DEVENV"
    rm "$SCRIPT_DIR"/profile.env.*
fi

echo ""
echo "  Configure Amazon Bedrock Access"
echo ""

read -p "AWS Access Key ID: " KEY_ID
[ -z "$KEY_ID" ] && echo "ERROR: Access Key ID required." && exit 1

# Read secret with asterisk feedback
echo -n "AWS Secret Access Key: "
SECRET=""
while IFS= read -r -s -n1 char; do
    if [[ -z "$char" ]]; then  # Enter pressed
        break
    elif [[ "$char" == $'\x7f' || "$char" == $'\x08' ]]; then  # Backspace
        if [[ -n "$SECRET" ]]; then
            SECRET="${SECRET%?}"
            echo -ne '\b \b'
        fi
    else
        SECRET+="$char"
        echo -n '*'
    fi
done
echo ""
[ -z "$SECRET" ] && echo "ERROR: Secret Access Key required." && exit 1

# update api key
sed -i '' \
    -e "s|\(AWS_ACCESS_KEY_ID=\).*|\1$KEY_ID|" \
    -e "s|\(AWS_SECRET_ACCESS_KEY=\).*|\1$SECRET|" \
    "$DEVENV"

echo ""
echo "Created: .devcontainer/devcontainer.env"
echo ""
echo "Next steps:"
echo "  If outside container: Open in VS Code → F1 → 'Dev Containers: Reopen in Container'"
echo "  If inside container:  F1 → 'Dev Containers: Rebuild Container'"
echo ""
