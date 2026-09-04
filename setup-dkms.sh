#!/bin/bash
# setup-dkms.sh — register 8189fs driver with DKMS so it survives kernel updates.
# Run ON the STB as a sudo user:  sudo ./setup-dkms.sh
# Requires: dkms, git, gcc-14+, linux-headers-$(uname -r), curl
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG="8189fs"
VER="5.7.9"
SRC="/usr/src/$PKG-$VER"

echo "[*] Installing prerequisites..."
sudo apt-get update
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y dkms git gcc-14 curl
if [ -d "/lib/modules/$(uname -r)/build" ]; then
  echo "[*] Kernel headers for $(uname -r) already present, skipping headers install."
else
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "linux-headers-$(uname -r)"
fi

echo "[*] Preparing source in $SRC ..."
sudo rm -rf "$SRC"
sudo git clone --depth 1 --branch rtl8189fs https://github.com/EvilOlaf/rtl8189ES_linux.git "$SRC"
cd "$SRC"
echo "[*] Patching Makefile (RTL8188F + native platform)..."
sudo sed -i 's/^CONFIG_RTL8188E = y/CONFIG_RTL8188E = n/' Makefile
sudo sed -i 's/^CONFIG_RTL8188F = n/CONFIG_RTL8188F = y/' Makefile
sudo sed -i 's/^CONFIG_PLATFORM_I386_PC = n/CONFIG_PLATFORM_I386_PC = y/' Makefile
grep -E "^CONFIG_RTL8188[EF] |^CONFIG_PLATFORM_I386_PC" Makefile
echo "[*] Installing DKMS helpers..."
sudo cp "$SCRIPT_DIR/dkms/dkms.conf" "$SCRIPT_DIR/dkms/dkms-make.sh" "$SCRIPT_DIR/dkms/dkms-pre-build.sh" "$SRC/"
sudo chmod +x "$SRC/dkms-make.sh" "$SRC/dkms-pre-build.sh"

echo "[*] Registering with DKMS..."
sudo dkms add -m "$PKG" -v "$VER" 2>/dev/null || echo "(already added)"
sudo dkms build -m "$PKG" -v "$VER"
sudo dkms install -m "$PKG" -v "$VER"
echo "[*] Config (modprobe, blacklist, autoload)..."
sudo cp "$SCRIPT_DIR/8189fs.conf" /etc/modprobe.d/8189fs.conf
sudo cp "$SCRIPT_DIR/blacklist-b860h-wifi.conf" /etc/modprobe.d/blacklist-b860h-wifi.conf
sudo cp "$SCRIPT_DIR/modules-load-8189fs.conf" /etc/modules-load.d/8189fs.conf
sudo modprobe 8189fs || true
sleep 2
echo "[*] Status:"
sudo dkms status "$PKG"
ip link show | grep -i wlan || { echo "[!] wlan not found"; exit 1; }
echo "[OK] 8189fs via DKMS. Future kernels: install linux-headers, DKMS rebuilds automatically."
