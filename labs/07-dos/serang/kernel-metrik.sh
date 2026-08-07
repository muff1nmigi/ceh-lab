#!/bin/sh
# Metrik TCP dari SISI TARGET. Dijalankan DI DALAM container target, bukan
# di toolbox, karena angka-angka ini milik kernel target.
#
#   ./lab sh 07 web        lalu   sh /serang/kernel-metrik.sh
#   ./lab sh 07 web-aman   lalu   sh /serang/kernel-metrik.sh
#
# Yang perlu dibaca:
#   SyncookiesSent      berapa kali kernel menjawab dengan SYN cookie, bukan
#                       dengan menyimpan koneksi setengah jadi. Nol di target
#                       rentan karena fiturnya memang dimatikan.
#   TCPReqQFullDoCookies antrean SYN penuh, dan kernel memilih mengirim cookie.
#                       Ini pertahanan yang bekerja.
#   TCPReqQFullDrop     antrean SYN penuh, dan kernel memilih MEMBUANG paket.
#                       Tiap satuan di sini adalah satu calon pengunjung yang
#                       koneksinya tidak pernah dijawab.
#   ListenDrops         paket dibuang di soket yang sedang mendengarkan.

echo "== SYN saat ini menunggu di antrean (state 03 = SYN_RECV) =="
awk 'NR>1 && $4=="03"' /proc/net/tcp | wc -l

echo
echo "== saklar kernel =="
printf 'tcp_syncookies       : '; cat /proc/sys/net/ipv4/tcp_syncookies
printf 'tcp_max_syn_backlog  : '; cat /proc/sys/net/ipv4/tcp_max_syn_backlog

echo
echo "== penghitung sejak container ini nyala =="
grep -A1 '^TcpExt:' /proc/net/netstat | awk '
  NR==1 { for (i = 1; i <= NF; i++) nama[i] = $i }
  NR==2 { for (i = 1; i <= NF; i++)
            if (nama[i] ~ /Syncookies|ListenDrops|ListenOverflows|ReqQFull/)
              printf "%-22s %s\n", nama[i], $i }'
