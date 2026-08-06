#!/bin/bash

set -e


APP_NAME="boot-switcher"

INSTALL_DIR="/opt/$APP_NAME"

BIN_PATH="/usr/local/bin/$APP_NAME"

DESKTOP_PATH="/usr/share/applications/$APP_NAME.desktop"

ICON_PATH="/usr/share/icons/hicolor/scalable/apps/$APP_NAME.svg"



# Find real user when running with sudo

REAL_USER=${SUDO_USER:-$USER}

REAL_HOME=$(eval echo "~$REAL_USER")



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



# Application files

if [ -d "$INSTALL_DIR" ]; then

    rm -rf "$INSTALL_DIR"

    success "Removed application files"

else

    warning "Application directory not found"

fi



# Terminal command

if [ -f "$BIN_PATH" ]; then

    rm -f "$BIN_PATH"

    success "Removed terminal command"

else

    warning "Terminal command not found"

fi



# Application menu entry

if [ -f "$DESKTOP_PATH" ]; then

    rm -f "$DESKTOP_PATH"

    success "Removed application menu entry"

else

    warning "Application menu entry not found"

fi



# Icon

if [ -f "$ICON_PATH" ]; then

    rm -f "$ICON_PATH"

    success "Removed application icon"

else

    warning "Application icon not found"

fi



# Desktop shortcut

if command -v xdg-user-dir >/dev/null 2>&1; then

    USER_DESKTOP=$(sudo -u "$REAL_USER" xdg-user-dir DESKTOP)/$APP_NAME.desktop

else

    USER_DESKTOP="$REAL_HOME/Desktop/$APP_NAME.desktop"

fi



if [ -f "$USER_DESKTOP" ]; then

    rm -f "$USER_DESKTOP"

    success "Removed desktop shortcut"

else

    warning "Desktop shortcut not found"

fi



# Refresh desktop/icon caches

if command -v update-desktop-database >/dev/null 2>&1; then

    update-desktop-database /usr/share/applications >/dev/null 2>&1 || true

fi



if command -v gtk-update-icon-cache >/dev/null 2>&1; then

    gtk-update-icon-cache /usr/share/icons/hicolor >/dev/null 2>&1 || true

fi



echo
echo -e "${GREEN}Boot Switcher uninstalled successfully.${RESET}"
echo