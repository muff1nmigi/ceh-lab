"""Pagar target untuk lab 07.

Semua skrip serangan di folder ini memanggil pastikan_target_lab() sebelum
mengirim satu paket pun. Fungsinya menolak target yang tidak berada di subnet
lab, jadi salah ketik alamat berhenti sebagai pesan error, bukan sebagai
serangan ke jaringan orang lain.

Pagar ini lapisan kedua. Lapisan pertama ada di Docker: network lab dibuat
internal, jadi dari dalam toolbox memang tidak ada rute ke mana pun kecuali
ke container lab. Dua lapisan dipakai karena lapisan pertama tidak memberi
pesan yang bisa dibaca peserta, dan pesan yang bisa dibaca itu bagian dari
pelajarannya.
"""

import ipaddress
import socket
import sys


def jaringan_lokal():
    """Daftar subnet yang terhubung langsung ke container ini.

    Dibaca dari /proc/net/route supaya tidak bergantung pada perkakas luar.
    Rute default (tujuan 0.0.0.0) sengaja dilewati: di lab yang benar rute itu
    tidak ada, dan kalaupun ada, ia bukan subnet yang terhubung langsung.
    """
    hasil = []
    with open("/proc/net/route", encoding="ascii") as f:
        f.readline()
        for baris in f:
            kolom = baris.split()
            if len(kolom) < 8:
                continue
            tujuan = int.from_bytes(bytes.fromhex(kolom[1]), "little")
            topeng = int.from_bytes(bytes.fromhex(kolom[7]), "little")
            if tujuan == 0 or topeng == 0:
                continue
            hasil.append(
                ipaddress.IPv4Network(
                    (tujuan, str(ipaddress.IPv4Address(topeng))), strict=False
                )
            )
    return hasil


def alamat_sendiri(ip_tujuan):
    """IP container ini di antarmuka yang dipakai untuk menjangkau ip_tujuan."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect((ip_tujuan, 9))
        return s.getsockname()[0]
    finally:
        s.close()


def pastikan_target_lab(nama):
    """Kembalikan (ip, subnet) kalau target sah. Kalau tidak, berhenti."""
    try:
        ip = socket.gethostbyname(nama)
    except OSError:
        sys.exit(
            "PAGAR: nama '%s' tidak bisa diresolusi dari dalam lab.\n"
            "       Target yang sah cuma 'web' dan 'web-aman'." % nama
        )

    alamat = ipaddress.IPv4Address(ip)
    if alamat.is_loopback:
        sys.exit(
            "PAGAR: '%s' menunjuk ke localhost container ini sendiri.\n"
            "       Dari dalam toolbox, targetnya dipanggil 'web', bukan"
            " 'localhost'." % nama
        )

    for subnet in jaringan_lokal():
        if alamat in subnet:
            return ip, subnet

    sys.exit(
        "PAGAR: %s (%s) ADA DI LUAR JARINGAN LAB. Tidak satu paket pun"
        " dikirim.\n"
        "       Subnet lab yang terdeteksi: %s\n"
        "       Kalau Anda sedang mencoba mengarahkan lab ini ke alamat di"
        " luar itu,\n"
        "       berhenti sekarang dan baca lagi bagian peringatan di README."
        % (nama, ip, ", ".join(str(s) for s in jaringan_lokal()) or "tidak ada")
    )
