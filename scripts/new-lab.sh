#!/usr/bin/env bash
# INSTRUKTUR. Bikin lab baru dari kerangka. Konsistensi dijaga sama skrip, bukan sama ingatan.
#   bash scripts/new-lab.sh 18b mqtt-inject 18 "IoT and OT Hacking" "Inject perintah palsu ke broker MQTT"
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/common.sh"
ID="${1:-}"; SLUG="${2:-}"; MODUL="${3:-}"; MODUL_NAMA="${4:-}"; JUDUL="${5:-}"
[ -n "$ID" ] && [ -n "$SLUG" ] || die 'Pakai: bash scripts/new-lab.sh <id> <slug> <modul> "<nama modul>" "<judul>"'
printf '%s' "$ID" | grep -Eq '^[0-9]{2}[a-z]$' || die "ID harus dua angka plus satu huruf, contoh 18b. Dapetnya '$ID'."
DEST="$LABS_DIR/$ID-$SLUG"
[ -e "$DEST" ] && die "Folder $DEST udah ada."
cp -R "$LABS_DIR/_template" "$DEST"
sed -i.bak -e "s|__ID__|$ID|g" -e "s|__MODUL__|$MODUL|g" -e "s|__MODUL_NAMA__|$MODUL_NAMA|g" -e "s|__JUDUL__|$JUDUL|g" \
  "$DEST/meta.env" "$DEST/README.md"
rm -f "$DEST"/*.bak
ok "Lab baru: $DEST"
info "Sunting compose.yaml dan README.md, lalu: bash scripts/check-arch.sh $ID"
info "Tiga hal yang paling sering bikin CI merah di lab baru:"
info "  1. port ga diikat ke 127.0.0.1, tulisnya harus \"127.0.0.1:8080:80\""
info "  2. service yang punya URL lupa nulis: networks: [default, edge]"
info "  3. URL di meta.env nunjuk port yang ga dipublish di compose.yaml"
