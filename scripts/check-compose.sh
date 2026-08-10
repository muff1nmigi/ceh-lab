#!/usr/bin/env bash
# GERBANG MUTU compose. Jalan di CI, dan boleh dijalankan tangan kapan saja:
#
#   bash scripts/check-compose.sh          semua lab
#   bash scripts/check-compose.sh 05      satu lab
#
# Yang dijaga di sini semuanya pernah jadi bug beneran, bukan gaya penulisan:
#
#   1. Jaringan lab wajib internal. Ini pagar yang bikin "nmap ke subnet
#      kelas" mati, dan sekali ada lab yang bocor, pagarnya hilang buat lab
#      itu tanpa ada yang sadar.
#   2. Toolbox cuma boleh nempel di jaringan lab. Kalau dia ikut ke "edge",
#      dia dapat jalan keluar lagi.
#   3. Port wajib diikat ke 127.0.0.1, bukan 0.0.0.0. Target lab sengaja
#      rapuh, dan 0.0.0.0 bikin dia kelihatan dari seluruh jaringan kantor.
#   4. URL di meta.env wajib punya port yang beneran dipublish. Tanpa gerbang
#      ini, lab yang cuma jalan karena akses langsung ke IP container lolos di
#      OrbStack dan gagal di Docker Desktop yang dipakai peserta.
#   5. Nol image amd64-only di jalur wajib.
#   6. Nol konstruksi yang membatalkan pagar: privileged, network_mode,
#      pid/ipc host, dan mount soket Docker.
#
# Skrip ini TIDAK butuh engine Docker jalan, cuma butuh "docker compose"
# (config dikerjakan di sisi klien) dan jq.
set -uo pipefail
. "$(cd "$(dirname "$0")" && pwd)/common.sh"

command -v jq >/dev/null 2>&1 || die "jq belum kepasang. macOS: brew install jq. Ubuntu: apt-get install -y jq"
docker compose version >/dev/null 2>&1 || die "'docker compose' ga ada."

AMD64_LIST="$REPO_ROOT/_shared/amd64-only.txt"
RC=0
PORTFILE="$(mktemp)"; trap 'rm -f "$PORTFILE" "$PORTFILE.cfg"' EXIT

fail() { bad "$1"; RC=1; }

# Port host dari URL. Tanpa port eksplisit, http itu 80 dan https itu 443.
url_port() {
  case "$1" in
    *://*:[0-9]*) printf '%s' "$1" | sed -e 's|^[a-z]*://[^:/]*:||' -e 's|[^0-9].*$||' ;;
    https://*)    printf '443' ;;
    http://*)     printf '80' ;;
    *)            printf '' ;;
  esac
}

