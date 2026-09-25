#!/bin/sh
# Renders the app icons and a sheet of Nutmeg's looks from the same SwiftUI
# drawing the app uses, so the icons can never drift from the mascot.
#
#   Tools/icons/build.sh [output folder]   (default /tmp/larder-icons)
#
# The PNGs come out with an alpha channel; strip it (convert to RGB) before
# they go into an app icon set, since icons must be opaque.
set -e
cd "$(dirname "$0")"
OUT="${1:-/tmp/larder-icons}"
mkdir -p "$OUT" .build
# NutmegView.swift without its #Preview, which needs the rest of the app.
sed '/^#Preview {/,/^}/d' ../../Larder/Larder/Mascot/NutmegView.swift > .build/NutmegView.swift
swiftc -o .build/render .build/NutmegView.swift main.swift
.build/render "$OUT"
