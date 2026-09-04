# B860H / B680H Internal WiFi Fix — Armbian (RTL8189FTV)

[Baca versi Indonesia](README.id.md).

Internal WiFi chip: Realtek RTL8189FTV, SDIO ID 024c:f179.
Symptom: no wlan in `ip link`, `dmesg` only shows `mmc0: new high speed SDIO card`.
Cause: ophub 6.12 kernels ship no 8189fs driver; the staging r8723bs driver does
not match (aliases cover B723/062x, not F179).

Tested on: Armbian noble, kernel 6.12.94-ophub, DTB meson-gxl-s905x-b860h.dtb.
Result: wlan0 UP, DHCP 201.168.0.175/24, ping 8.8.8.8 via wlan0 2/2 OK.

## Folder contents

- 8189fs.ko — prebuilt module for kernel 6.12.94-ophub, v5.7.9_35795.20191128
- install.sh — quick installer (same kernel only)
- setup-dkms.sh + dkms/ — DKMS setup, rebuilds driver on kernel updates (recommended)
- 8189fs.conf — modprobe options (power_mgnt=0, enusbss=0)
- blacklist-b860h-wifi.conf — blacklist r8723bs
- modules-load-8189fs.conf — autoload 8189fs at boot

## Quick install (same kernel)

1. Copy this folder to the STB, then:
   sudo ./install.sh
2. Connect:
   nmcli dev wifi connect "SSID" password "PASSWORD" ifname wlan0
   nmcli con mod "SSID" connection.autoconnect yes
3. Set wlan1 (phantom interface) unmanaged — never delete it:
   nmcli dev set wlan1 managed no
   `iw dev wlan1 del` hangs the 8189fs driver and sshd; the box then needs a power cycle.

## DKMS install (recommended, survives kernel updates)

  sudo ./setup-dkms.sh

This clones the driver (rtl8189fs branch), patches the Makefile, registers DKMS,
builds and installs. On later kernel updates just install the matching
`linux-headers-*` package — DKMS rebuilds 8189fs automatically.

Two quirks are handled for you:

- gcc-13 cannot build kernel 6.12 modules (needs -fmin-function-alignment=4),
  so dkms-make.sh auto-picks gcc-14+ and fails loudly if none is installed.
- Some ophub linux-headers ship a truncated
  arch/arm64/include/asm/jump_label.h (28 lines instead of ~56), which breaks
  every out-of-tree build. dkms-pre-build.sh detects and repairs it from
  upstream torvalds/linux before each build.

## Rebuilding manually (different kernel / headers)

Driver source: rtl8189fs branch of EvilOlaf/rtl8189ES_linux (complete RTL8188F HAL).

1. sudo apt-get install -y build-essential dkms gcc-14 linux-headers-$(uname -r)
2. git clone https://github.com/EvilOlaf/rtl8189ES_linux.git ~/.rtl8189fs
   cd ~/.rtl8189fs && git checkout -B rtl8189fs origin/rtl8189fs
3. In Makefile: CONFIG_RTL8188F = y, CONFIG_RTL8188E = n,
   CONFIG_PLATFORM_I386_PC = n -> y.
4. make ARCH=arm64 CC=gcc-14 — produces 8189fs.ko.
   Then copy to /lib/modules/$(uname -r)/kernel/drivers/net/wireless/,
   depmod -a, modprobe 8189fs.

## Notes

- The prebuilt .ko works only on 6.12.94-ophub. A kernel update needs a rebuild
  (or DKMS, which does it for you).
- The broken jump_label.h lives in the ophub linux-headers package, not the driver.
