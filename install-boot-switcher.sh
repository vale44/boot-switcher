#!/bin/bash

set -e


APP_NAME="boot-switcher"

REPO="https://github.com/vale44/boot-switcher/archive/refs/heads/main.tar.gz"

INSTALL_DIR="/opt/$APP_NAME"

BIN_PATH="/usr/local/bin/$APP_NAME"

DESKTOP_PATH="/usr/share/applications/$APP_NAME.desktop"

ICON_DIR="/usr/share/icons/hicolor/scalable/apps"

ICON_PATH="$ICON_DIR/$APP_NAME.svg"



GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"



success()
{
    echo -e "${GREEN}✓ $1${RESET}"
}


warning()
{
    echo -e "${YELLOW}! $1${RESET}"
}


error()
{
    echo -e "${RED}✗ $1${RESET}"
}



echo
echo "Boot Switcher installer"
echo "======================="
echo



if [ "$EUID" -ne 0 ]; then

    error "Please run this installer with sudo"

    echo

    echo "Example:"
    echo "sudo bash install-boot-switcher.sh"

    exit 1

fi



if [ ! -d "/sys/firmware/efi" ]; then

    error "UEFI firmware not detected"

    echo "Boot Switcher requires a UEFI system."

    exit 1

fi



success "UEFI firmware detected"



# --------------------------------------------------
# Package manager detection
# --------------------------------------------------


PACKAGE_MANAGER=""



if command -v apt >/dev/null 2>&1; then

    PACKAGE_MANAGER="apt"

elif command -v dnf >/dev/null 2>&1; then

    PACKAGE_MANAGER="dnf"

elif command -v pacman >/dev/null 2>&1; then

    PACKAGE_MANAGER="pacman"

elif command -v zypper >/dev/null 2>&1; then

    PACKAGE_MANAGER="zypper"

fi



install_package()
{

    PACKAGE="$1"


    warning "$PACKAGE missing"

    echo "Installing $PACKAGE..."



    case "$PACKAGE_MANAGER" in


        apt)

            apt update

            apt install -y "$PACKAGE"

            ;;


        dnf)

            dnf install -y "$PACKAGE"

            ;;


        pacman)

            pacman -Sy --noconfirm "$PACKAGE"

            ;;


        zypper)

            zypper install -y "$PACKAGE"

            ;;


        *)

            error "Unsupported package manager"

            echo "Please install manually:"
            echo "$PACKAGE"

            exit 1

            ;;

    esac



    success "$PACKAGE installed"

}



check_command()
{

    COMMAND="$1"

    PACKAGE="$2"



    if command -v "$COMMAND" >/dev/null 2>&1; then

        success "$COMMAND found"

    else

        install_package "$PACKAGE"

    fi

}



echo
echo "Checking dependencies..."
echo



check_command python3 python3

check_command efibootmgr efibootmgr

check_command pkexec policykit-1



# Python venv


if python3 -m venv --help >/dev/null 2>&1; then

    success "Python virtual environment support found"

else

    warning "Python venv missing"


    case "$PACKAGE_MANAGER" in

        apt)

            apt install -y python3-venv

            ;;


        dnf)

            dnf install -y python3-virtualenv

            ;;


        pacman)

            pacman -Sy --noconfirm python-virtualenv

            ;;


        zypper)

            zypper install -y python3-virtualenv

            ;;


        *)

            error "Cannot install Python venv automatically"

            exit 1

            ;;

    esac


    success "Python venv installed"

fi



echo
echo "Installing Boot Switcher..."
echo



TEMP_DIR=$(mktemp -d)



echo "Downloading files..."

curl -fsSL "$REPO" -o "$TEMP_DIR/source.tar.gz"



mkdir -p "$TEMP_DIR/extract"



tar -xzf "$TEMP_DIR/source.tar.gz" \
-C "$TEMP_DIR/extract"



SOURCE_DIR=$(find "$TEMP_DIR/extract" \
-maxdepth 1 \
-type d \
-name "boot-switcher-*")



if [ -z "$SOURCE_DIR" ]; then

    error "Could not extract project files"

    exit 1

