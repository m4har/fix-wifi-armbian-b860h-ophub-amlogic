#!/bin/bash
# install.sh — install 8189fs WiFi driver on B860H/B680H STB (Armbian kernel 6.12.94-ophub)
# Run on the target STB as a sudo user:  sudo ./install.sh
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KREL="$(uname -r)"
DST="/lib/modules/$KREL/kernel/drivers/net/wireless/8189fs.ko"
echo "[*] Kernel: $KREL"
if [ "$KREL" != "6.12.94-ophub" ]; then
  echo "[!] Prebuilt module is for 6.12.94-ophub; use setup-dkms.sh for other kernels."
  exit 1
fi
echo "[*] Copy 8189fs.ko ..."
sudo cp "$SCRIPT_DIR/8189fs.ko" "$DST"
sudo depmod -a
echo "[*] Writing modprobe + blacklist + autoload ..."
sudo cp "$SCRIPT_DIR/8189fs.conf" /etc/modprobe.d/8189fs.conf
sudo cp "$SCRIPT_DIR/blacklist-b860h-wifi.conf" /etc/modprobe.d/blacklist-b860h-wifi.conf
sudo cp "$SCRIPT_DIR/modules-load-8189fs.conf" /etc/modules-load.d/8189fs.conf
sudo modprobe 8189fs
sleep 2
echo "[*] Verify:"
ip link show | grep -i wlan || { echo "[!] no wlan interface"; exit 1; }
echo "[OK] wlan found. Next: nmcli dev wifi connect \"SSID\" password \"PASS\" ifname wlan0"
