# Fix WiFi Internal B860H / B680H di Armbian (RTL8189FTV)

[Read in English](README.md)

WiFi internal STB B860H / B680H mati di Armbian ophub karena driver tidak tersedia. Repo ini berisi modul prebuilt, installer cepat, dan setup DKMS agar WiFi tetap jalan setelah update kernel.

## Ringkasan

- Chip: Realtek RTL8189FTV, SDIO ID `024c:f179`
- Gejala: `ip link` tidak ada `wlan`, `dmesg` hanya tampil `mmc0: new high speed SDIO card`
- Penyebab: kernel ophub 6.12 tidak menyertakan driver `8189fs`; driver staging `r8723bs` tidak cocok (alias hanya `B723`/`062x`, bukan `F179`)
- Solusi: modul `8189fs` v5.7.9, dua jalur instalasi (prebuilt cepat atau DKMS permanen)

Teruji: Armbian noble, kernel `6.12.94-ophub`, DTB `meson-gxl-s905x-b860h.dtb`.
Hasil: `wlan0` UP, DHCP `201.168.0.175/24`, ping `8.8.8.8` via `wlan0` 2/2 OK.

## Isi repo

```text
.
├── 8189fs.ko                 # modul prebuilt, khusus 6.12.94-ophub
├── install.sh               # installer cepat (kernel sama saja)
├── setup-dkms.sh            # setup DKMS (disarankan)
├── dkms/
│   ├── dkms.conf            # konfigurasi DKMS
│   ├── dkms-make.sh         # pilih gcc-14+ otomatis, lalu build
│   └── dkms-pre-build.sh    # deteksi + perbaiki jump_label.h rusak
├── 8189fs.conf               # opsi modprobe (power_mgnt=0, enusbss=0)
├── blacklist-b860h-wifi.conf # blacklist r8723bs
└── modules-load-8189fs.conf  # autoload 8189fs saat boot
```

## Opsi A: instal cepat (kernel `6.12.94-ophub` saja)

```bash
chmod +x install.sh
sudo ./install.sh
```

Sambungkan WiFi:

```bash
nmcli dev wifi connect "SSID" password "PASSWORD" ifname wlan0
nmcli con mod "SSID" connection.autoconnect yes
```

## Opsi B: DKMS (disarankan, tahan update kernel)

```bash
chmod +x setup-dkms.sh
sudo ./setup-dkms.sh
```

Script meng-clone driver branch `rtl8189fs`, patch Makefile, daftar ke DKMS, build, dan install. Saat kernel update, cukup pasang `linux-headers-$(uname -r)` yang cocok, DKMS rebuild otomatis.

Dua jebakan sudah ditangani otomatis:

1. gcc-13 tidak bisa build modul kernel 6.12 (butuh flag `-fmin-function-alignment=4`). `dkms-make.sh` pilih gcc-14+ dan gagal dengan pesan jelas bila tidak ada.
2. Sebagian paket `linux-headers` ophub membawa `arch/arm64/include/asm/jump_label.h` terpotong (28 baris, seharusnya ~56) sehingga semua build out-of-tree gagal. `dkms-pre-build.sh` mendeteksi dan memperbaikinya dari upstream `torvalds/linux` sebelum tiap build.

## Verifikasi

```bash
ip link | grep -i wlan
dmesg | grep -i -E "8189|wlan|mmc0" | tail -20
modinfo 8189fs | grep alias
nmcli dev status
ping -c 2 -I wlan0 8.8.8.8
```

Normal: `wlan0` muncul, `modinfo` tampil `alias: sdio:c*v024CdF179*`, ping 2/2 OK.

## Peringatan: jangan hapus `wlan1`

Driver membuat interface bayangan `wlan1`. Perlakukan sebagai berikut:

```bash
nmcli dev set wlan1 managed no
```

Jangan jalankan `iw dev wlan1 del`: driver `8189fs` + sshd hang, STB perlu cabut power.

## Troubleshooting

| Gejala | Penyebab / aksi |
|---|---|
| `install.sh` menolak: bukan `6.12.94-ophub` | Pakai Opsi B (DKMS), prebuilt hanya untuk satu kernel |
| `wlan` tetap tidak muncul setelah modprobe | Cek `dmesg \| tail -30`, pastikan DTB `meson-gxl-s905x-b860h.dtb` dan blacklist `r8723bs` terpasang |
| Build gagal `fmin-function-alignment` | Install `gcc-14`: `sudo apt-get install -y gcc-14` |
| Build gagal di `jump_label.h` | Jalankan ulang `setup-dkms.sh` (pre-build repair otomatis), butuh koneksi ke `raw.githubusercontent.com` |
| `wlan0` muncul tapi tidak dapat IP | Cek `nmcli dev wifi list ifname wlan0`, pastikan password dan band 2.4 GHz benar |

## Uninstall

```bash
# prebuilt
sudo rm /lib/modules/$(uname -r)/kernel/drivers/net/wireless/8189fs.ko
sudo rm /etc/modprobe.d/8189fs.conf /etc/modprobe.d/blacklist-b860h-wifi.conf /etc/modules-load.d/8189fs.conf
sudo depmod -a

# DKMS
sudo dkms remove -m 8189fs -v 5.7.9 --all
sudo rm -rf /usr/src/8189fs-5.7.9
```

## Build manual (kernel / headers lain)

Source: branch `rtl8189fs` dari `EvilOlaf/rtl8189ES_linux` (HAL RTL8188F lengkap).

```bash
sudo apt-get install -y build-essential dkms gcc-14 linux-headers-$(uname -r)
git clone https://github.com/EvilOlaf/rtl8189ES_linux.git ~/.rtl8189fs
cd ~/.rtl8189fs && git checkout -B rtl8189fs origin/rtl8189fs
```

Di `Makefile`: `CONFIG_RTL8188F = y`, `CONFIG_RTL8188E = n`, `CONFIG_PLATFORM_I386_PC = n` menjadi `y`. Lalu:

```bash
make ARCH=arm64 CC=gcc-14
sudo cp 8189fs.ko /lib/modules/$(uname -r)/kernel/drivers/net/wireless/
sudo depmod -a
sudo modprobe 8189fs
```

## Catatan

- File `.ko` prebuilt hanya untuk `6.12.94-ophub`. Update kernel = build ulang atau pakai DKMS.
- File `jump_label.h` yang rusak berasal dari paket `linux-headers` ophub, bukan dari driver.

Sumber driver: https://github.com/EvilOlaf/rtl8189ES_linux (branch `rtl8189fs`).
Lisensi driver: GPL (Realtek).
