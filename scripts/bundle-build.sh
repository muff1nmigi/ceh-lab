#!/usr/bin/env bash
# INSTRUKTUR SAJA. Bikin bundel offline dua arsitektur buat disalin ke flashdisk.
#
#   bash scripts/bundle-build.sh /Volumes/FLASHDISK/ceh-bundle
#
# Hasilnya dua folder: bundle-arm64/ dan bundle-amd64/, masing-masing satu
# .tar.gz per image plus SHA256SUMS. Peserta cuma butuh SATU folder sesuai
# laptopnya, dan ./lab offline load yang milih sendiri.
#
# Kenapa satu tar per image, bukan satu tar raksasa: kalau salinan ke flashdisk
# putus di tengah, yang perlu diulang cuma satu berkas. Dan peserta bisa mulai
# load duluan sambil sisanya masih nyalin.
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/common.sh"

OUT="${1:-}"
[ -n "$OUT" ] || die "Pakai: bash scripts/bundle-build.sh <folder tujuan>"
detect_engine; detect_compose

# ---------------------------------------------------------------------------
# 1. Kumpulin semua image dari semua lab, termasuk yang di balik profil.
# ---------------------------------------------------------------------------
LIST="$(mktemp)"; trap 'rm -f "$LIST"' EXIT
for d in "$LABS_DIR"/*/; do
  d="${d%/}"
  [ "$(basename "$d")" = "_template" ] && continue
  [ -f "$d/meta.env" ] || continue
  resolve_lab "$(meta_get "$d/meta.env" ID)" || continue
  COMPOSE_PROFILES="bonus,x86" dc config --images 2>/dev/null >> "$LIST"
done
sort -u "$LIST" | grep -v '^$' > "$LIST.uniq" && mv "$LIST.uniq" "$LIST"
TOTAL="$(wc -l < "$LIST" | tr -d ' ')"
title "Bundel offline: $TOTAL image, dua arsitektur"

sanitize() { printf '%s' "$1" | tr '/:' '__' | tr -cd '[:alnum:]._-'; }

build_one_arch() {
  TARGET_ARCH="$1"
  DIR="$OUT/bundle-$TARGET_ARCH"
  mkdir -p "$DIR"
  : > "$DIR/manifest.txt"
  n=0
  while IFS= read -r img; do
    [ -n "$img" ] || continue
    n=$((n+1))
    plat="linux/$TARGET_ARCH"
    printf '  [%s/%s] %s  %s\n' "$n" "$TOTAL" "$TARGET_ARCH" "$img"
    if ! docker pull -q --platform "$plat" "$img" >/dev/null 2>&1; then
      # Image ini ga punya varian buat arsitektur itu. Buat laptop arm64,
      # yang bener adalah tetap bawa versi amd64-nya, karena di laptop peserta
      # dia bakal jalan lewat emulasi. Jadi bundelnya per-LAPTOP, bukan per-image.
      if [ "$TARGET_ARCH" = "arm64" ] && docker pull -q --platform linux/amd64 "$img" >/dev/null 2>&1; then
        plat="linux/amd64"
        warn "    $img ga punya arm64, dibawain versi amd64 (nanti jalan emulasi)"
      else
        bad "    $img GAGAL ditarik, dilewat"
        printf 'GAGAL %s\n' "$img" >> "$DIR/manifest.txt"
        continue
      fi
    fi
    f="$DIR/$(sanitize "$img").tar"
    docker save --platform "$plat" -o "$f" "$img" || { bad "    save gagal: $img"; continue; }
    gzip -f "$f"
    printf '%s %s %s\n' "$img" "$plat" "$(basename "$f").gz" >> "$DIR/manifest.txt"
  done < "$LIST"

  ( cd "$DIR" && \
    if command -v sha256sum >/dev/null 2>&1; then sha256sum ./*.tar.gz > SHA256SUMS
    else shasum -a 256 ./*.tar.gz > SHA256SUMS; fi )
  ok "bundle-$TARGET_ARCH selesai: $(du -sh "$DIR" | awk '{print $1}')"
}

build_one_arch amd64
build_one_arch arm64

# Salin juga isi repo biar flashdisk-nya berdiri sendiri, tanpa perlu git clone.
mkdir -p "$OUT/repo"
( cd "$REPO_ROOT" && tar --exclude .git -cf - . ) | ( cd "$OUT/repo" && tar -xf - )

cat > "$OUT/BACA-SAYA.txt" <<'EOF'
BUNDEL OFFLINE LAB CEH

Kalau internet kelas mati, ini yang lo pakai. Tiga langkah:

1. Salin folder "repo" ke laptop lo, kasih nama ceh-lab.
2. Buka terminal di folder itu.
3. macOS / Linux :  ./lab offline load /Volumes/NAMA-FLASHDISK
   Windows       :  .\lab.cmd offline load E:\

Skripnya sendiri yang milih bundel arm64 atau amd64 sesuai laptop lo.
Lo GA PERLU tau laptop lo arsitektur apa.
EOF
ok "Bundel siap di $OUT"
