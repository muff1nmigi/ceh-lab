#!/usr/bin/env python3
"""Pembaca header surel untuk lab CEH 04.

Perkakas ini MENGURAI, bukan menyimpulkan. Dia mengeluarkan header yang perlu
Anda lihat, jalur Received berurutan, dan setiap tautan beserta teks yang
tampil di layar korban. Penilaian curiga atau tidak tetap tugas Anda, dan
itulah yang diuji di soal.

Padanannya di dunia nyata: Message Header Analyzer milik Microsoft dan
MXToolbox Header Analyzer. Keduanya menempel di web, jadi tidak dipakai di
lab yang sengaja nol egress ini.

Pemakaian:
    python3 /lab/files/periksa-header.py /lab/files/surat/01-verifikasi-akun.eml
"""

import email
import email.policy
import re
import sys

PENTING = [
    "Return-Path",
    "From",
    "Reply-To",
    "To",
    "Subject",
    "Date",
    "Message-ID",
    "X-Mailer",
    "X-Originating-IP",
    "X-Priority",
]


def domain(nilai):
    if not nilai:
        return ""
    cocok = re.findall(r"[\w.+-]+@([\w.-]+)", str(nilai))
    return cocok[-1].rstrip(">").lower() if cocok else ""


def cetak_judul(teks):
    print()
    print(teks)
    print("-" * len(teks))


def main():
    if len(sys.argv) != 2:
        print("Pemakaian: python3 periksa-header.py <berkas.eml>")
        return 2

    with open(sys.argv[1], "r", encoding="utf-8", errors="replace") as fh:
        pesan = email.message_from_file(fh, policy=email.policy.default)

    cetak_judul("HEADER UTAMA")
    for kunci in PENTING:
        nilai = pesan.get(kunci)
        if nilai is not None:
            print("  %-17s %s" % (kunci, " ".join(str(nilai).split())))

    cetak_judul("KESELARASAN DOMAIN")
    d_from = domain(pesan.get("From"))
    d_envelope = domain(pesan.get("Return-Path"))
    d_reply = domain(pesan.get("Reply-To"))
    d_msgid = domain(pesan.get("Message-ID")) or (
        (pesan.get("Message-ID") or "").split("@")[-1].rstrip(">").lower()
    )
    for label, nilai in (
        ("From", d_from),
        ("Return-Path", d_envelope),
        ("Reply-To", d_reply),
        ("Message-ID", d_msgid),
    ):
        print("  %-17s %s" % (label, nilai or "(tidak ada)"))
    print()
    print("  Bandingkan sendiri keempat baris di atas. Perkakas ini sengaja")
    print("  tidak memberi vonis, karena itu yang ditanya di soal.")

    cetak_judul("HASIL AUTENTIKASI APA ADANYA")
    ada = False
    for kunci in ("Authentication-Results", "Received-SPF", "DKIM-Signature"):
        for nilai in pesan.get_all(kunci) or []:
            ada = True
            print("  %s: %s" % (kunci, " ".join(str(nilai).split())))
    if not ada:
        print("  (tidak ada satu pun header autentikasi)")

    cetak_judul("JALUR RECEIVED, HOP TERTUA DI BAWAH")
    hops = pesan.get_all("Received") or []
    for nomor, hop in enumerate(hops, start=1):
        rapi = " ".join(str(hop).split())
        print("  hop %d: %s" % (nomor, rapi))
    print()
    print("  Jumlah hop: %d" % len(hops))
    print("  Baca dari BAWAH ke ATAS untuk mengikuti perjalanan pesan.")

    cetak_judul("TAUTAN: YANG TERLIHAT LAWAN YANG DITUJU")
    ketemu = False
    for bagian in pesan.walk():
        if bagian.get_content_type() != "text/html":
            continue
        isi = bagian.get_content()
        for href, teks in re.findall(
            r'<a\s[^>]*href="([^"]*)"[^>]*>(.*?)</a>', isi, re.S | re.I
        ):
            ketemu = True
            print("  terlihat : %s" % " ".join(re.sub(r"<[^>]+>", "", teks).split()))
            print("  menuju   : %s" % href)
            print()
    if not ketemu:
        print("  (tidak ada bagian HTML, atau tidak ada tautan di dalamnya)")

    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
