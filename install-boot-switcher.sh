#!/bin/bash

set -e

APP_NAME="boot-switcher"
REPO="https://github.com/YOURNAME/boot-switcher.git"

TEMP_DIR=$(mktemp -d)

echo "Boot Switcher installer"
echo "======================="
echo

echo "Downloading Boot Switcher..."

if ! command -v git >/dev/null 2>&1; then
    echo "Git is required to download Boot Switcher."

    if command -v apt >/dev/null 2>&1; then
        sudo apt update
        sudo apt install -y git
    else
        echo "Please install git manually and run again."
        exit 1
    fi
fi


git clone "$REPO" "$TEMP_DIR/$APP_NAME"


echo
echo "Starting installer..."
echo


cd "$TEMP_DIR/$APP_NAME"


sudo ./installer/install.sh


echo
echo "Cleaning temporary files..."

rm -rf "$TEMP_DIR"


echo
echo "Boot Switcher installation complete."