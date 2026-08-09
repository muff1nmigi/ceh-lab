#!/usr/bin/env bash
# ============================================================================
# Build toolbox penyerang lab CEH, untuk macOS dan Linux.
#
#   bash toolbox/build.sh
#
# Pilihan tambahan, semuanya opsional:
#   bash toolbox/build.sh --no-cache     ulang dari nol, abaikan cache
#   bash toolbox/build.sh --quiet        keluaran build diringkas
#
# Skrip ini mendeteksi sendiri arsitektur laptop dan membangun image native,
# jadi tidak ada yang perlu diubah baik di Apple Silicon maupun Intel/AMD.
# ============================================================================
set -uo pipefail

IMAGE_NAME="ceh-toolbox"
IMAGE_TAG="1.0"
IMAGE="$IMAGE_NAME:$IMAGE_TAG"
CTX="$(cd "$(dirname "$0")" && pwd)"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_R=$'\033[31m'; C_G=$'\033[32m'; C_Y=$'\033[33m'; C_B=$'\033[1m'; C_0=$'\033[0m'
else
  C_R=''; C_G=''; C_Y=''; C_B=''; C_0=''
fi
ok()    { printf '%s  OK  %s %s\n' "$C_G" "$C_0" "$1"; }
warn()  { printf '%s WARN %s %s\n' "$C_Y" "$C_0" "$1"; }
bad()   { printf '%s GAGAL%s %s\n' "$C_R" "$C_0" "$1"; }
info()  { printf '       %s\n' "$1"; }
title() { printf '\n%s%s%s\n' "$C_B" "$1" "$C_0"; }

NOCACHE=""
PROGRESS="plain"
for a in "$@"; do
  case "$a" in
    --no-cache) NOCACHE="--no-cache" ;;
    --quiet|-q) PROGRESS="auto" ;;
    -h|--help)  sed -n '2,14p' "$0"; exit 0 ;;
    *) bad "Pilihan '$a' tidak dikenal. Yang ada: --no-cache, --quiet"; exit 1 ;;
  esac
done

title "BUILD TOOLBOX LAB CEH"

# ---------------------------------------------------------------------------
# 1. Pastikan Docker ada dan hidup. Dua keadaan ini beda, dan solusinya beda,
#    jadi pesannya juga harus beda.
# ---------------------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  bad "Docker belum terpasang di laptop ini."
  info "Baca docs/02-pasang-docker-di-kali.md"
  info "Windows : jalankan build.ps1, bukan build.sh"
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  bad "Docker terpasang tetapi mesinnya belum jalan."
  info "Buka aplikasi Docker Desktop, tunggu sampai ikonnya hijau, lalu ulangi perintah ini."
  exit 1
fi
ok "Docker jalan, versi $(docker version --format '{{.Client.Version}}' 2>/dev/null)"

# ---------------------------------------------------------------------------
# 2. Deteksi arsitektur. Yang dipercaya adalah Docker Engine, bukan sistem
#    operasinya, karena engine bisa saja jalan di VM dengan arsitektur lain.
# ---------------------------------------------------------------------------
RAW="$(docker info --format '{{.Architecture}}' 2>/dev/null)"
OSTYPE_D="$(docker info --format '{{.OSType}}' 2>/dev/null)"
case "$RAW" in
  x86_64|amd64)  ARCH="amd64"; PLATFORM="linux/amd64"; LABEL="Intel atau AMD" ;;
  aarch64|arm64) ARCH="arm64"; PLATFORM="linux/arm64"; LABEL="Apple Silicon atau ARM" ;;
  *)             ARCH="";      PLATFORM="";            LABEL="" ;;
esac
if [ "$OSTYPE_D" != "linux" ]; then
  bad "Docker sedang di mode container Windows."
  info "Klik kanan ikon Docker di taskbar, pilih 'Switch to Linux containers', lalu ulangi."
  exit 1
fi
if [ -z "$ARCH" ]; then
  warn "Arsitektur '$RAW' tidak dikenal. Build tetap dilanjutkan tanpa --platform."
  info "Kirim baris ini ke instruktur supaya dicatat."
