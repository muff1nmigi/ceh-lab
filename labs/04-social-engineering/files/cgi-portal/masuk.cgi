#!/usr/bin/perl
# ---------------------------------------------------------------------------
# Sisi portal SAH (container "portal"). Ini bukan pemanen.
#
# Dua hal yang sengaja dibuat begini:
#   1. Tidak ada satu pun kredensial yang diterima. Berapa kali pun dicoba,
#      jawabannya selalu "nama pengguna atau kata sandi salah". Lab ini soal
#      social engineering, bukan soal menebak kata sandi.
#   2. Kata sandi TIDAK PERNAH ditulis ke log. Yang masuk log server cuma nama
#      penggunanya. Itu praktik yang benar di aplikasi sungguhan, dan di lab
#      ini juga jadi bukti: peserta bisa melihat percobaan masuk nyasar ke
#      portal asli lewat "./lab logs 04", tanpa kata sandinya ikut terpampang.
# ---------------------------------------------------------------------------
use strict;
use warnings;

sub urldecode {
    my ($s) = @_;
    return '' unless defined $s;
    $s =~ tr/+/ /;
    $s =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge;
    return $s;
}

sub html_aman {
    my ($s) = @_;
    return '' unless defined $s;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g;
    return $s;
}

my $body = '';
if (($ENV{REQUEST_METHOD} || 'GET') eq 'POST') {
    my $len = $ENV{CONTENT_LENGTH} || 0;
    $len = 65536 if $len > 65536;
    read(STDIN, $body, $len) if $len > 0;
}

my $pengguna = '';
for my $pasangan (split /&/, $body) {
    my ($k, $v) = split /=/, $pasangan, 2;
    next unless defined $k;
    $pengguna = urldecode($v) if urldecode($k) eq 'pengguna';
}

my $catat = $pengguna;
$catat =~ s/[\x00-\x1f\x7f]/./g;
$catat = '(kosong)' unless length $catat;
# Ke error log Apache, jadi kelihatan di "./lab logs 04". Kata sandi sengaja
# tidak ikut.
print STDERR "PORTAL-SAH: percobaan masuk gagal untuk pengguna '$catat'\n";

my $tampil = html_aman($pengguna);
$tampil = '(kosong)' unless length $tampil;

print "Content-Type: text/html; charset=utf-8\r\n";
print "Cache-Control: no-store\r\n";
print "\r\n";
print <<"HALAMAN";
<!doctype html><html lang="id"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Tirtabyte Connect - Gagal masuk</title></head>
<body style="font-family:-apple-system,'Segoe UI',Roboto,Arial,sans-serif;background:#eef2f6;margin:0;display:flex;min-height:100vh;align-items:center;justify-content:center">
<div style="background:#fff;border:1px solid #d7dee7;border-radius:10px;padding:28px;width:400px;max-width:92vw">
<h1 style="font-size:19px;margin:0 0 10px">Nama pengguna atau kata sandi salah</h1>
<p style="font-size:14px;color:#42505f;line-height:1.6">Percobaan untuk
<b>$tampil</b> ditolak.</p>
<p style="font-size:14px"><a href="/">Coba lagi</a></p>
<hr style="border:0;border-top:1px solid #e6ebf1;margin:20px 0">
<p style="font-size:12px;color:#8794a3;line-height:1.6">
Halaman ini dilayani oleh <b>portal Tirtabyte yang sah, port 8400</b>.
Kalau Anda sampai di sini setelah menekan tombol di halaman umpan port 8401,
berarti formulir umpan itu masih mengirim datanya ke portal asli, bukan ke
penyerang. Itu bukan kerusakan, itu memang isi Langkah 5. Cara membetulkannya
ada di Langkah 6 README lab.
</p>
</div></body></html>
HALAMAN
