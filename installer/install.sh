#!/bin/bash

set -e


APP_NAME="boot-switcher"

INSTALL_DIR="/opt/$APP_NAME"

BIN_PATH="/usr/local/bin/$APP_NAME"

DESKTOP_PATH="/usr/share/applications/$APP_NAME.desktop"


# Colors

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


info()
{
    echo -e "$1"
}



echo
echo "Boot Switcher installer"
echo "======================="
echo



# Root check

if [ "$EUID" -ne 0 ]; then

    error "Please run this installer with sudo"

    echo
    echo "Example:"
    echo "sudo ./installer/install.sh"

    exit 1

fi



# Detect UEFI

if [ ! -d "/sys/firmware/efi" ]; then

    error "No UEFI firmware detected."

    echo "Boot Switcher requires a UEFI system."

    exit 1

fi

success "UEFI firmware detected"



# Detect package manager

PACKAGE_MANAGER=""



if command -v apt >/dev/null; then

    PACKAGE_MANAGER="apt"

elif command -v dnf >/dev/null; then

    PACKAGE_MANAGER="dnf"

elif command -v pacman >/dev/null; then

    PACKAGE_MANAGER="pacman"

elif command -v zypper >/dev/null; then

    PACKAGE_MANAGER="zypper"

fi



install_package()
{

    PACKAGE="$1"


    if command -v "$PACKAGE" >/dev/null; then

        success "$PACKAGE already installed"

        return

    fi


    warning "$PACKAGE missing"


    if [ -z "$PACKAGE_MANAGER" ]; then

        error "No supported package manager found"

        echo
        echo "Please install manually:"
        echo "$PACKAGE"

        exit 1

    fi



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

    esac



    if command -v "$PACKAGE" >/dev/null; then

        success "$PACKAGE installed"

    else

        error "Could not install $PACKAGE"

        exit 1

    fi

}



echo
echo "Checking dependencies..."
echo



# Python

if command -v python3 >/dev/null; then

    success "Python3 found"

else

    install_package python3

fi



# venv

if python3 -m venv --help >/dev/null 2>&1; then

    success "Python virtual environment support found"

else

    warning "Python venv support missing"


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
            error "Install python venv support manually"
            exit 1
            ;;

    esac


    success "Python venv support installed"

fi



# efibootmgr

if command -v efibootmgr >/dev/null; then

    success "efibootmgr found"

else

    install_package efibootmgr

fi



# pkexec

if command -v pkexec >/dev/null; then

    success "pkexec found"

else

    warning "pkexec missing"


    case "$PACKAGE_MANAGER" in

        apt)
            apt install -y policykit-1
            ;;

        dnf)
            dnf install -y polkit
            ;;

        pacman)
            pacman -Sy --noconfirm polkit
            ;;

        zypper)
            zypper install -y polkit
            ;;

        *)
            error "Install polkit manually"
            exit 1
            ;;

    esac


    success "pkexec installed"

fi



echo
echo "Installing Boot Switcher..."
echo



mkdir -p "$INSTALL_DIR"



# Copy files

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"


cp -r "$SCRIPT_DIR/run.py" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/src" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/requirements.txt" "$INSTALL_DIR/"



success "Files copied"



# Create venv

if [ ! -d "$INSTALL_DIR/venv" ]; then

    python3 -m venv "$INSTALL_DIR/venv"

    success "Virtual environment created"

else

    success "Existing virtual environment found"

fi



echo "Installing Python dependencies..."

"$INSTALL_DIR/venv/bin/pip" install --upgrade pip >/dev/null

"$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/requirements.txt"



success "Python dependencies installed"



# Create command

cat > "$BIN_PATH" <<EOF
#!/bin/bash

$INSTALL_DIR/venv/bin/python $INSTALL_DIR/run.py
EOF


chmod +x "$BIN_PATH"


success "Command installed: boot-switcher"



# Desktop entry

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



echo
echo -e "${GREEN}Installation complete!${RESET}"
echo
echo "Run with:"
echo
echo "    boot-switcher"
echo