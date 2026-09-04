# llm.md — Acuan build untuk AI agent (fix-wifi-b680h)

File ini sumber kebenaran ringkas untuk agent yang membantu build, debug, atau rilis repo ini. README.md (EN) dan README.id.md (ID) untuk manusia; file ini untuk mesin.

## 1. Fakta perangkat (jangan diubah tanpa verifikasi ulang)

- Target: STB HG680P / B860H / B680H (SoC Amlogic S905x), DTB `meson-gxl-s905x-b860h.dtb`
- OS: Armbian noble, kernel `6.12.94-ophub`, ARCH `arm64`
- Chip WiFi: Realtek RTL8189FTV, SDIO ID `024c:f179`
- Driver: `8189fs` v5.7.9 (`v5.7.9_35795.20191128`), lisensi GPL (Realtek)
- Source driver: https://github.com/EvilOlaf/rtl8189ES_linux , branch `rtl8189fs`
- Gejala tanpa driver: `ip link` tanpa `wlan`, `dmesg` hanya `mmc0: new high speed SDIO card`
- Penyebab: kernel ophub 6.12 tanpa `8189fs`; staging `r8723bs` tidak cocok (alias hanya `B723`/`062x`)
- Hasil teruji: `wlan0` UP, DHCP `201.168.0.175/24`, ping `8.8.8.8` via `wlan0` 2/2 OK
- Pantangan: interface bayangan `wlan1` cukup `nmcli dev set wlan1 managed no`; `iw dev wlan1 del` hang driver + sshd, butuh cabut power

## 2. Peta file repo

```text
8189fs.ko                  # prebuilt, HANYA 6.12.94-ophub (lihat §3)
install.sh                 # installer cepat, tolak kernel lain (exit 1)
setup-dkms.sh              # setup DKMS, clone source, patch Makefile, dkms add/build/install
dkms/dkms.conf             # PACKAGE 8189fs 5.7.9, MAKE via dkms-make.sh, PRE_BUILD via dkms-pre-build.sh
dkms/dkms-make.sh          # pilih gcc mendukung -fmin-function-alignment=4 (gcc-14+), build ARCH=arm64
dkms/dkms-pre-build.sh     # perbaiki jump_label.h terpotong dari upstream torvalds/linux
8189fs.conf                # options 8189fs rtw_power_mgnt=0 rtw_enusbss=0
blacklist-b860h-wifi.conf  # blacklist r8723bs
modules-load-8189fs.conf   # autoload 8189fs
README.md / README.id.md   # dokumentasi manusia EN / ID
llm.md                     # file ini
```

## 3. Artefak prebuilt (fakta terverifikasi 2026-09-04)

- `8189fs.ko`: 2969512 byte, sha256 `660253efad71ffa9e3413b5c7e9c568abbe633baa19dddeccada07fc26d5d7e8`
- `modinfo`: `version v5.7.9_35795.20191128`, `alias sdio:c*v024CdF179*`, `depends cfg80211`, `vermagic 6.12.94-ophub SMP preempt mod_unload aarch64`
- Berlaku HANYA untuk `vermagic` di atas. Kernel lain wajib build ulang / DKMS.
- Bila `.ko` diganti, update sha256 + vermagic di sini dan di kedua README.

## 4. Build manual kanonis

```bash
sudo apt-get install -y build-essential dkms gcc-14 linux-headers-$(uname -r)
git clone https://github.com/EvilOlaf/rtl8189ES_linux.git ~/.rtl8189fs
cd ~/.rtl8189fs && git checkout -B rtl8189fs origin/rtl8189fs
# Makefile: CONFIG_RTL8188F = y, CONFIG_RTL8188E = n, CONFIG_PLATFORM_I386_PC = n -> y
make ARCH=arm64 CC=gcc-14
sudo cp 8189fs.ko /lib/modules/$(uname -r)/kernel/drivers/net/wireless/
sudo depmod -a
sudo modprobe 8189fs
```

Patch Makefile yang dipakai `setup-dkms.sh` (setara sed):

```bash
sed -i 's/^CONFIG_RTL8188E = y/CONFIG_RTL8188E = n/' Makefile
sed -i 's/^CONFIG_RTL8188F = n/CONFIG_RTL8188F = y/' Makefile
sed -i 's/^CONFIG_PLATFORM_I386_PC = n/CONFIG_PLATFORM_I386_PC = y/' Makefile
grep -E "^CONFIG_RTL8188[EF] |^CONFIG_PLATFORM_I386_PC" Makefile
```

## 5. Dua jebakan build (wajib dipertahankan solusinya)

1. gcc-13 gagal build modul kernel 6.12 (butuh `-fmin-function-alignment=4`).
   Solusi: `dkms/dkms-make.sh` probe `gcc-14 gcc-15 gcc-13 gcc`, pakai yang lolos uji flag, gagal keras bila tidak ada. Jangan hapus probe ini.
2. Sebagian `linux-headers` ophub membawa `arch/arm64/include/asm/jump_label.h` terpotong (28 baris, normal ~56), semua build out-of-tree gagal.
   Solusi: `dkms/dkms-pre-build.sh` cek jumlah baris < 40, fetch upstream `https://raw.githubusercontent.com/torvalds/linux/v<MAJOR>/arch/arm64/include/asm/jump_label.h`, backup lama ke `/tmp/jump_label.h.bak-<KVER>`. Butuh akses `raw.githubusercontent.com`. Jangan hapus hook `PRE_BUILD` di `dkms.conf`.

## 6. Verifikasi (urutan baku)

```bash
uname -r
ip link | grep -i wlan
dmesg | grep -i -E "8189|wlan|mmc0" | tail -20
modinfo 8189fs | grep -E "^(version|vermagic|alias)"
nmcli dev status
ping -c 2 -I wlan0 8.8.8.8
```

Sehat: `wlan0` ada, alias `sdio:c*v024CdF179*` cocok, ping 2/2 OK.

## 7. Batasan untuk agent

- Jangan klaim `.ko` cocok untuk kernel lain tanpa `modinfo` vermagic cocok.
- Jangan ganti source driver tanpa uji alias F179 (`modinfo | grep alias`).
- Jangan sarankan hapus `wlan1` (lihat §1 pantangan).
- Jangan hapus probe gcc / repair jump_label.h (lihat §5).
- Setiap rilis `.ko` baru: update sha256 + vermagic di §3 dan kedua README, sebutkan kernel target.
- Bahasa dokumen manusia: EN default, ID pendamping; `llm.md` ini boleh campur, yang penting presisi.
