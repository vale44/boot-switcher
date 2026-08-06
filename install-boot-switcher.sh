#!/bin/bash

set -e

APP_NAME="boot-switcher"

REPO="https://github.com/vale44/boot-switcher/archive/refs/heads/main.tar.gz"

INSTALL_DIR="/opt/$APP_NAME"
BIN_PATH="/usr/local/bin/$APP_NAME"
DESKTOP_PATH="/usr/share/applications/$APP_NAME.desktop"
ICON_PATH="/usr/share/icons/hicolor/scalable/apps/$APP_NAME.svg"

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
RESET="\033[0m"


success() {
    echo -e "${GREEN}✓ $1${RESET}"
}

warning() {
    echo -e "${YELLOW}! $1${RESET}"
}

error() {
    echo -e "${RED}✗ $1${RESET}"
}


echo
echo "Boot Switcher installer"
echo "======================="
echo


if [ "$EUID" -ne 0 ]; then

    error "Please run this installer with sudo"

    exit 1

fi


if [ ! -d /sys/firmware/efi ]; then

    error "UEFI firmware not detected"
    echo "Boot Switcher requires UEFI."

    exit 1

fi


success "UEFI firmware detected"



echo
echo "Checking dependencies..."
echo


install_package() {

    PACKAGE="$1"


    if command -v apt >/dev/null 2>&1; then

        apt update
        apt install -y "$PACKAGE"


    elif command -v dnf >/dev/null 2>&1; then

        dnf install -y "$PACKAGE"


    elif command -v pacman >/dev/null 2>&1; then

        pacman -Sy --noconfirm "$PACKAGE"


    elif command -v zypper >/dev/null 2>&1; then

        zypper install -y "$PACKAGE"


    else

        error "Unsupported package manager"

        exit 1

    fi

}



check_command() {

    CMD="$1"
    PACKAGE="$2"


    if command -v "$CMD" >/dev/null 2>&1; then

        success "$CMD found"

    else

        warning "$CMD missing - installing"

        install_package "$PACKAGE"


        if command -v "$CMD" >/dev/null 2>&1; then

            success "$CMD installed"

        else

            error "Could not install $CMD"

            exit 1

        fi

    fi

}



check_command python3 python3
check_command efibootmgr efibootmgr
check_command pkexec policykit-1



if ! python3 -m venv --help >/dev/null 2>&1; then

    warning "Python venv missing"


    if command -v apt >/dev/null 2>&1; then

        apt install -y python3-venv

    else

        error "Please install Python venv manually"

        exit 1

    fi

fi


success "Python virtual environment support found"



echo
echo "Installing Boot Switcher..."
echo


TEMP_DIR=$(mktemp -d)


echo "Downloading files..."

curl -L "$REPO" -o "$TEMP_DIR/source.tar.gz"


mkdir -p "$TEMP_DIR/extract"


tar -xzf "$TEMP_DIR/source.tar.gz" \
-C "$TEMP_DIR/extract"


SOURCE_DIR=$(find "$TEMP_DIR/extract" \
-maxdepth 1 \
-type d \
-name "boot-switcher-*")



rm -rf "$INSTALL_DIR"

mkdir -p "$INSTALL_DIR"



cp "$SOURCE_DIR/run.py" "$INSTALL_DIR/"
cp -r "$SOURCE_DIR/src" "$INSTALL_DIR/"
cp "$SOURCE_DIR/requirements.txt" "$INSTALL_DIR/"


success "Files copied"



# Icon installation

if [ -f "$SOURCE_DIR/assets/$APP_NAME.svg" ]; then

    mkdir -p "$(dirname "$ICON_PATH")"

    cp "$SOURCE_DIR/assets/$APP_NAME.svg" "$ICON_PATH"

    chmod 644 "$ICON_PATH"

    success "Application icon installed"

else

    warning "Icon not found"

fi



echo "Creating virtual environment..."

python3 -m venv "$INSTALL_DIR/venv"


success "Virtual environment created"



echo "Installing Python dependencies..."


"$INSTALL_DIR/venv/bin/pip" install --upgrade pip >/dev/null

"$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/requirements.txt"


success "Python dependencies installed"



# Command launcher

cat > "$BIN_PATH" <<EOF
#!/bin/bash
exec $INSTALL_DIR/venv/bin/python $INSTALL_DIR/run.py "\$@"
EOF


chmod +x "$BIN_PATH"


success "Command installed: $BIN_PATH"



# Application menu entry

cat > "$DESKTOP_PATH" <<EOF
[Desktop Entry]
Type=Application
Name=Boot Switcher
Comment=Switch EFI boot entries
Exec=$BIN_PATH
Path=$INSTALL_DIR
Icon=$APP_NAME
Terminal=false
Categories=Utility;System;
StartupNotify=true
EOF


chmod 644 "$DESKTOP_PATH"



if command -v update-desktop-database >/dev/null 2>&1; then

    update-desktop-database /usr/share/applications

fi



if command -v gtk-update-icon-cache >/dev/null 2>&1; then

    gtk-update-icon-cache /usr/share/icons/hicolor

fi



success "Application menu entry created"



# Optional desktop shortcut

echo

read -p "Create desktop shortcut? (y/n): " answer


if [[ "$answer" == "y" || "$answer" == "Y" ]]; then


    if [ -n "$SUDO_USER" ]; then

        REAL_USER="$SUDO_USER"
        REAL_HOME=$(eval echo "~$REAL_USER")

    else

        REAL_USER=$(whoami)
        REAL_HOME="$HOME"

    fi



    if command -v xdg-user-dir >/dev/null 2>&1; then

        DESKTOP_DIR=$(sudo -u "$REAL_USER" xdg-user-dir DESKTOP)

    else

        DESKTOP_DIR="$REAL_HOME/Desktop"

    fi



    if [ -d "$DESKTOP_DIR" ]; then


        cp "$DESKTOP_PATH" \
        "$DESKTOP_DIR/$APP_NAME.desktop"


        chown "$REAL_USER:$REAL_USER" \
        "$DESKTOP_DIR/$APP_NAME.desktop"


        chmod +x "$DESKTOP_DIR/$APP_NAME.desktop"


        if command -v gio >/dev/null 2>&1; then

            sudo -u "$REAL_USER" gio set \
            "$DESKTOP_DIR/$APP_NAME.desktop" \
            metadata::trusted true

        fi


        success "Desktop shortcut created"


    else

        warning "Desktop folder not found, skipping shortcut"

    fi

fi



rm -rf "$TEMP_DIR"



echo
echo -e "${GREEN}Installation complete!${RESET}"
echo
echo "Run with:"
echo
echo "    boot-switcher"
echo