check_lab() {
  resolve_lab "$1"
  local nama; nama="$(basename "$LAB_DIR")"
  printf '\n  lab %s (%s)\n' "$LAB_ID" "$nama"

  # -------------------------------------------------------------------
  # Saklar internet. Ini yang nentuin network apa aja yang boleh muncul.
  # -------------------------------------------------------------------
  local inet; inet="$(meta_get "$LAB_META" INTERNET)"
  case "${inet:-0}" in
    ''|0) inet=0 ;;
    1)    inet=1 ;;
    *)    fail "    INTERNET di meta.env isinya '$inet'. Cuma boleh 0 atau 1."; inet=0 ;;
  esac
  if [ "$inet" = "1" ]; then
    if grep -q '^## Kenapa lab ini butuh internet[[:space:]]*$' "$LAB_DIR/README.md" 2>/dev/null; then
      warn "    INTERNET=1. Alasannya ada di README, oke."
    else
      fail "    INTERNET=1 tapi README.md ga punya bagian '## Kenapa lab ini butuh internet'."
    fi
  fi

  # -------------------------------------------------------------------
  # Lab ga boleh mendefinisikan network sendiri. Itu satu-satunya cara
  # "default" bisa berhenti jadi internal tanpa kelihatan.
  # -------------------------------------------------------------------
  if grep -qE '^networks:[[:space:]]*$' "$LAB_DIR/compose.yaml"; then
    fail "    compose.yaml mendefinisikan 'networks:' di tingkat atas. Itu tugas _shared/compose.base.yaml."
  fi

  # -------------------------------------------------------------------
  # Konfigurasi yang sudah digabung. Ini yang beneran dijalankan Docker,
  # jadi ini juga yang diperiksa, bukan berkas mentahnya.
  # -------------------------------------------------------------------
  local cfg="$PORTFILE.cfg"
  if ! dc config --format json > "$cfg" 2>/dev/null; then
    fail "    compose RUSAK, 'config' gagal."
    return
  fi

  # 1. Jaringan lab wajib internal.
  if [ "$(jq -r '.networks.default.internal // false' "$cfg")" != "true" ]; then
    fail "    network 'default' BUKAN internal. Pagar jaringan lab ini bolong."
  fi

  # 2. Network yang boleh dipakai service.
  local boleh='["default","edge"]'
  [ "$inet" = "1" ] && boleh='["default","edge","internet"]'
  local nakal
  nakal="$(jq -r --argjson boleh "$boleh" '
    [ .services | to_entries[]
      | . as $s | ($s.value.networks // {"default":null} | keys)
      | map(select(. as $n | $boleh | index($n) | not))
      | select(length > 0) | ($s.key + ": " + (join(","))) ] | .[]' "$cfg" 2>/dev/null)"
  if [ -n "$nakal" ]; then
    printf '%s\n' "$nakal" | while IFS= read -r baris; do
      printf '    network ga dikenal di service %s\n' "$baris"
    done
    fail "    ada service nempel di network yang ga disediakan."
  fi

  # 3. Toolbox cuma di jaringan lab, plus 'internet' kalau lab ini memang
  #    dibolehkan. Ga pernah 'edge'.
  local tbnet; tbnet="$(jq -r '(.services.toolbox.networks // {"default":null}) | keys | join(",")' "$cfg")"
  if [ "$inet" = "1" ]; then
    [ "$tbnet" = "default,internet" ] || fail "    toolbox nempel di '$tbnet', harusnya 'default,internet' buat lab INTERNET=1."
  else
    [ "$tbnet" = "default" ] || fail "    toolbox nempel di '$tbnet', harusnya cuma 'default'."
  fi

  # 4. Service yang ikut 'edge' wajib ikut 'default' juga, kalau ga dia ga
  #    kelihatan dari toolbox dan lab-nya mati tanpa pesan yang jelas.
  local yatim
  yatim="$(jq -r '[ .services | to_entries[]
      | select((.value.networks // {}) | has("edge"))
      | select((.value.networks // {}) | has("default") | not)
      | .key ] | join(" ")' "$cfg")"
  [ -n "$yatim" ] && fail "    service ini di 'edge' tapi ga di 'default': $yatim"

  # 5. Port wajib diikat ke 127.0.0.1.
  local liar
  liar="$(jq -r '[ .services | to_entries[] as $s
      | ($s.value.ports // [])[]
      | select((.host_ip // "") != "127.0.0.1")
      | ($s.key + " " + (.published|tostring)) ] | join(", ")' "$cfg")"
  [ -n "$liar" ] && fail "    port ga diikat ke 127.0.0.1: $liar. Tulis \"127.0.0.1:8080:80\"."

  # Kumpulin port buat cek tabrakan antar lab.
  jq -r '[ .services[].ports // [] ] | flatten | .[] | .published | tostring' "$cfg" \
    | sed 's|-.*||' | while IFS= read -r p; do
        [ -n "$p" ] && printf '%s %s\n' "$p" "$LAB_ID" >> "$PORTFILE"
      done

  # 6. Konstruksi yang membatalkan pagar.
  local bahaya
  bahaya="$(jq -r '[ .services | to_entries[]
      | select((.value.privileged == true)
            or ((.value.network_mode // "") != "")
            or ((.value.pid // "") == "host")
            or ((.value.ipc // "") == "host")
            or ([ (.value.volumes // [])[] | (.source // "") ] | any(test("docker\\.sock"))))
      | .key ] | join(" ")' "$cfg")"
  [ -n "$bahaya" ] && fail "    service ini pakai privileged / network_mode / pid host / mount soket docker: $bahaya"

  # 7. URL di meta.env wajib punya port yang dipublish.
  local url; url="$(meta_get "$LAB_META" URL)"
  if [ -n "$url" ]; then
    local want; want="$(url_port "$url")"
    if [ -z "$want" ]; then
      fail "    URL '$url' ga kebaca portnya."
    elif jq -e --arg p "$want" '[ .services[].ports // [] ] | flatten | any(.published == $p)' "$cfg" >/dev/null; then
      ok "    URL $url nyambung ke port yang dipublish"
    else
      fail "    URL '$url' nunjuk port $want, tapi ga ada satu pun service yang mem-publish port itu."
      info "    Ini bug yang lolos di OrbStack dan gagal di Docker Desktop punya peserta."
    fi
  fi

  # 7b. TIAP layanan target wajib punya healthcheck. Ini gerbang termahal di
  # berkas ini, dan dia lahir dari kegagalan nyata di kelas hari pertama,
  # 2026-08-10: vsftpd di lab 01 mati diam-diam, containernya tetap "Up",
  # "./lab up" tetap bilang sukses, dan peserta baru menemukannya waktu port
  # 21 terbaca "closed" di tengah kelas.
  #
  # Tanpa healthcheck, "docker compose up --wait" cuma menunggu container
  # BERJALAN, bukan LAYANANNYA MENJAWAB. Dengan healthcheck, lab yang
  # layanannya mati gagal keras di "./lab up", di rumah, bukan di kelas.
  #
  # toolbox dikecualikan dan itu disengaja: dia terminal tempat peserta
  # mengetik, bukan target yang harus menjawab protokol.
  local nohc
  nohc="$(jq -r '.services | to_entries[] | select(.key != "toolbox") | select(.value.healthcheck == null) | .key' "$cfg" 2>/dev/null)"
  if [ -n "$nohc" ]; then
    for entry in $nohc; do
      fail "    service '$entry' nol healthcheck."
      info "    Tanpa itu, layanan yang mati tetap terbaca sehat. Lihat lab 01 service ftp buat contohnya."
    done
  else
    ok "    tiap service target punya healthcheck"
  fi

  # 8. Nol image amd64-only di jalur wajib. Jalur wajib = tanpa profile.
  local imgs; imgs="$(COMPOSE_PROFILES='' dc config --images 2>/dev/null | sort -u)"
  local img entry base
  for img in $imgs; do
    # Awalan "ceh-" dipakai semua image yang dibangun lokal (toolbox, dan
    # Domain Controller milik lab 03), jadi tidak ada di daftar amd64-only.
    case "$img" in ''|*'${'*|"$TOOLBOX_IMAGE"|ceh-*) continue ;; esac
    while IFS= read -r entry; do
      case "$entry" in ''|\#*) continue ;; esac
      base="${img##*/}"
      if [ "$img" = "$entry" ] || [ "${img%%:*}" = "$entry" ] || \
         [ "$base" = "$entry" ] || [ "${base%%:*}" = "$entry" ]; then
        fail "    image '$img' cuma punya amd64 dan dipakai di jalur wajib."
        info "    Pindahin ke profiles: [bonus] plus platform: linux/amd64, atau cari gantinya di _shared/amd64-only.txt."
      fi
    done < "$AMD64_LIST"
  done
}

title "Cek compose dan pagar jaringan"
: > "$PORTFILE"
if [ -n "${1:-}" ]; then
  check_lab "$1"
else
  for d in "$LABS_DIR"/*/; do
    d="${d%/}"; [ "$(basename "$d")" = "_template" ] && continue
    [ -f "$d/meta.env" ] || continue
    check_lab "$(meta_get "$d/meta.env" ID)"
  done
fi

# Port host ga boleh kepakai dua lab, kalau ga dua lab ga bisa nyala barengan.
if [ -s "$PORTFILE" ]; then
  DUP="$(awk '{print $1}' "$PORTFILE" | sort | uniq -d)"
  if [ -n "$DUP" ]; then
    printf '\n'
    for p in $DUP; do
      fail "port host $p kepakai lebih dari satu lab: $(awk -v p="$p" '$1==p{printf "%s ", $2}' "$PORTFILE")"
    done
  fi
fi

printf '\n'
if [ "$RC" != "0" ]; then
  bad "Ada yang harus dibetulin di atas."
  exit 1
fi
ok "Semua lab lolos gerbang compose."
