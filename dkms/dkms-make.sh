#!/bin/bash
# DKMS make wrapper: pick a compiler supporting the kernel's flags, then build.
KVER="${1:-$(uname -r)}"
CC_BIN=""
for c in gcc-14 gcc-15 gcc-13 gcc; do
  if command -v "$c" >/dev/null 2>&1; then
    if echo 'int main(void){return 0;}' | "$c" -fmin-function-alignment=4 -x c - -o /dev/null 2>/dev/null; then
      CC_BIN="$c"
      break
    fi
  fi
done
[ -n "$CC_BIN" ] || { echo "ERROR: no gcc with -fmin-function-alignment=4 (need gcc-14+). Install gcc-14." >&2; exit 1; }
echo "DKMS build: KVER=$KVER CC=$CC_BIN ARCH=arm64"
exec make -j"$(nproc)" ARCH=arm64 "CC=$CC_BIN" "KVER=$KVER" "KSRC=/lib/modules/$KVER/build" modules
