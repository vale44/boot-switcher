#!/bin/bash

set -e

APP_NAME="boot-switcher"
REPO="https://github.com/vale44/boot-switcher/archive/refs/heads/main.tar.gz"

INSTALL_DIR="/opt/$APP_NAME"
BIN_PATH="/usr/local/bin/$APP_NAME"
DESKTOP_PATH="/usr/share/applications/$APP_NAME.desktop"

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
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

        error "Please install python3-venv manually"

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


tar -xzf "$TEMP_DIR/source.tar.gz" -C "$TEMP_DIR/extract"



SOURCE_DIR=$(find "$TEMP_DIR/extract" -maxdepth 1 -type d -name "boot-switcher-*")



rm -rf "$INSTALL_DIR"

mkdir -p "$INSTALL_DIR"



cp -r "$SOURCE_DIR/run.py" "$INSTALL_DIR/"
cp -r "$SOURCE_DIR/src" "$INSTALL_DIR/"
cp "$SOURCE_DIR/requirements.txt" "$INSTALL_DIR/"



success "Files copied"



echo "Creating virtual environment..."

python3 -m venv "$INSTALL_DIR/venv"


success "Virtual environment created"



echo "Installing Python dependencies..."

"$INSTALL_DIR/venv/bin/pip" install --upgrade pip >/dev/null

"$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/requirements.txt"



success "Python dependencies installed"



cat > "$BIN_PATH" <<EOF
#!/bin/bash
exec $INSTALL_DIR/venv/bin/python $INSTALL_DIR/run.py "\$@"
EOF


chmod +x "$BIN_PATH"


success "Command installed: $BIN_PATH"



cat > "$DESKTOP_PATH" <<EOF
[Desktop Entry]
Type=Application
Name=Boot Switcher
Comment=Switch EFI boot entries
Exec=$BIN_PATH
Path=$INSTALL_DIR
Icon=computer
Terminal=false
Categories=Utility;
StartupNotify=true
EOF


chmod +x "$DESKTOP_PATH"


success "Application menu entry created"



rm -rf "$TEMP_DIR"



echo
echo "Installation complete!"
echo
echo "Run with:"
echo
echo "    boot-switcher"
echo