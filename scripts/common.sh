# shellcheck shell=bash
# Berkas ini cuma di-source, dan sebagian variabelnya (MIN_RAM_GB, ENGINE_CPUS,
# dan kawan-kawan) dibaca sama ./lab, bukan sama dirinya sendiri. Dari sudut
# pandang linter itu kelihatan seperti variabel nganggur, jadi SC2034 dimatikan
# di sini. Kalau ga, gerbangnya di CI merah terus tanpa ada yang salah.
# shellcheck disable=SC2034
# Dipakai bareng semua skrip. Jangan dijalanin langsung, di-source dari ./lab.

set -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT
LABS_DIR="$REPO_ROOT/labs"
SHARED_COMPOSE="$REPO_ROOT/_shared/compose.base.yaml"
INTERNET_COMPOSE="$REPO_ROOT/_shared/compose.internet.yaml"
# Toolbox dibangun di laptop peserta, bukan ditarik dari registry. Nilai ini
# harus sama persis dengan default TOOLBOX_IMAGE di _shared/compose.base.yaml.
TOOLBOX_IMAGE="${TOOLBOX_IMAGE:-ceh-toolbox:1.0}"
export TOOLBOX_IMAGE
# Kandidat image mungil buat nguji emulasi. Tiga registry beda, karena
# SEMUANYA bisa kena 429: Docker Hub 100 tarikan per jam per IP buat anonim,
# dan public.ecr.aws juga kebukti bisa balik "Rate exceeded".
PROBE_IMAGES="public.ecr.aws/docker/library/busybox:latest quay.io/quay/busybox:latest busybox:latest"
MIN_DISK_GB=25
MIN_RAM_GB=6

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_R=$'\033[31m'; C_G=$'\033[32m'; C_Y=$'\033[33m'; C_B=$'\033[1m'; C_0=$'\033[0m'
else
  C_R=''; C_G=''; C_Y=''; C_B=''; C_0=''
fi

ok()    { printf '%s  OK  %s %s\n'  "$C_G" "$C_0" "$1"; }
warn()  { printf '%s WARN %s %s\n'  "$C_Y" "$C_0" "$1"; }
bad()   { printf '%s GAGAL%s %s\n'  "$C_R" "$C_0" "$1"; }
info()  { printf '       %s\n' "$1"; }
title() { printf '\n%s%s%s\n' "$C_B" "$1" "$C_0"; }
die()   { bad "$1"; exit 1; }

# Baca satu kunci dari berkas KEY=value tanpa source, tanpa jq, tanpa yq.
meta_get() {
  [ -f "$1" ] || return 0
  awk -F'=' -v k="$2" 'index($0,"#")==1{next} $1==k{sub(/^[^=]*=/,""); print; exit}' "$1"
}

# ---------------------------------------------------------------------------
# DETEKSI. Sumber kebenaran itu Docker Engine, bukan sistem operasi peserta.
# ---------------------------------------------------------------------------
detect_engine() {
  command -v docker >/dev/null 2>&1 || die \
    "Docker belum terpasang. Baca docs/01-pasang-docker-windows.md atau docs/02-pasang-docker-macos.md"

  if ! docker info >/dev/null 2>&1; then
    die "Docker terpasang tetapi engine-nya mati. Buka aplikasi Docker Desktop atau OrbStack, tunggu ikonnya hidup, lalu ulangi."
  fi

  ENGINE_ARCH_RAW="$(docker info --format '{{.Architecture}}' 2>/dev/null)"
  ENGINE_OS="$(docker info --format '{{.OSType}}' 2>/dev/null)"
  ENGINE_MEM_BYTES="$(docker info --format '{{.MemTotal}}' 2>/dev/null)"
  ENGINE_CPUS="$(docker info --format '{{.NCPU}}' 2>/dev/null)"

  case "$ENGINE_ARCH_RAW" in
    x86_64|amd64)  ARCH=amd64; HOST_PLATFORM=linux/amd64 ;;
    aarch64|arm64) ARCH=arm64; HOST_PLATFORM=linux/arm64 ;;
    *)             ARCH=unknown; HOST_PLATFORM='' ;;
  esac
  export ARCH HOST_PLATFORM

  if [ "$ENGINE_OS" != "linux" ]; then
    die "Docker sedang berada di mode container Windows. Klik kanan ikon Docker di taskbar, pilih 'Switch to Linux containers', lalu ulangi."
  fi
}

detect_compose() {
  docker compose version >/dev/null 2>&1 || die \
    "'docker compose' tidak tersedia. Docker Desktop versi baru sudah membawanya. Kalau Anda memasang docker.io dari apt, pasang juga paket docker-compose-plugin."
}