else
  ok "Arsitektur terdeteksi: $ARCH ($LABEL). Image dibangun native, tanpa emulasi."
fi

# ---------------------------------------------------------------------------
# 3. Jaga supaya tag di sini tidak melenceng dari yang dicari compose.
#    Kalau dua berkas ini beda, gejalanya "image tidak ditemukan" saat lab
#    dinyalakan, dan penyebabnya tidak kelihatan sama sekali dari pesan itu.
# ---------------------------------------------------------------------------
BASE_YML="$(cd "$CTX/.." 2>/dev/null && pwd)/_shared/compose.base.yaml"
if [ -f "$BASE_YML" ] && ! grep -q "TOOLBOX_IMAGE:-$IMAGE}" "$BASE_YML"; then
  warn "Tag di skrip ini ($IMAGE) tidak cocok dengan default di _shared/compose.base.yaml."
  info "Ini bug repo, tolong laporkan ke instruktur."
  info "Sementara bisa dipaksa dengan:  TOOLBOX_IMAGE=$IMAGE ./lab up <id>"
fi

# ---------------------------------------------------------------------------
# 4. Build. Basisnya satu image saja dari Docker Hub, sisanya dari repo Kali,
#    jadi batas 100 tarikan per jam Docker Hub praktis tidak tersentuh.
# ---------------------------------------------------------------------------
info "konteks build : $CTX"
info "tag hasil     : $IMAGE"
info "Perlu internet dan sekitar 3 sampai 10 menit, tergantung kecepatan jaringan."
printf '\n'

START="$(date +%s)"
set -- build $NOCACHE --progress="$PROGRESS" -t "$IMAGE" -t "$IMAGE_NAME:latest"
[ -n "$PLATFORM" ] && set -- "$@" --platform "$PLATFORM"
set -- "$@" "$CTX"

if ! docker "$@"; then
  ELAPSED=$(( $(date +%s) - START ))
  printf '\n'
  bad "Build gagal setelah ${ELAPSED} detik."
  info "Tiga penyebab yang paling sering, urut dari yang paling sering:"
  info "1. Internet putus atau lambat waktu apt mengambil paket."
  info "   Solusi: sambungkan ulang, jalankan lagi perintah yang sama."
  info "2. Repo Kali sedang tidak sinkron, biasanya pesannya"
  info "   'Hash Sum mismatch' atau '404 Not Found'."
  info "   Solusi: ulangi dengan  bash toolbox/build.sh --no-cache"
  info "3. Disk penuh, pesannya 'no space left on device'."
  info "   Solusi: jalankan  docker system prune -a  lalu ulangi."
  info "Kalau masih gagal, salin 20 baris terakhir layar ini dan kirim ke instruktur."
  exit 1
fi
ELAPSED=$(( $(date +%s) - START ))

# ---------------------------------------------------------------------------
# 5. Uji singkat. Image yang berhasil dibangun belum tentu isinya jalan,
#    jadi jangan berhenti di kata "Successfully built".
# ---------------------------------------------------------------------------
printf '\n'
title "UJI SINGKAT"
SMOKE='nmap --version | head -1; printf "john "; john --list=build-info | head -1; printf "sqlmap "; sqlmap --version; gobuster --version | head -1'
if OUT="$(docker run --rm "$IMAGE" sh -c "$SMOKE" 2>&1)"; then
  printf '%s\n' "$OUT" | sed 's/^/       /'
  ok "Perkakas inti menjawab."
else
  bad "Image terbangun tetapi gagal dijalankan. Kirim keluaran ini ke instruktur."
  printf '%s\n' "$OUT" | sed 's/^/       /'
  exit 1
fi

# Yang dilaporkan adalah pemakaian disk, bukan ukuran unduhan. Dua angka ini
# beda jauh, dan yang bikin disk peserta penuh adalah yang pertama.
SIZE="$(docker images "$IMAGE" --format '{{.Size}}' 2>/dev/null | head -1)"
printf '\n'
ok "Toolbox siap. Tag: $IMAGE"
info "waktu build   : ${ELAPSED} detik"
info "pakai disk    : ${SIZE:-tidak terbaca}"
info "Langkah berikutnya:  ./lab doctor"
printf '\n'
