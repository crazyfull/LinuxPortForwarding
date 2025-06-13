#!/bin/bash

# مسیر نصب
TARGET_DIR="/etc/DropBearTunnel"
TARGET_FILE="$TARGET_DIR/DropBearTunnel"
DOWNLOAD_URL="https://github.com/crazyfull/LinuxPortForwarding/releases/download/%23version1/DropBearT"

# create directory
if [ ! -d "$TARGET_DIR" ]; then
    mkdir -p "$TARGET_DIR"
    if [ $? -ne 0 ]; then
        echo "❌ error on create folder $TARGET_DIR"
        exit 1
    fi
fi

# downloading
curl -L "$DOWNLOAD_URL" -o "$TARGET_FILE"
if [ $? -ne 0 ]; then
    echo "❌ error on download $DOWNLOAD_URL"
    exit 1
fi

# set access
chmod +x "$TARGET_FILE"

# exec
"$TARGET_FILE -install"
