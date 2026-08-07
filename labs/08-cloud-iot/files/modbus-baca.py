#!/usr/bin/env python3
"""Pembaca register Modbus TCP, hanya memakai pustaka bawaan Python.

Dipakai di lab 08. Sengaja pendek dan tanpa dependensi apa pun, karena dua
alasan. Pertama, toolbox Kali di lab ini tidak punya pymodbus dan jaringan lab
tertutup, jadi tidak ada cara memasangnya di kelas. Kedua, dan ini yang lebih
penting untuk exam: seluruh isi berkas ini adalah bukti bahwa Modbus TCP tidak
punya lapisan autentikasi. Tidak ada nama pengguna, tidak ada sandi, tidak ada
token, tidak ada handshake. Yang dikirim cuma tujuh byte header lalu nomor
fungsi dan alamat. Siapa pun yang bisa membuka soket TCP ke port 502 sudah
selesai urusannya.

Bentuk satu permintaan Modbus TCP, dua belas byte:

    00 01   Transaction ID, dipilih bebas oleh klien
    00 00   Protocol ID, selalu nol untuk Modbus
    00 06   panjang sisa pesan
    01      Unit ID, alamat slave
    03      kode fungsi, di sini Read Holding Registers
    00 00   alamat register awal
    00 05   berapa register dibaca

Pakai:
    python3 modbus-baca.py <host> [port] [unit]

Contoh:
    python3 /lab/files/modbus-baca.py plc
"""

import socket
import struct
import sys

# kode fungsi, nama, jenis nilai
FUNGSI = [
    (1, "coil            ", "bit"),
    (2, "discrete input  ", "bit"),
    (3, "holding register", "word"),
    (4, "input register  ", "word"),
]


def minta(host, port, unit, fc, alamat, jumlah):
    """Kirim satu permintaan Modbus TCP, kembalikan blok data jawabannya."""
    paket = struct.pack(">HHHBBHH", 1, 0, 6, unit, fc, alamat, jumlah)
    s = socket.create_connection((host, port), timeout=5)
    s.settimeout(5)
    try:
        s.sendall(paket)
        jawab = s.recv(512)
    finally:
        s.close()

    if len(jawab) < 9:
        raise RuntimeError("jawaban kependekan: %s" % jawab.hex())
    # Bit tertinggi kode fungsi menyala berarti server mengembalikan exception.
    if jawab[7] & 0x80:
        raise RuntimeError("server menolak, exception code %d" % jawab[8])
    n = jawab[8]
    return jawab[9:9 + n]


def sebagai_teks(kata):
    """Tafsirkan deret word 16 bit sebagai ASCII, dua huruf per word."""
    keluar = []
    for w in kata:
        keluar.append(chr(w >> 8))
        keluar.append(chr(w & 0xFF))
    bersih = "".join(c if 32 <= ord(c) < 127 else "." for c in keluar)
    return bersih.rstrip(". ")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    host = sys.argv[1]
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 502
    unit = int(sys.argv[3]) if len(sys.argv) > 3 else 1

    print("target %s:%d unit %d" % (host, port, unit))
    print("")

    for fc, nama, jenis in FUNGSI:
        try:
            data = minta(host, port, unit, fc, 0, 16)
        except Exception as e:                      # noqa: BLE001
            print("FC%-2d %s  GAGAL: %s" % (fc, nama, e))
            continue

        if jenis == "bit":
            bit = []
            for i in range(16):
                bit.append((data[i // 8] >> (i % 8)) & 1)
            print("FC%-2d %s alamat 0-15 : %s" % (fc, nama, " ".join(str(b) for b in bit)))
        else:
            kata = struct.unpack(">%dH" % (len(data) // 2), data)
            print("FC%-2d %s alamat 0-15 : %s" % (fc, nama, " ".join(str(w) for w in kata)))

    # Blok teks yang disebut di runbook. Dibaca terpisah karena letaknya jauh
    # dari alamat nol.
    print("")
    for awal, jumlah, label in ((10, 8, "tag perangkat"), (30, 7, "catatan integrator")):
        try:
            data = minta(host, port, unit, 3, awal, jumlah)
            kata = struct.unpack(">%dH" % (len(data) // 2), data)
            print("holding %2d-%-2d %-19s : %r" % (awal, awal + jumlah - 1, label, sebagai_teks(kata)))
        except Exception as e:                      # noqa: BLE001
            print("holding %2d %s GAGAL: %s" % (awal, label, e))

    return 0


if __name__ == "__main__":
    sys.exit(main())
