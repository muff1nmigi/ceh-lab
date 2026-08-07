#!/usr/bin/perl
# ---------------------------------------------------------------------------
# Panel penyerang untuk lab CEH 04: menampilkan isi /tangkapan/kredensial.log.
# Cuma membaca berkas lokal, nol koneksi keluar.
# Isi catatan di-escape sebelum dicetak, supaya kredensial berisi tanda kurung
# sudut tidak berubah jadi HTML di panel ini sendiri.
# ---------------------------------------------------------------------------
use strict;
use warnings;

my $LOG = '/tangkapan/kredensial.log';

sub html_aman {
    my ($s) = @_;
    return '' unless defined $s;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g;
    return $s;
}

my @baris;
if (open(my $fh, '<', $LOG)) {
    while (my $b = <$fh>) {
        chomp $b;
        push @baris, $b if length $b;
    }
    close($fh);
}

print "Content-Type: text/html; charset=utf-8\r\n";
print "Cache-Control: no-store\r\n";
print "\r\n";

my $jumlah = scalar @baris;
print <<"KEPALA";
<!doctype html><html lang="id"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Panel panen - lab CEH 04</title>
<style>
body{font-family:-apple-system,'Segoe UI',Roboto,Arial,sans-serif;background:#12161b;color:#e8eaed;margin:0;padding:28px}
h1{font-size:20px;margin:0 0 4px}
p.sub{color:#9aa4b0;font-size:13px;margin:0 0 22px}
table{border-collapse:collapse;width:100%;font-size:12px}
th,td{border:1px solid #2b323b;padding:7px 9px;text-align:left;vertical-align:top}
th{background:#1b2129;color:#9aa4b0;font-weight:600}
td{font-family:ui-monospace,Menlo,Consolas,monospace;word-break:break-all}
.kosong{border:1px dashed #3a424c;padding:18px;color:#9aa4b0;font-size:13px;line-height:1.6}
.catatan{margin-top:22px;font-size:12px;color:#7d8794;line-height:1.6}
</style></head><body>
<h1>Panel panen</h1>
<p class="sub">Sisi penyerang, lab CEH 04. Jumlah tangkapan: $jumlah</p>
KEPALA

if ($jumlah == 0) {
    print <<'KOSONG';
<div class="kosong">
Belum ada satu pun tangkapan.<br><br>
Kalau Anda sudah mengirim formulir dari halaman umpan dan panel ini tetap kosong,
itu bukan kerusakan. Artinya kredensialnya terkirim ke tempat lain. Periksa
atribut <b>action</b> pada formulir di halaman umpan.
</div>
KOSONG
} else {
    print "<table><tr><th>#</th><th>Catatan mentah</th></tr>\n";
    my $n = 0;
    for my $b (@baris) {
        $n++;
        print '<tr><td>' . $n . '</td><td>' . html_aman($b) . "</td></tr>\n";
    }
    print "</table>\n";
}

print <<'EKOR';
<p class="catatan">
Catatan disimpan di /tangkapan/kredensial.log di dalam volume lab, tidak pernah
dikirim ke mana pun, dan ikut terhapus waktu lab dimatikan dengan
"./lab down 04". Merek Tirtabyte fiktif.
</p>
</body></html>
EKOR
