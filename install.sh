#!/bin/bash
# install.sh — pasang driver WiFi 8189fs di STB B860H/B680H (Armbian kernel 6.12.94-ophub)
# Jalankan di STB target sebagai user sudo:  sudo ./install.sh
set -e
KREL="$(uname -r)"
DST="/lib/modules/$KREL/kernel/drivers/net/wireless/8189fs.ko"
echo "[*] Kernel: $KREL"
if [ "$KREL" != "6.12.94-ophub" ]; then
  echo "[!] Modul prebuilt untuk 6.12.94-ophub; kernel lain perlu build ulang (lihat README)."
  exit 1
fi
echo "[*] Copy 8189fs.ko ..."
sudo cp 8189fs.ko "$DST"
sudo depmod -a
echo "[*] Tulis modprobe + blacklist + autoload ..."
sudo cp 8189fs.conf /etc/modprobe.d/8189fs.conf
sudo cp blacklist-b860h-wifi.conf /etc/modprobe.d/blacklist-b860h-wifi.conf
sudo cp modules-load-8189fs.conf /etc/modules-load.d/8189fs.conf
sudo modprobe 8189fs
sleep 2
echo "[*] Verifikasi:"
ip link show | grep -i wlan || { echo "[!] wlan tidak muncul"; exit 1; }
echo "[OK] wlan terdeteksi. Lanjut: nmcli dev wifi connect \"SSID\" password \"PASS\" ifname wlan0"
