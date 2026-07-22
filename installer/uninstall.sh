#!/bin/bash

set -e


APP_NAME="boot-switcher"

INSTALL_DIR="/opt/$APP_NAME"

BIN_PATH="/usr/local/bin/$APP_NAME"

DESKTOP_PATH="/usr/share/applications/$APP_NAME.desktop"


# Find the real user when running with sudo
REAL_USER=${SUDO_USER:-$USER}

REAL_HOME=$(eval echo "~$REAL_USER")

USER_DESKTOP="$REAL_HOME/Desktop/$APP_NAME.desktop"


GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RESET="\033[0m"


success()
{
    echo -e "${GREEN}✓ $1${RESET}"
}


warning()
{
    echo -e "${YELLOW}! $1${RESET}"
}



echo
echo "Boot Switcher uninstaller"
echo "========================="
echo



if [ "$EUID" -ne 0 ]; then

    echo "Please run with sudo:"
    echo

    echo "sudo ./installer/uninstall.sh"

    exit 1

fi



echo "Removing Boot Switcher..."
echo



if [ -d "$INSTALL_DIR" ]; then

    rm -rf "$INSTALL_DIR"

    success "Removed application files"

else

    warning "Application directory not found"

fi



if [ -f "$BIN_PATH" ]; then

    rm -f "$BIN_PATH"

    success "Removed terminal command"

else

    warning "Terminal command not found"

fi



if [ -f "$DESKTOP_PATH" ]; then

    rm -f "$DESKTOP_PATH"

    success "Removed application menu entry"

else

    warning "Application menu entry not found"

fi



if [ -f "$USER_DESKTOP" ]; then

    rm -f "$USER_DESKTOP"

    success "Removed desktop shortcut"

else

    warning "Desktop shortcut not found"

fi



echo
echo -e "${GREEN}Boot Switcher uninstalled successfully.${RESET}"
echo