#!/bin/bash
# DKMS pre-build: detect truncated ophub jump_label.h and repair from upstream.
KVER="${1:-$(uname -r)}"
JL="/lib/modules/$KVER/build/arch/arm64/include/asm/jump_label.h"
[ -f "$JL" ] || JL="/usr/src/linux-headers-$KVER/arch/arm64/include/asm/jump_label.h"
[ -f "$JL" ] || exit 0
LINES=$(wc -l < "$JL")
if [ "$LINES" -lt 40 ]; then
  echo "WARNING: $JL truncated ($LINES lines), fetching upstream fix..."
  MAJOR=$(echo "$KVER" | grep -oE '^[0-9]+\.[0-9]+')
  if curl -sL --max-time 60 "https://raw.githubusercontent.com/torvalds/linux/v$MAJOR/arch/arm64/include/asm/jump_label.h" -o /tmp/jl_fix.h \
     && [ "$(wc -l < /tmp/jl_fix.h 2>/dev/null)" -gt 40 ]; then
    cp "$JL" "/tmp/jump_label.h.bak-$KVER" 2>/dev/null
    cp /tmp/jl_fix.h "$JL" && echo "Header repaired."
  else
    echo "ERROR: could not fetch fixed header; build will likely fail." >&2
  fi
fi
exit 0
