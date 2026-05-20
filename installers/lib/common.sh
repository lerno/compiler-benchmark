#!/bin/bash

# Detect OS
if [ -f /etc/arch-release ]; then
    OS="arch"
    INSTALL_CMD="sudo pacman -S --noconfirm --needed"
elif [ -f /etc/lsb-release ]; then
    OS="ubuntu"
    INSTALL_CMD="sudo apt-get install -y"
else
    echo "Unsupported OS"
    exit 1
fi

# Helper function to install packages
install_pkg() {
    echo "Installing $1 via $OS..."
    $INSTALL_CMD "$@"
}
