#!/usr/bin/env bash
# Pengukur ketersediaan layanan. Dijalankan DI DALAM toolbox.
#
#   bash /lab/serang/ukur.sh web        10 permintaan ke target rentan
#   bash /lab/serang/ukur.sh web-aman   10 permintaan ke target termitigasi
#   bash /lab/serang/ukur.sh web 20 3   20 permintaan, batas tunggu 3 detik
#
# Ini alat ukurnya, bukan alat serangnya. Jalankan sebelum serangan untuk
# mendapat angka dasar, lalu jalankan lagi saat serangan berlangsung, di
# jendela terminal yang berbeda.
#
# Angka yang keluar:
#   kode   kode status HTTP. 000 berarti curl tidak dapat jawaban sama sekali,
#          entah karena koneksi ditolak, di-reset, atau habis waktu tunggu.
#   detik  waktu total satu permintaan, dari mulai sampai selesai.
set -uo pipefail

TARGET="${1:-web}"
JUMLAH="${2:-10}"
BATAS="${3:-5}"

case "$TARGET" in
  web|web-aman) ;;
  *)
    printf 'PAGAR: target sah cuma "web" dan "web-aman". Diberi: %s\n' "$TARGET"
    exit 1
    ;;
esac

printf 'mengukur http://%s/ , %s permintaan, batas tunggu %s detik\n\n' \
  "$TARGET" "$JUMLAH" "$BATAS"
printf '  %-4s %-6s %s\n' "no" "kode" "detik"

sukses=0
gagal=0
jumlah_waktu=0
i=1
while [ "$i" -le "$JUMLAH" ]; do
  hasil="$(curl -s -o /dev/null -m "$BATAS" \
    -w '%{http_code} %{time_total}' "http://$TARGET/" 2>/dev/null)"
  [ -n "$hasil" ] || hasil="000 $BATAS"
  kode="${hasil%% *}"
  waktu="${hasil##* }"
  printf '  %-4s %-6s %s\n' "$i" "$kode" "$waktu"
  if [ "$kode" = "200" ]; then
    sukses=$((sukses + 1))
  else
    gagal=$((gagal + 1))
  fi
  jumlah_waktu="$(awk -v a="$jumlah_waktu" -v b="$waktu" 'BEGIN{print a+b}')"
  i=$((i + 1))
done

printf '\n  berhasil : %s dari %s\n' "$sukses" "$JUMLAH"
printf '  gagal    : %s\n' "$gagal"
printf '  rata-rata: %s detik\n' \
  "$(awk -v t="$jumlah_waktu" -v n="$JUMLAH" 'BEGIN{printf "%.3f", t/n}')"

printf '\n  metrik pekerja Apache:\n'
metrik="$(curl -s -m "$BATAS" "http://$TARGET/server-status?auto" 2>/dev/null \
  | grep -E '^(Total Accesses|BusyWorkers|IdleWorkers|ConnsTotal|ConnsAsyncKeepAlive|ConnsAsyncClosing):')"
if [ -n "$metrik" ]; then
  printf '%s\n' "$metrik" | sed 's/^/    /'
else
  printf '    TIDAK TERBACA. Halaman metrik ikut tidak bisa dibuka, dan itu\n'
  printf '    bukan kerusakan alat ukur: /server-status juga butuh satu\n'
  printf '    pekerja Apache, dan pekerjanya sedang habis.\n'
fi
exit 0
