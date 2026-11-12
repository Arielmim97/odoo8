#!/bin/bash
DESTINATION=$1
PORT=$2
CHAT=$3

if [ -z "$DESTINATION" ] || [ -z "$PORT" ] || [ -z "$CHAT" ]; then
    echo "Usage: run.sh <folder> <odoo-port> <chat-port>"
    echo "Example: run.sh odoo-one 10008 20008"
    exit 1
fi

# Clone Odoo directory
git clone --depth=1 --branch odoo8 https://github.com/Arielmim97/odoo8.git "$DESTINATION"
rm -rf "$DESTINATION/.git"

# Create PostgreSQL directory
mkdir -p "$DESTINATION/postgresql"

# Change ownership to current user and set restrictive permissions for security
sudo chown -R "$USER:$USER" "$DESTINATION"
sudo chmod -R 700 "$DESTINATION" # Only the user has access

# Check if running on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Running on macOS. Skipping inotify configuration."
else
    # System configuration
    if grep -qF "fs.inotify.max_user_watches" /etc/sysctl.conf; then
        echo $(grep -F "fs.inotify.max_user_watches" /etc/sysctl.conf)
    else
        echo "fs.inotify.max_user_watches = 524288" | sudo tee -a /etc/sysctl.conf
    fi
    sudo sysctl -p
fi

# Set ports in docker-compose.yml
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS sed syntax
    sed -i '' 's/10008/'"$PORT"'/g' "$DESTINATION/docker-compose.yml"
    sed -i '' 's/20008/'"$CHAT"'/g' "$DESTINATION/docker-compose.yml"
else
    # Linux sed syntax
    sed -i 's/10008/'"$PORT"'/g' "$DESTINATION/docker-compose.yml"
    sed -i 's/20008/'"$CHAT"'/g' "$DESTINATION/docker-compose.yml"
fi

# Set file and directory permissions after installation
find "$DESTINATION" -type f -exec chmod 644 {} \;
find "$DESTINATION" -type d -exec chmod 755 {} \;

chmod +x "$DESTINATION/entrypoint.sh"
# Postgres and the filestore run as users inside the container
chmod 777 "$DESTINATION/addons" "$DESTINATION/etc" "$DESTINATION/postgresql"

# Run Odoo
if ! is_present="$(type -p "docker-compose")" || [[ -z $is_present ]]; then
    docker compose -f "$DESTINATION/docker-compose.yml" up -d
else
    docker-compose -f "$DESTINATION/docker-compose.yml" up -d
fi

echo "Odoo started at http://localhost:$PORT | Master Password: admin | Live chat port: $CHAT"
