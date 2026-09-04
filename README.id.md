# Fix WiFi STB B860H / B680H — Armbian (RTL8189FTV)

[Read English version](README.md) — versi Indonesia di bawah.

Chip WiFi internal: Realtek RTL8189FTV, SDIO ID 024c:f179.
Gejala: `ip link` tidak ada wlan, `dmesg` hanya `mmc0: new high speed SDIO card`.
Penyebab: kernel ophub 6.12 tidak membawa driver 8189fs; driver staging r8723bs
tidak cocok (alias hanya B723/062x, bukan F179).

Teruji di: Armbian noble, kernel 6.12.94-ophub, DTB meson-gxl-s905x-b860h.dtb.
Hasil: wlan0 UP, DHCP 201.168.0.175/24, ping 8.8.8.8 via wlan0 2/2 OK.

## Isi folder

- 8189fs.ko — modul prebuilt kernel 6.12.94-ophub, v5.7.9_35795.20191128
- install.sh — installer cepat (kernel sama saja)
- setup-dkms.sh + dkms/ — setup DKMS, rebuild otomatis tiap update kernel (disarankan)
- 8189fs.conf — opsi modprobe (power_mgnt=0, enusbss=0)
- blacklist-b860h-wifi.conf — blacklist r8723bs
- modules-load-8189fs.conf — autoload 8189fs saat boot

## Cara cepat (kernel sama)

1. Copy folder ini ke STB, lalu:
   sudo ./install.sh
2. Konek WiFi:
   nmcli dev wifi connect "SSID" password "PASSWORD" ifname wlan0
   nmcli con mod "SSID" connection.autoconnect yes
3. Set wlan1 (interface bayangan) unmanaged — jangan dihapus:
   nmcli dev set wlan1 managed no
   `iw dev wlan1 del` bikin driver 8189fs + sshd hang; STB perlu cabut power.

## Install DKMS (disarankan, selamat update kernel)

  sudo ./setup-dkms.sh

Script ini clone driver (branch rtl8189fs), patch Makefile, daftar DKMS,
build dan install. Saat kernel update, cukup install paket
`linux-headers-*` yang cocok — DKMS rebuild 8189fs otomatis.

Dua jebakan sudah ditangani:

- gcc-13 tidak bisa build modul kernel 6.12 (butuh -fmin-function-alignment=4),
  jadi dkms-make.sh otomatis pilih gcc-14+ dan gagal dengan pesan jelas bila tidak ada.
- Sebagian paket linux-headers ophub membawa
  arch/arm64/include/asm/jump_label.h yang terpotong (28 baris, seharusnya ~56),
  sehingga semua build out-of-tree gagal. dkms-pre-build.sh mendeteksi dan
  memperbaikinya dari upstream torvalds/linux sebelum tiap build.

## Build manual (kernel / headers beda)

Source driver: branch rtl8189fs dari EvilOlaf/rtl8189ES_linux (HAL RTL8188F lengkap).

1. sudo apt-get install -y build-essential dkms gcc-14 linux-headers-$(uname -r)
2. git clone https://github.com/EvilOlaf/rtl8189ES_linux.git ~/.rtl8189fs
   cd ~/.rtl8189fs && git checkout -B rtl8189fs origin/rtl8189fs
3. Di Makefile: CONFIG_RTL8188F = y, CONFIG_RTL8188E = n,
   CONFIG_PLATFORM_I386_PC = n -> y.
4. make ARCH=arm64 CC=gcc-14 — menghasilkan 8189fs.ko.
   Lalu copy ke /lib/modules/$(uname -r)/kernel/drivers/net/wireless/,
   depmod -a, modprobe 8189fs.

## Catatan

- File .ko prebuilt hanya untuk 6.12.94-ophub. Update kernel = build ulang
  (atau pakai DKMS, otomatis).
- File jump_label.h yang rusak ada di paket linux-headers ophub, bukan di driver.