# Uji beneran, bukan asumsi: bisa ga engine ini jalanin container amd64.
# EMU_OK: 1 bisa, 0 ga bisa, 2 ga ketauan (image ujinya ga bisa ditarik).
# Bedain tiga keadaan itu penting: "ga bisa narik image" bukan berarti
# "emulasi rusak", dan salah nyimpulin bikin peserta panik ga perlu.
probe_amd64() {
  if [ "$ARCH" = "amd64" ]; then EMU_OK=1; export EMU_OK; return 0; fi
  EMU_OK=2
  for p in $PROBE_IMAGES; do
    docker image inspect "$p" >/dev/null 2>&1 || docker pull -q --platform linux/amd64 "$p" >/dev/null 2>&1 || continue
    if docker run --rm --platform linux/amd64 "$p" true >/dev/null 2>&1; then EMU_OK=1; else EMU_OK=0; fi
    break
  done
  export EMU_OK
}

# Satu image uji yang beneran kepakai, buat doctor.
probe_image_ok() {
  for p in $PROBE_IMAGES; do
    if docker pull -q "$p" >/dev/null 2>&1; then return 0; fi
  done
  return 1
}

# ---------------------------------------------------------------------------
# RESOLUSI LAB. Peserta ngetik "05", skripnya yang cari foldernya.
# ---------------------------------------------------------------------------
resolve_lab() {
  local want="$1" hit n
  [ -n "$want" ] || die "Sebutkan ID labnya. Contoh: ./lab up 05   (lihat daftarnya: ./lab list)"
  hit=""
  n=0
  # Nama folder utuh diterima juga, bukan cuma prefix-nya. Peserta menyalin
  # "01-scanning-enum" dari README dan jadwal, dan menolak salinan itu adalah
  # cara paling gampang bikin perintah pertama mereka gagal tanpa sebab jelas.
  if [ -d "$LABS_DIR/$want" ] && [ "$want" != "_template" ]; then
    hit="$LABS_DIR/$want"
    n=1
    want="${want%%-*}"
  else
    for d in "$LABS_DIR"/"$want"-*; do
      [ -d "$d" ] || continue
      hit="$d"; n=$((n+1))
    done
  fi
  if [ "$n" -eq 0 ]; then
    bad "Lab '$want' tidak ditemukan."
    info "Daftar lab yang ada: ./lab list"
    exit 1
  fi
  [ "$n" -gt 1 ] && die "ID '$want' cocok ke lebih dari satu folder. Ini bug repo, lapor ke instruktur."
  LAB_DIR="$hit"
  LAB_ID="$want"
  LAB_PROJECT="ceh-$want"
  LAB_META="$LAB_DIR/meta.env"
  [ -f "$LAB_DIR/compose.yaml" ] || die "Lab '$want' rusak, compose.yaml-nya tidak ada."
  # Satu-satunya saklar yang mengizinkan lab nyentuh internet. Isinya harus
  # persis "1". Selain itu, network "internet" ga pernah dibikin.
  LAB_INTERNET=0
  [ "$(meta_get "$LAB_META" INTERNET)" = "1" ] && LAB_INTERNET=1
  export LAB_DIR LAB_ID LAB_PROJECT LAB_META LAB_INTERNET
}

# Bungkus docker compose supaya --project-directory ga pernah kelupaan.
# Tanpa flag itu, './files' di compose lab bakal nyasar ke _shared/files.
# Berkas internet ditumpuk PALING AKHIR supaya setelan toolbox-nya menang.
dc() {
  if [ "${LAB_INTERNET:-0}" = "1" ]; then
    docker compose \
      -p "$LAB_PROJECT" \
      --project-directory "$LAB_DIR" \
      -f "$SHARED_COMPOSE" \
      -f "$LAB_DIR/compose.yaml" \
      -f "$INTERNET_COMPOSE" \
      "$@"
  else
    docker compose \
      -p "$LAB_PROJECT" \
      --project-directory "$LAB_DIR" \
      -f "$SHARED_COMPOSE" \
      -f "$LAB_DIR/compose.yaml" \
      "$@"
  fi
}

# Toolbox ada di laptop ini belum. Dipakai ./lab up dan ./lab doctor.
toolbox_ready() { docker image inspect "$TOOLBOX_IMAGE" >/dev/null 2>&1; }

# Berapa layanan di lab ini yang dipaksa amd64. Dibaca dari berkas kita sendiri,
# jadi nol ketergantungan ke jq atau yq.
# Pakai awk, bukan "grep -c || echo 0": grep -c udah nyetak "0" waktu ga ketemu
# TAPI exit code-nya 1, jadi versi lama nyetak dua baris "0" dan bikin
# perbandingan angka di pemanggilnya rusak diam-diam.
count_emulated() {
  awk '/^[[:space:]]*platform:[[:space:]]*linux\/amd64[[:space:]]*$/{n++} END{print n+0}' \
    "$LAB_DIR/compose.yaml" 2>/dev/null || echo 0
}

human_gb() { awk -v b="$1" 'BEGIN{printf "%.1f", b/1073741824}'; }
