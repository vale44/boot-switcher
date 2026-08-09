
#!/bin/bash

set -e

APP_NAME="boot-switcher"
INSTALL_DIR="/opt/$APP_NAME"
BIN_PATH="/usr/local/bin/$APP_NAME"
DESKTOP_PATH="/usr/share/applications/$APP_NAME.desktop"
ICON_DIR="/usr/share/icons/hicolor/scalable/apps"
ICON_PATH="$ICON_DIR/$APP_NAME.svg"

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RESET="\033[0m"

success() {
    echo -e "${GREEN}✓ $1${RESET}"
}

warning() {
    echo -e "${YELLOW}! $1${RESET}"
}

echo
echo "Boot Switcher local installer"
echo "============================="
echo
echo "Installing from the current cloned repository."
echo

if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo:"
    echo
    echo "    sudo ./installer/dev-install.sh"
    echo
    exit 1
fi

# Find the repository root.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Find the real user when running with sudo.
REAL_USER=${SUDO_USER:-$USER}

echo "Checking dependencies..."
echo

if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 is required."
    exit 1
fi
success "python3 found"

if ! python3 -m venv --help >/dev/null 2>&1; then
    echo "Error: Python virtual environment support is required."
    echo "Install your distribution's python3-venv package and try again."
    exit 1
fi
success "Python virtual environment support found"

if ! command -v efibootmgr >/dev/null 2>&1; then
    echo "Error: efibootmgr is required."
    exit 1
fi
success "efibootmgr found"

if ! command -v pkexec >/dev/null 2>&1; then
    echo "Error: pkexec is required."
    exit 1
fi
success "pkexec found"

if [ ! -d /sys/firmware/efi ]; then
    echo
    echo "Error: UEFI firmware was not detected."
    echo "Boot Switcher requires a UEFI-booted Linux system."
    exit 1
fi
success "UEFI firmware detected"

echo
echo "Installing Boot Switcher..."
echo

# Validate required project files.
if [ ! -f "$PROJECT_DIR/run.py" ]; then
    echo "Error: run.py was not found."
    echo "Make sure this script is being run from a complete Boot Switcher repository."
    exit 1
fi

if [ ! -f "$PROJECT_DIR/requirements.txt" ]; then
    echo "Error: requirements.txt was not found."
    exit 1
fi

if [ ! -d "$PROJECT_DIR/src/boot_switcher" ]; then
    echo "Error: application source directory was not found."
    exit 1
fi

if [ ! -f "$PROJECT_DIR/assets/boot-switcher.svg" ]; then
    echo "Error: application icon was not found."
    exit 1
fi

echo "Copying files..."

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

cp "$PROJECT_DIR/run.py" "$INSTALL_DIR/"
cp "$PROJECT_DIR/requirements.txt" "$INSTALL_DIR/"
cp -r "$PROJECT_DIR/src" "$INSTALL_DIR/"
cp -r "$PROJECT_DIR/assets" "$INSTALL_DIR/"

success "Files copied"

echo "Creating virtual environment..."

python3 -m venv "$INSTALL_DIR/venv"

success "Virtual environment created"

echo "Installing Python dependencies..."

"$INSTALL_DIR/venv/bin/pip" install --upgrade pip >/dev/null
"$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/requirements.txt"

success "Python dependencies installed"

echo "Installing command..."

cat > "$BIN_PATH" <<EOF
#!/bin/bash
exec "$INSTALL_DIR/venv/bin/python" "$INSTALL_DIR/run.py" "\$@"
EOF

chmod +x "$BIN_PATH"

success "Command installed: $BIN_PATH"

echo "Installing application icon..."

mkdir -p "$ICON_DIR"
cp "$INSTALL_DIR/assets/boot-switcher.svg" "$ICON_PATH"

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi

success "Application icon installed"

echo "Creating application menu entry..."

cat > "$DESKTOP_PATH" <<EOF
[Desktop Entry]
Type=Application
Name=Boot Switcher
Comment=Switch EFI boot entries
Exec=$BIN_PATH
Path=$INSTALL_DIR
Icon=$ICON_PATH
Terminal=false
Categories=Utility;System;
StartupNotify=true
EOF

chmod 644 "$DESKTOP_PATH"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
fi

success "Application menu entry created"

echo
echo "Creating desktop shortcut..."

DESKTOP_DIR="$(sudo -u "$REAL_USER" xdg-user-dir DESKTOP 2>/dev/null || true)"

if [ -z "$DESKTOP_DIR" ] || [ ! -d "$DESKTOP_DIR" ]; then
    warning "Desktop folder not found, skipping desktop shortcut"
else
    DESKTOP_FILE="$DESKTOP_DIR/$APP_NAME.desktop"

    sed "s|^Icon=.*|Icon=$ICON_PATH|" \
        "$DESKTOP_PATH" > "$DESKTOP_FILE"

    chown "$REAL_USER:$REAL_USER" "$DESKTOP_FILE"
    chmod +x "$DESKTOP_FILE"

    # Mark the launcher as trusted when supported by the desktop environment.
    if command -v gio >/dev/null 2>&1; then
        sudo -u "$REAL_USER" gio set \
            "$DESKTOP_FILE" \
            metadata::trusted true >/dev/null 2>&1 || true
    fi

    touch "$DESKTOP_FILE"

    success "Desktop shortcut created"
fi

echo
echo -e "${GREEN}Installation complete!${RESET}"
echo
echo "Run with:"
echo
echo "    boot-switcher"
echo
```
