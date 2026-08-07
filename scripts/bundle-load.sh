#!/usr/bin/env bash
# PESERTA. Muat semua image lab dari flashdisk, tanpa internet sama sekali.
#   ./lab offline load /Volumes/FLASHDISK/ceh-bundle
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/common.sh"

SRC="${1:-}"
[ -n "$SRC" ] || die "Sebutin foldernya. Contoh: ./lab offline load /Volumes/CEH"
[ -d "$SRC" ] || die "Folder '$SRC' tidak ada. Periksa nama flashdisknya."
detect_engine

# Peserta ga perlu tau arsitekturnya. Skrip yang milih.
DIR="$SRC/bundle-$ARCH"
if [ ! -d "$DIR" ] && [ -d "$SRC/bundle-arm64" ] && [ "$ARCH" = "arm64" ]; then DIR="$SRC/bundle-arm64"; fi
if [ ! -d "$DIR" ]; then
  # mungkin peserta nunjuk langsung ke folder bundle-nya
  if [ -f "$SRC/manifest.txt" ]; then DIR="$SRC"; else
    die "Ga nemu folder bundle-$ARCH di dalam '$SRC'. Pastikan flashdisknya kesalin utuh."
  fi
fi

title "Muat image dari flashdisk (arsitektur laptop ini: $ARCH)"
n=0; gagal=0
for f in "$DIR"/*.tar.gz; do
  [ -f "$f" ] || continue
  n=$((n+1))
  printf '  [%s] %s\n' "$n" "$(basename "$f")"
  if ! docker load -i "$f" >/dev/null 2>&1; then
    bad "    gagal: $(basename "$f")"
    gagal=$((gagal+1))
  fi
done

printf '\n'
if [ "$n" = "0" ]; then
  die "Nol berkas .tar.gz di '$DIR'. Salah folder?"
elif [ "$gagal" = "0" ]; then
  ok "$n image termuat. Semua lab sekarang bisa dijalankan TANPA internet."
  info "Coba: ./lab up 00a"
else
  warn "$n berkas dicoba, $gagal gagal. Panggil instruktur, tunjukin layar ini."
fi
