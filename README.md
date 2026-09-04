# B860H / B680H Internal WiFi Fix on Armbian (RTL8189FTV)

[Baca versi Indonesia](README.id.md)

Internal WiFi on B860H / B680H boxes is dead on ophub Armbian because the driver is missing. This repo ships a prebuilt module, a quick installer, and a DKMS setup so WiFi survives kernel updates.

## Summary

- Chip: Realtek RTL8189FTV, SDIO ID `024c:f179`
- Symptom: no `wlan` in `ip link`, `dmesg` shows only `mmc0: new high speed SDIO card`
- Cause: ophub 6.12 kernels ship no `8189fs` driver; staging `r8723bs` does not match (aliases cover `B723`/`062x`, not `F179`)
- Fix: `8189fs` module v5.7.9, two install paths (fast prebuilt or permanent DKMS)

Tested: Armbian noble, kernel `6.12.94-ophub`, DTB `meson-gxl-s905x-b860h.dtb`.
Result: `wlan0` UP, DHCP `201.168.0.175/24`, ping `8.8.8.8` via `wlan0` 2/2 OK.

## Repo contents

```text
.
├── 8189fs.ko                 # prebuilt module, 6.12.94-ophub only
├── install.sh               # quick installer (same kernel only)
├── setup-dkms.sh            # DKMS setup (recommended)
├── dkms/
│   ├── dkms.conf            # DKMS config
│   ├── dkms-make.sh         # auto-picks gcc-14+, then builds
│   └── dkms-pre-build.sh    # detects + repairs broken jump_label.h
├── 8189fs.conf               # modprobe options (power_mgnt=0, enusbss=0)
├── blacklist-b860h-wifi.conf # blacklist r8723bs
└── modules-load-8189fs.conf  # autoload 8189fs at boot
```

## Option A: quick install (`6.12.94-ophub` only)

```bash
chmod +x install.sh
sudo ./install.sh
```

Connect:

```bash
nmcli dev wifi connect "SSID" password "PASSWORD" ifname wlan0
nmcli con mod "SSID" connection.autoconnect yes
```

## Option B: DKMS (recommended, survives kernel updates)

```bash
chmod +x setup-dkms.sh
sudo ./setup-dkms.sh
```

This clones the driver (`rtl8189fs` branch), patches the Makefile, registers DKMS, builds, and installs. On later kernel updates just install the matching `linux-headers-$(uname -r)` package — DKMS rebuilds `8189fs` automatically.

Two quirks handled automatically:

1. gcc-13 cannot build kernel 6.12 modules (needs `-fmin-function-alignment=4`). `dkms-make.sh` picks gcc-14+ and fails loudly if none is installed.
2. Some ophub `linux-headers` ship a truncated `arch/arm64/include/asm/jump_label.h` (28 lines instead of ~56), breaking every out-of-tree build. `dkms-pre-build.sh` detects and repairs it from upstream `torvalds/linux` before each build.

## Verify

```bash
ip link | grep -i wlan
dmesg | grep -i -E "8189|wlan|mmc0" | tail -20
modinfo 8189fs | grep alias
nmcli dev status
ping -c 2 -I wlan0 8.8.8.8
```

Healthy: `wlan0` present, `modinfo` shows `alias: sdio:c*v024CdF179*`, ping 2/2 OK.

## Warning: do not delete `wlan1`

The driver creates a phantom `wlan1` interface. Leave it alone:

```bash
nmcli dev set wlan1 managed no
```

Never run `iw dev wlan1 del`: it hangs the `8189fs` driver and sshd, forcing a power cycle.

## Troubleshooting

| Symptom | Cause / action |
|---|---|
| `install.sh` refuses: not `6.12.94-ophub` | Use Option B (DKMS); prebuilt covers one kernel only |
| No `wlan` after modprobe | Check `dmesg \| tail -30`, confirm DTB `meson-gxl-s905x-b860h.dtb` and `r8723bs` blacklist |
| Build fails on `fmin-function-alignment` | Install `gcc-14`: `sudo apt-get install -y gcc-14` |
| Build fails in `jump_label.h` | Re-run `setup-dkms.sh` (pre-build repair is automatic), needs access to `raw.githubusercontent.com` |
| `wlan0` up but no IP | Check `nmcli dev wifi list ifname wlan0`, confirm password and 2.4 GHz band |

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

## Manual build (other kernels / headers)

Source: `rtl8189fs` branch of `EvilOlaf/rtl8189ES_linux` (complete RTL8188F HAL).

```bash
sudo apt-get install -y build-essential dkms gcc-14 linux-headers-$(uname -r)
git clone https://github.com/EvilOlaf/rtl8189ES_linux.git ~/.rtl8189fs
cd ~/.rtl8189fs && git checkout -B rtl8189fs origin/rtl8189fs
```

In `Makefile`: `CONFIG_RTL8188F = y`, `CONFIG_RTL8188E = n`, `CONFIG_PLATFORM_I386_PC = n` to `y`. Then:

```bash
make ARCH=arm64 CC=gcc-14
sudo cp 8189fs.ko /lib/modules/$(uname -r)/kernel/drivers/net/wireless/
sudo depmod -a
sudo modprobe 8189fs
```

## Notes

- Prebuilt `.ko` works only on `6.12.94-ophub`. Kernel update = rebuild or use DKMS.
- Broken `jump_label.h` lives in the ophub `linux-headers` package, not the driver.

Driver source: https://github.com/EvilOlaf/rtl8189ES_linux (branch `rtl8189fs`).
Driver license: GPL (Realtek).
