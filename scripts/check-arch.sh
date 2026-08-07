#!/usr/bin/env bash
# GERBANG MUTU, jalan di CI dan boleh dijalanin tangan.
# Aturannya satu kalimat: tiap image harus punya varian arm64, ATAU dipin
# eksplisit "platform: linux/amd64" di compose lab-nya.
# Ini yang nyegah salah tulis seperti vulnerables/web-dvwa (amd64 doang)
# nyelip diam-diam dan bikin separuh kelas kena emulasi tanpa sadar.
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/common.sh"
detect_engine; detect_compose
FAILFILE="$(mktemp)"; trap 'rm -f "$FAILFILE"' EXIT

# Keluaran polos "imagetools inspect" yang dibaca, BUKAN --format.
# Alasannya terukur: bentuk --format bikin buildx menarik tiap manifest anak
# satu per satu, dan registry balik 429 walau image-nya baik-baik saja.
# public.ecr.aws kebukti begitu pada 2026-08-06, sementara keluaran polosnya
# jalan mulus karena cuma butuh satu permintaan ke index.
plats_of() {
  out="$(docker buildx imagetools inspect "$1" 2>/dev/null \
    | awk '/^[[:space:]]*Platform:[[:space:]]/{print $2}' \
    | grep -v unknown | sort -u | tr '\n' ' ')"
  if [ -z "$out" ]; then
    # Image satu arsitektur tanpa index tetap balik lewat --format .Image.
    out="$(docker buildx imagetools inspect "$1" --format '{{.Image.OS}}/{{.Image.Architecture}}' 2>/dev/null)"
  fi
  case "$out" in *'<no value>'*) out='' ;; esac
  printf '%s' "$out"
}

pinned() { # pinned <compose file> <image>
  awk -v img="$2" '
    $0 ~ "image:[ \t]*"img"[ \t]*$" {found=1; next}
    found && /^[ \t]*platform:[ \t]*linux\/amd64[ \t]*$/ {print "yes"; exit}
    found && /^[ \t]*[a-z_-]+:/ && !/^[ \t]*(platform|container_name|command|ports|environment|volumes|profiles|cap_add|networks|depends_on|restart|hostname|build|healthcheck|security_opt|init|tty|stdin_open|working_dir|user|entrypoint|sysctls|tmpfs|expose|labels|deploy|mem_limit|cpus):/ {exit}
  ' "$1" | grep -q yes
}

check_lab() {
  resolve_lab "$1" || return 0
  printf '\n  lab %s\n' "$LAB_ID"
  imgs="$(COMPOSE_PROFILES="bonus,x86" dc config --images 2>/dev/null | sort -u)"
  for img in $imgs; do
    case "$img" in ''|*'${'*) continue ;; esac
    # Image yang dibangun di laptop peserta tidak pernah ada di registry mana
    # pun, jadi "imagetools inspect" pasti gagal untuk dia. Melewatinya bukan
    # kelonggaran: arsitekturnya selalu mengikuti laptop yang mem-build.
    # Selain toolbox, ada lab yang membangun targetnya sendiri (lab 03
    # membangun Domain Controller dari dc/Dockerfile). Semua image lokal
    # memakai awalan "ceh-", dan awalan itu yang jadi penandanya.
    case "$img" in
      "$TOOLBOX_IMAGE"|ceh-*)
        printf '    OK-LOKAL %-52s dibangun lokal, ga ada di registry\n' "$img"
        continue
        ;;
    esac
    p="$(plats_of "$img")"
    if [ -z "$p" ]; then
      printf '    ?        %-52s manifest ga kebaca (429 atau image ga ada). Ulangi nanti.\n' "$img"
      echo x >> "$FAILFILE"
    elif printf '%s' "$p" | grep -q arm64; then
      printf '    OK       %-52s %s\n' "$img" "$p"
    elif pinned "$LAB_DIR/compose.yaml" "$img"; then
      printf '    OK-EMU   %-52s %s, udah dipin platform\n' "$img" "$p"
    else
      printf '    LANGGAR  %-52s %s TANPA platform: linux/amd64\n' "$img" "$p"
      echo x >> "$FAILFILE"
    fi
  done
}

title "Cek arsitektur image"
if [ -n "${1:-}" ]; then
  check_lab "$1"
else
  for d in "$LABS_DIR"/*/; do
    d="${d%/}"; [ "$(basename "$d")" = "_template" ] && continue
    [ -f "$d/meta.env" ] || continue
    check_lab "$(meta_get "$d/meta.env" ID)"
  done
fi
printf '\n'
if [ -s "$FAILFILE" ]; then
  bad "$(wc -l < "$FAILFILE" | tr -d ' ') image bermasalah. Betulin sebelum di-push."
  exit 1
fi
ok "Semua image beres."