fi
rm -rf "$INSTALL_DIR"

mkdir -p "$INSTALL_DIR"



# Copy application files

cp "$SOURCE_DIR/run.py" "$INSTALL_DIR/"

cp -r "$SOURCE_DIR/src" "$INSTALL_DIR/"

cp "$SOURCE_DIR/requirements.txt" "$INSTALL_DIR/"



success "Files copied"



# --------------------------------------------------
# Icon installation
# --------------------------------------------------


if [ -f "$SOURCE_DIR/assets/$APP_NAME.svg" ]; then


    mkdir -p "$ICON_DIR"


    cp "$SOURCE_DIR/assets/$APP_NAME.svg" "$ICON_PATH"


    chmod 644 "$ICON_PATH"


    success "Application icon installed"


else


    warning "Application icon not found"


fi



# --------------------------------------------------
# Python environment
# --------------------------------------------------


echo "Creating virtual environment..."



python3 -m venv "$INSTALL_DIR/venv"



success "Virtual environment created"



echo "Installing Python dependencies..."



"$INSTALL_DIR/venv/bin/pip" install --upgrade pip >/dev/null



"$INSTALL_DIR/venv/bin/pip" install \
-r "$INSTALL_DIR/requirements.txt"



success "Python dependencies installed"



# --------------------------------------------------
# Terminal command
# --------------------------------------------------


cat > "$BIN_PATH" <<EOF
#!/bin/bash

exec $INSTALL_DIR/venv/bin/python $INSTALL_DIR/run.py "\$@"
EOF



chmod +x "$BIN_PATH"



success "Command installed: $BIN_PATH"



# --------------------------------------------------
# Application menu entry
# --------------------------------------------------


cat > "$DESKTOP_PATH" <<EOF
[Desktop Entry]
Type=Application
Name=Boot Switcher
Comment=Switch EFI boot entries
Exec=$BIN_PATH
Path=$INSTALL_DIR
Icon=$APP_NAME
Terminal=false
Categories=Utility;
StartupNotify=true
EOF



chmod 644 "$DESKTOP_PATH"



success "Application menu entry created"



# --------------------------------------------------
# Refresh desktop/icon databases
# --------------------------------------------------


if command -v update-desktop-database >/dev/null 2>&1; then

    update-desktop-database \
    /usr/share/applications \
    >/dev/null 2>&1 || true

fi



if command -v gtk-update-icon-cache >/dev/null 2>&1; then

    gtk-update-icon-cache \
    /usr/share/icons/hicolor \
    >/dev/null 2>&1 || true

fi



# --------------------------------------------------
# Desktop shortcut
# --------------------------------------------------

# --------------------------------------------------
# Desktop shortcut
# --------------------------------------------------

if [ -n "$SUDO_USER" ]; then

    REAL_USER="$SUDO_USER"
    REAL_HOME=$(eval echo "~$REAL_USER")

else

    REAL_USER="$USER"
    REAL_HOME="$HOME"

fi


if command -v xdg-user-dir >/dev/null 2>&1; then

    DESKTOP_DIR=$(sudo -u "$REAL_USER" xdg-user-dir DESKTOP)

else

    DESKTOP_DIR="$REAL_HOME/Desktop"

fi


if [ -d "$DESKTOP_DIR" ]; then

    DESKTOP_FILE="$DESKTOP_DIR/$APP_NAME.desktop"

    rm -f "$DESKTOP_FILE"

    sed 's|Icon=boot-switcher|Icon=/usr/share/icons/hicolor/scalable/apps/boot-switcher.svg|' \
    "$DESKTOP_PATH" > "$DESKTOP_FILE"

    chown "$REAL_USER:$REAL_USER" "$DESKTOP_FILE"

    chmod +x "$DESKTOP_FILE"

    success "Desktop shortcut created"

else

    warning "Desktop folder not found, skipping shortcut"

fi


    # Force file timestamp update
    touch "$DESKTOP_FILE"


    success "Desktop shortcut created"


else

    warning "Desktop folder not found, skipping shortcut"

fi