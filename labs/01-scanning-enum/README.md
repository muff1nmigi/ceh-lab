# Lab 01 - Network scanning dan enumeration

Modul CEH 03 - Scanning Networks dan Enumeration | 75 menit | Level 2

## Tujuan

Anda memetakan sebuah jaringan kantor kecil dari nol: menemukan host yang
hidup, membuka daftar portnya, memastikan layanan apa yang benar-benar
berjalan di balik tiap port, lalu menarik nama akun dan nama share dari server
berkas tanpa punya satu pun kredensial. Lab ini menyentuh tiga domain exam
sekaligus, yaitu Footprinting and Reconnaissance, Scanning Networks, dan
Enumeration, karena di soal ketiganya memang muncul sebagai satu rantai kerja
yang sama, bukan sebagai tiga topik terpisah.

## Waktu

75 menit. Langkah wajib 1 sampai 8 memakan sekitar 45 menit kalau Anda
mengetik sendiri, sisanya untuk pertanyaan dan tantangan tambahan.

Scanning di lab ini jauh lebih cepat daripada di dunia nyata. Scan 65535 port
ke empat target selesai dalam 2 detik di mesin uji, karena semua target ada di
memori laptop yang sama dan latensinya nol koma sekian mikrodetik.

## Peringatan dan batas

Baca bagian ini sampai habis sebelum mengetik perintah apa pun.

**Target yang sah di lab ini cuma empat nama: `web`, `smb`, `ftp`, dan `ssh`.**
Tidak ada target lain, dan itu bukan aturan sopan santun, itu batas hukum.
Memindai jaringan orang lain tanpa izin tertulis bukan latihan, itu perbuatan
yang bisa dituntut. Kelas ini berjalan di jaringan kantor yang bukan milik
kita, dan satu perintah `nmap` yang salah alamat sudah cukup untuk jadi
insiden.

Karena peringatan berbentuk paragraf selalu kalah lawan orang yang sedang
semangat, pagarnya dipasang di lapisan yang tidak bisa dilewati tanpa sengaja.
Jaringan lab ini internal, jadi dari dalam toolbox memang tidak ada jalan
keluar sama sekali. Anda bisa membuktikannya sendiri di langkah 2.

Port yang dipublish ke laptop Anda juga diikat ke `127.0.0.1`, jadi peserta
lain di ruangan yang sama tidak bisa membuka target Anda, dan Anda tidak bisa
membuka punya mereka.

## Cara nyalain

```
./lab up 01
```

Di Windows, ganti `./lab` dengan `.\lab.cmd` pada semua perintah di halaman
ini.

Buka di browser: http://localhost:8180
Terminal penyerang: `./lab sh 01`

Semua langkah di bawah dikerjakan dari dalam toolbox, kecuali kalau tertulis
lain. Kalau prompt Anda berubah jadi `root@penyerang`, Anda sudah di tempat
yang benar.

## Peta lab

| Container | Perannya | Nama dari dalam toolbox | Port |
|---|---|---|---|
| toolbox | tempat Anda mengetik | `penyerang` | - |
| web | intranet perusahaan | `web` | 80 |
| smb | server berkas kantor | `smb` | 139, 445, 137/udp |
| ftp | server arsip | `ftp` | 21 |
| ssh | server jump | `ssh` | 2222 |

Dua di antaranya juga bisa dibuka langsung dari laptop Anda:
`http://localhost:8180` untuk web, dan port `8122` untuk SSH.

`smb` dan `ftp` sengaja tidak dipublish ke laptop. Alasannya ditulis di bagian
"Yang tidak bisa dikerjakan di lab ini".

Semua image di lab ini punya versi arm64 dan amd64, jadi tidak ada satu pun
peserta yang kena emulasi. Tidak ada bedanya antara Apple Silicon dan x86 di
sini, selain kecepatan laptopnya sendiri.

## Langkah wajib

### 1. Cari tahu Anda ada di jaringan mana

Anda belum tahu subnetnya, dan itu memang titik awal yang benar. Jangan
menyalin angka dari halaman ini, angkanya berbeda di tiap laptop.

```
./lab sh 01
ip -4 -o addr show eth0
```

Yang muncul kira-kira seperti ini, dengan angka yang berbeda di laptop Anda:

```
2: eth0    inet 192.168.163.4/24 brd 192.168.163.255 scope global eth0
```

Artinya toolbox Anda ada di `192.168.163.4` dan jaringannya `/24`, jadi
subnet yang akan dipindai adalah `192.168.163.0/24`. Docker memilih subnet ini
sendiri saat lab dinyalakan, dan di laptop lain angkanya bisa `172.x.x.x`.
Catat angka Anda, semua langkah berikutnya memakainya.

### 2. Buktikan dulu pagarnya ada

Sebelum memindai apa pun, pastikan Anda memang tidak bisa keluar.

```
ping -c 1 -W 2 8.8.8.8
ping -c 1 -W 2 192.168.18.1
```

Yang dicari: dua-duanya GAGAL dengan pesan `Network is unreachable`.

Kegagalan itu hasil yang diinginkan, bukan kerusakan. Kalau salah satu justru
berhasil, berhenti dan panggil instruktur, karena berarti pagar labnya bocor.

### 3. Host discovery, siapa saja yang hidup

Ganti subnetnya dengan punya Anda dari langkah 1.

```
nmap -sn 192.168.163.0/24
```

Yang mestinya kelihatan, kira-kira:

```
Nmap scan report for ceh-01-ftp-1.ceh-01_default (192.168.163.2)
Host is up (0.0000070s latency).
MAC Address: C2:75:4B:E6:BE:59 (Unknown)
Nmap scan report for ceh-01-web-1.ceh-01_default (192.168.163.3)
...
Nmap done: 256 IP addresses (7 hosts up) scanned in 2.47 seconds
```

`-sn` artinya ping scan, yaitu host discovery tanpa port scan. Di soal, ini
sering disebut ping sweep. Perhatikan bahwa jumlah host yang hidup lebih
banyak daripada jumlah target. Hitung sendiri dan cari tahu kenapa, itu salah
satu pertanyaan di bawah.

Perhatikan juga bahwa nmap ikut memberi nama host. Itu hasil reverse DNS, dan
di jaringan sungguhan nama host sering membocorkan peran mesinnya jauh sebelum
Anda memindai satu port pun.

### 4. Port scan, dan kenapa `--top-ports` bisa menipu

Mulai dari yang cepat dulu:

```
nmap -sS -T4 --top-ports 200 --open web smb ftp ssh
```

Yang mestinya kelihatan: `web` punya 80, `smb` punya 139 dan 445, `ftp` punya
21. Dan `ssh` tidak muncul sama sekali.

Itu bukan bug. `--top-ports 200` cuma memindai 200 port yang paling sering
dipakai, dan port 2222 tidak termasuk. Sekarang ulangi dengan seluruh port:

```
nmap -sS -p- -T4 --open web smb ftp ssh
```

Sekarang `ssh` muncul:

```
Nmap scan report for ssh (192.168.163.6)
PORT     STATE SERVICE
2222/tcp open  EtherNetIP-1
```

Dua hal yang harus Anda bawa ke exam dari sini. Pertama, `-p-` berarti 65535
port, dan tanpa itu layanan yang dipindah ke port tidak lazim akan lolos.
Kedua, `-sS` adalah SYN scan, yang di soal disebut half-open scan atau stealth
scan: nmap mengirim SYN, menerima SYN-ACK, lalu membalas RST sehingga
handshake tidak pernah selesai dan sambungannya tidak tercatat sebagai sesi di
banyak aplikasi.

### 5. Deteksi versi, dan kenapa kolom SERVICE tidak bisa dipercaya

Lihat lagi baris `ssh` di langkah 4. Nmap menyebutnya `EtherNetIP-1`. Itu
tebakan berdasarkan nomor port saja, dibaca dari berkas `nmap-services`.
Sekarang minta nmap benar-benar bertanya ke layanannya:

```
nmap -sV -p 21,80,139,445,2222 web smb ftp ssh
```

Yang mestinya kelihatan:

```
80/tcp   open   http         Apache httpd 2.4.68 ((Unix))
139/tcp  open   netbios-ssn  Samba smbd 3.X - 4.X (workgroup: NUSANTARA)
445/tcp  open   netbios-ssn  Samba smbd 3.X - 4.X (workgroup: NUSANTARA)
21/tcp   open   ftp          vsftpd 2.0.8 or later
2222/tcp open   ssh          OpenSSH 10.3 (protocol 2.0)
```

`EtherNetIP-1` ternyata OpenSSH 10.3. Inilah bedanya kolom SERVICE hasil
tebakan dengan kolom VERSION hasil pemeriksaan. Di laporan pentest, yang boleh
Anda tulis cuma yang kedua.

Perhatikan juga baris FTP, dan lanjutkan ke langkah berikutnya sebelum menarik
kesimpulan tentangnya.

### 6. Banner grabbing manual

Nmap bagus, tapi Anda harus bisa melakukannya tanpa nmap juga, karena itu
keluar di soal.

```
nc ftp 21
```

Yang mestinya kelihatan:

```
220 Server arsip PT Nusantara Digital. Semua aktivitas dicatat.
```

Tekan `Ctrl+C` untuk keluar. Perhatikan bahwa banner ini tidak menyebut nama
produk maupun versinya, padahal `-sV` di langkah 5 dengan yakin menjawab
vsftpd. Itu karena `-sV` tidak cuma membaca teks sambutan, dia mengirim
serangkaian probe dan mencocokkan pola balasannya. Menyamarkan banner memang
menyusahkan penyerang yang malas, tapi tidak menyembunyikan produknya.

Dua banner lagi, dengan cara yang berbeda:

```
nc ssh 2222
printf 'HEAD / HTTP/1.0\r\n\r\n' | nc web 80
```

Yang mestinya kelihatan: `SSH-2.0-OpenSSH_10.3`, lalu blok header HTTP yang
memuat `Server: Apache/2.4.68 (Unix)`.

### 7. Footprinting lewat web, sebelum menyentuh server berkas

Bagian ini yang sering dilewati orang, padahal ini yang membuat langkah
enumerasi berikutnya jauh lebih tajam.

```
curl -s http://web/ | head -40
curl -s http://web/robots.txt
```

Yang mestinya kelihatan: sebuah tabel berisi nama pegawai lengkap dengan email
dan nomor ekstensi, sebuah komentar HTML dari tim TI yang tidak dimaksudkan
untuk dibaca orang luar, dan sebuah `robots.txt` yang justru menunjuk dua
folder yang tidak ditautkan dari mana pun:

```
User-agent: *
Disallow: /arsip-lama/
Disallow: /panel-internal/
```

`robots.txt` adalah permintaan sopan kepada mesin pencari, bukan kontrol
akses. Isinya justru daftar tempat yang menurut pemiliknya tidak ingin
ditemukan, dan itu membuatnya jadi tempat pertama yang dilihat penyerang.
Buka dua folder itu:

```
curl -s http://web/arsip-lama/
curl -s http://web/panel-internal/
```

Sekarang temukan sendiri folder tersembunyi tanpa bantuan `robots.txt`,
dengan cara menebak nama satu per satu:

```
gobuster dir -u http://web/ -w /lab/wordlists/direktori.txt -t 10
```

Yang mestinya kelihatan:

```
arsip-lama           (Status: 301) [Size: 270] [--> http://web/arsip-lama/]
panel-internal       (Status: 301) [Size: 274] [--> http://web/panel-internal/]
```

Wordlist yang dipakai ada di dalam repo lab ini, di
`labs/01-scanning-enum/wordlists/direktori.txt`, dan dari dalam toolbox
alamatnya `/lab/wordlists/direktori.txt`. Silakan dibuka, isinya cuma 50 nama
folder yang lazim.

Dari langkah ini Anda sekarang punya daftar nama akun tebakan: `budi`, `siti`,
`agus`, dan `itadmin`. Simpan, itu bahan langkah 9.

### 8. Enumerasi SMB dengan skrip NSE

NSE adalah Nmap Scripting Engine, dan di exam Anda perlu tahu bahwa
skripnya dipanggil dengan `--script`.

```
nmap -p139,445 --script smb-protocols,smb-os-discovery,smb-security-mode,smb-enum-shares,smb-enum-users smb
```

Yang mestinya kelihatan, dipendekkan:

```
| smb-os-discovery:
|   OS: Windows 6.1 (Samba 4.23.8)
|   Computer name: fs-kantor
|   NetBIOS computer name: FS-KANTOR
| smb-protocols:
|   dialects:
|     NT LM 0.12 (SMBv1) [dangerous, but default]
|     2.0.2
|     ...
|     3.1.1
| smb-security-mode:
|   account_used: guest
|_  message_signing: disabled (dangerous, but default)
| smb-enum-users:
|   FS-KANTOR\agus (RID: 7006)
|   FS-KANTOR\budi (RID: 7002)
|   FS-KANTOR\itadmin (RID: 7008)
|_  FS-KANTOR\siti (RID: 7004)
```

Tiga temuan sekaligus, dan ketiganya sering jadi butir soal: SMBv1 masih
dilayani, message signing mati, dan daftar akun bisa ditarik oleh sesi tamu.

Coba juga UDP, karena banyak orang lupa NetBIOS name service hidup di sana:

```
nmap -sU -p137 --script nbstat smb
```

Yang mestinya kelihatan: nama `FS-KANTOR` dan workgroup `NUSANTARA`, lengkap
dengan kode suffix seperti `<00>` dan `<20>`.

### 9. SMB null session, tanpa satu pun kredensial

Null session artinya sesi SMB dengan username kosong dan password kosong.
Di server yang belum dikeraskan, sesi itu tetap boleh bertanya banyak hal.

```
smbclient -L //smb -N
```

Yang mestinya kelihatan:

```
	Sharename       Type      Comment
	---------       ----      -------
	keuangan        Disk      Rekap keuangan, terbatas
	publik          Disk      Dokumen umum, boleh dibaca semua orang
	IPC$            IPC       IPC Service (File Server Kantor Pusat)
```

`-N` artinya jangan minta password. Sekarang coba masuk ke dua share itu:

```
smbclient //smb/publik -N -c "ls; get baca-saya.txt /tmp/baca.txt"
cat /tmp/baca.txt
smbclient //smb/keuangan -N -c "ls"
```

Yang mestinya kelihatan: share `publik` terbuka dan berkasnya terbaca,
sedangkan `keuangan` ditolak dengan `NT_STATUS_ACCESS_DENIED`. Perbedaan
jawaban itu sendiri adalah informasi: penyerang jadi tahu share mana yang
layak dikejar.

Lanjut ke RPC, yang jauh lebih banyak bicara:

```
rpcclient -U "" -N smb -c "srvinfo"
rpcclient -U "" -N smb -c "enumdomusers"
rpcclient -U "" -N smb -c "querydominfo"
```

Yang mestinya kelihatan:

```
user:[budi] rid:[0x1b5a]
user:[itadmin] rid:[0x1b60]
user:[agus] rid:[0x1b5e]
user:[siti] rid:[0x1b5c]
```

Empat nama tebakan Anda dari langkah 7 sekarang terkonfirmasi, dan Anda dapat
bonus berupa RID masing-masing.

### 10. RID cycling

RID adalah bagian terakhir dari SID sebuah akun. Kalau Anda tahu SID domainnya
dan bisa bertanya per RID, Anda bisa memetakan akun satu per satu, termasuk
akun yang tidak muncul di `enumdomusers`.

Ambil dulu SID domainnya lewat satu nama yang sudah Anda ketahui:

```
rpcclient -U "" -N smb -c "lookupnames budi"
```

Yang mestinya kelihatan, dengan angka yang berbeda di laptop Anda karena SID
dibuat sekali saat container pertama kali jalan:

```
budi S-1-5-21-119024976-1664744103-3938118322-7002 (User: 1)
```

Buang bagian `-7002` di ujung, sisanya adalah SID domain. Sekarang tanyakan
beberapa RID sekaligus, ganti SID di bawah dengan punya Anda:

```
for r in 500 501 7002 7004 7006 7008; do
  rpcclient -U "" -N smb -c "lookupsids S-1-5-21-119024976-1664744103-3938118322-$r"
done
```

Yang mestinya kelihatan:

```
...-500 *unknown*\*unknown* (8)
...-501 FS-KANTOR\nobody (1)
...-7002 FS-KANTOR\budi (1)
...-7004 FS-KANTOR\siti (1)
...-7006 FS-KANTOR\agus (1)
...-7008 FS-KANTOR\itadmin (1)
```

Perhatikan pola RID-nya: 7002, 7004, 7006, 7008. Berjarak dua, dan tidak
dimulai dari 1000. Cari tahu dari mana angka itu, itu salah satu pertanyaan.

### 11. Enumerasi otomatis, dan kenapa tetap dikerjakan terakhir

Sekarang jalankan perkakas yang mengerjakan langkah 8 sampai 10 sekaligus.
Sengaja terakhir, supaya Anda sudah tahu apa yang sebenarnya dia lakukan.

```
enum4linux -U -S smb
enum4linux-ng -A smb
```

Yang mestinya kelihatan dari `enum4linux-ng`, selain semua yang tadi, adalah
kebijakan password yang tidak Anda dapat dari langkah manual:

```
Domain password information:
  Minimum password length: 5
  Password properties:
  - DOMAIN_PASSWORD_COMPLEX: false
Domain lockout information:
  Lockout threshold: None
```

`Lockout threshold: None` artinya akun tidak pernah terkunci berapa kali pun
salah password. Di laporan, itu temuan yang lebih berat daripada daftar
akunnya sendiri, karena itu yang membuat password spraying jadi murah.

### 12. FTP dan akses tamu

```
nmap -p21 -sV --script ftp-anon,banner ftp
```

Yang mestinya kelihatan:

```
21/tcp open  ftp     vsftpd 2.0.8 or later
|_banner: 220 Server arsip PT Nusantara Digital. Semua aktivitas dicatat.
| ftp-anon: Anonymous FTP login allowed (FTP code 230)
|_-rw-rw-r--    1 1000     1000          198 Aug 09 00:27 baca-saya.txt
```

Ambil berkasnya:

```
curl -s --list-only ftp://anonymous:x@ftp/
curl -s ftp://anonymous:x@ftp/baca-saya.txt
```

### 13. Bukti dari luar container

Dua langkah terakhir dikerjakan di terminal laptop Anda, bukan di dalam
toolbox. Keluar dulu dengan `exit`.

```
curl -sI http://localhost:8180/
```

Yang mestinya kelihatan: `HTTP/1.1 200 OK` dan `Server: Apache/2.4.68 (Unix)`.

Lalu banner SSH, tanpa perkakas tambahan:

```
nc 127.0.0.1 8122
```

Yang mestinya kelihatan: `SSH-2.0-OpenSSH_10.3`. Tekan `Ctrl+C` untuk keluar.
Di Windows PowerShell, `nc` tidak ada, pakai ini sebagai gantinya:

```
Test-NetConnection -ComputerName 127.0.0.1 -Port 8122
```

Perhatikan bahwa dari laptop, alamatnya `localhost` dengan port `8180` dan
`8122`, sedangkan dari dalam toolbox alamatnya `web` port `80` dan `ssh` port
`2222`. Itu dua sudut pandang yang berbeda ke mesin yang sama, dan bingung
antara keduanya adalah penyebab nomor satu lab yang "tidak jalan".

## Pertanyaan

Jawabannya cuma ketemu kalau Anda benar-benar menjalankan langkahnya. Tulis
jawaban Anda di catatan sendiri.

1. Di langkah 3, berapa host yang dilaporkan hidup? Jumlahnya lebih banyak
   daripada empat target. Sebutkan siapa saja kelebihannya dan kenapa mereka
   ikut terhitung.
2. Port 2222 disebut apa di kolom SERVICE hasil `-sS`, dan apa jawabannya
   setelah `-sV`? Dari mana nmap mendapat tebakan yang pertama?
3. Banner FTP tidak menyebut nama produk sama sekali. Apa yang tetap
   dilaporkan `-sV`, dan jelaskan dengan kalimat Anda sendiri kenapa dia masih
   bisa tahu.
4. Menurut `smb-os-discovery`, versi Samba berapa yang berjalan? Dan menurut
   `smb-protocols`, dialek paling tua yang masih dilayani apa namanya?
5. Sebutkan RID untuk `budi` dan untuk `itadmin`. Jaraknya berapa antar akun,
   dan kenapa tidak berjarak satu? Petunjuk: cari hubungan antara RID dan UID
   Unix, rumusnya melibatkan perkalian dua.
6. Tulis SID domain lengkap dari server SMB di laptop Anda. Bandingkan dengan
   punya teman sebelah. Sama atau berbeda, dan kenapa begitu?
7. Ada empat kode temuan yang disembunyikan di lab ini, masing-masing
   berformat `HURUF-HURUF-ANGKA`. Satu di share SMB yang terbuka untuk tamu,
   satu di folder tamu FTP, dan dua di folder web yang tidak ditautkan dari
   halaman mana pun. Temukan keempatnya dan tulis dari mana Anda dapat.
8. Share mana yang menolak sesi anonim, dan pesan galat persisnya apa?
9. Berapa `Lockout threshold` di kebijakan password server SMB, dan kenapa
   nilai itu penting untuk penyerang?
10. `http-methods` melaporkan satu metode yang ditandai berisiko. Metode apa,
    dan kenapa dia dianggap berisiko?

## Tantangan tambahan

Untuk yang sudah selesai duluan. Tidak wajib, dan tidak ada yang diperiksa.

1. **Lihat sendiri bedanya `-sS` dan `-sT` di kabel.** Buka dua terminal ke
   toolbox (`./lab sh 01` dua kali). Di terminal pertama jalankan
   `tcpdump -n -i eth0 host web and port 80`. Di terminal kedua jalankan
   `nmap -sS -p80 web`, lalu `nmap -sT -p80 web`. Hitung paketnya. SYN scan
   berhenti di tiga paket dengan RST di akhir, TCP connect scan menyelesaikan
   handshake dulu. Itu alasan yang pertama disebut half-open.
2. **Kredensial dipakai ulang di mana saja.** Password akun `budi` di SSH ada
   di berkas `meta.env` lab ini. Coba pakai password yang sama untuk membuka
   share `keuangan`: `smbclient //smb/keuangan -U budi%<password>`. Kalau
   berhasil, Anda baru saja memperagakan kenapa credential reuse adalah temuan
   tersendiri, bukan sekadar catatan kaki.
3. **Susun daftar akun dari nol.** Ambil nama pegawai dari halaman web di
   langkah 7, buat berkas teks berisi tebakan nama akun, lalu periksa satu per
   satu dengan `rpcclient -U "" -N smb -c "lookupnames <nama>"`. Nama yang ada
   akan menjawab dengan SID, yang tidak ada akan menjawab
   `NT_STATUS_NONE_MAPPED`. Itu user enumeration lewat perbedaan jawaban.
4. **Simpan hasil dengan benar.** Ulangi scan langkah 4 dengan
   `nmap -sS -p- -T4 --open -oA /lab/hasil-scan web smb ftp ssh`. Anda dapat
   tiga berkas sekaligus: `.nmap`, `.gnmap`, dan `.xml`. Tarik daftar port
   terbuka dari yang greppable dengan `grep -o '[0-9]*/open' /lab/hasil-scan.gnmap`.
   Berkasnya muncul di folder lab di laptop Anda, karena folder itu memang
   di-mount ke `/lab`. Hapus lagi kalau sudah selesai.
5. **Bandingkan template timing, dengan rentang port yang kecil.**

   ```
   time nmap -sS -T4 -p78-82 web
   time nmap -sS -T1 -p78-82 web
   ```

   Diukur pada 2026-08-06: `-T4` selesai dalam 1 detik, `-T1` butuh 90 detik,
   untuk lima port yang sama. `-T1` bernama paranoid dan memang menyisipkan
   jeda 5 detik antar probe supaya tidak memicu alarm IDS.

   Perhatikan rentang portnya sengaja cuma lima. **Jangan menjalankan `-T1`
   bersama `-p-`**, karena 65535 port dikali jeda 5 detik berarti berhari-hari,
   dan sesi Anda akan menggantung sampai kelas selesai.

   Setelah itu jawab sendiri: di jaringan dengan latensi nol seperti ini,
   apakah perbedaan `-T` mengajarkan sesuatu yang berlaku di dunia nyata? Ini
   pertanyaan jebakan, dan jawabannya ada di bagian berikutnya.
6. **Pemindai web.** `nikto -h http://web/ -ask no`. Bandingkan temuannya
   dengan hasil `--script http-headers` Anda tadi. Perhatikan bahwa nikto ikut
   menyebut `robots.txt` sebagai hal yang perlu dilihat manual, sama seperti
   kesimpulan Anda di langkah 7.

## Yang tidak bisa dikerjakan di lab ini

Bagian ini sama pentingnya dengan langkah-langkah di atas. Lab yang tidak
menyebut batasnya sendiri mengajarkan kepercayaan diri yang salah.

**OS fingerprinting dengan `nmap -O` sengaja tidak dipakai, dan jangan
percaya hasilnya kalau Anda coba sendiri.** Semua container berbagi kernel
dengan laptop Anda, jadi sidik jari tumpukan TCP/IP yang dibaca nmap bukan
milik target, melainkan milik mesin yang menjalankan lab. Diuji pada
2026-08-06, `nmap -O` terhadap container Apache menjawab dengan tebakan
`Android 11`, `MikroTik RouterOS`, dan `OpenWrt`, semuanya dengan keyakinan di
atas 90 persen, dan semuanya salah. Keempat target di lab ini juga akan
memberi jawaban yang mirip satu sama lain, karena memang sumbernya satu.
Di dunia nyata, empat mesin berbeda memberi sidik jari berbeda, dan `-O` jadi
petunjuk yang berguna. Nama flagnya tetap perlu Anda hafal untuk exam, cuma
hasilnya yang tidak boleh dipercaya di sini.

**Latensi nol membuat pelajaran timing jadi palsu.** Semua target ada di
memori laptop yang sama, jadi scan 65535 port selesai dalam hitungan detik dan
`-T1` sampai `-T5` nyaris tidak terasa bedanya. Di jaringan sungguhan, `-T4`
ke sebuah `/24` lewat WAN bisa memakan puluhan menit, dan `-T5` cukup sering
melewatkan port karena timeout-nya terlalu ketat. Angka waktu dari lab ini
jangan dipakai untuk memperkirakan pekerjaan nyata.

**Tidak ada firewall dan tidak ada IDS, jadi teknik evasion tidak ada
lawannya.** Flag seperti `-f` untuk fragmentasi, `-D` untuk decoy, `--source-port`,
dan `--data-length` tetap bisa dijalankan dan tetap akan berhasil, tapi
keberhasilannya tidak membuktikan apa pun karena tidak ada yang menyaring.
Nama dan gunanya tetap keluar di exam, jadi hafalkan konsepnya, jangan
menyimpulkan efektivitasnya dari lab ini.

**Alamat MAC dan vendor lookup tidak berarti apa-apa di sini.** Perhatikan
bahwa nmap menulis `(Unknown)` di sebelah setiap MAC. Alamat itu dibuat acak
oleh Docker, bukan milik kartu jaringan sungguhan, jadi teknik menebak jenis
perangkat dari OUI vendor tidak jalan.

**Targetnya Samba di Linux, bukan Windows.** Yang Anda enumerasi memang server
SMB sungguhan dan semua yang Anda pelajari di langkah 8 sampai 11 berlaku
untuk Windows juga. Tapi lab ini bukan Active Directory, jadi tidak ada
Kerberos, tidak ada AS-REP roasting, tidak ada Kerberoasting, dan tidak ada
DCSync. Kerentanan khas Windows seperti MS17-010 juga tidak ada di sini, jadi
`--script smb-vuln-ms17-010` akan menjawab kosong, dan kosongnya bukan berarti
target aman.

**Beberapa protokol enumerasi yang keluar di exam tidak punya target di lab
ini**, yaitu SNMP, NFS, SMTP, dan NTP. SNMP khususnya sengaja tidak ada, karena
image SNMP yang lazim dipakai cuma tersedia untuk amd64, dan menaruhnya di
jalur wajib berarti separuh kelas menjalankannya lewat emulasi. Untuk exam,
hafalkan tetap: SNMP di UDP 161, community string bawaan `public` dan
`private`, perkakasnya `snmp-check` dan `snmpwalk`.

**`smb` dan `ftp` sengaja tidak bisa dibuka dari laptop Anda.** Untuk FTP,
mode passive memakai port data 21000 sampai 21010, dan mem-publish port 21
saja membuat sambungan dari laptop tersambung lalu menggantung saat `LIST`,
yang jauh lebih membingungkan daripada tidak ada portnya sama sekali. Untuk
SMB, port 445 di macOS sering sudah dipakai layanan berbagi berkas bawaan
sistem. Dua-duanya tetap dikerjakan penuh dari dalam toolbox, dan itu memang
tempat Anda seharusnya mengetik.

**Jaringan kelas dan internet tidak bisa dijangkau, dan itu permanen.**
Bukan sekadar disarankan, tapi dipagari di lapisan jaringan Docker. Kalau lab
lain nanti butuh internet, lab itu punya berkas dan alasannya sendiri.

## Cara matiin dan beberes

```
./lab down 01
```

Kalau Anda mengerjakan tantangan nomor 4, hapus juga berkas hasil scan yang
tercecer di folder lab:

```
rm -f labs/01-scanning-enum/hasil-scan.*
```

Kalau lab terasa aneh dan Anda ingin mulai dari container yang benar-benar
baru, termasuk SID domain SMB yang baru:

```
./lab reset 01
```

## Nyambung ke exam

Yang paling sering muncul dari lab ini, dalam bentuk yang biasa ditanyakan:

| Konsep | Yang perlu diingat |
|---|---|
| SYN scan | `nmap -sS`, disebut juga half-open atau stealth scan, tidak menyelesaikan handshake |
| TCP connect scan | `nmap -sT`, handshake penuh, lebih mudah tercatat, dipakai kalau tidak punya hak raw socket |
| Ping sweep | `nmap -sn`, host discovery tanpa port scan |
| Seluruh port | `nmap -p-`, 65535 port, bukan cuma 1000 yang bawaan |
| Deteksi versi | `nmap -sV`, membaca perilaku layanan, bukan cuma banner |
| NSE | `nmap --script <nama>`, mesin skrip bawaan nmap |
| Null session | sesi SMB dengan user dan password kosong, `smbclient -N`, `rpcclient -U "" -N` |
| RID | bagian terakhir SID, akun bawaan Administrator selalu 500 dan Guest 501 |
| RID cycling | menebak akun dengan menanyakan SID per RID berurutan |
| SMBv1 | dialek `NT LM 0.12`, temuan yang selalu dilaporkan |
| Port SMB | 445 untuk SMB langsung, 139 lewat NetBIOS session service, 137 UDP untuk name service |
| Port FTP | 21 kontrol, 20 data pada mode active |
| Banner grabbing | `nc`, `telnet`, atau `--script banner`, dan hasilnya bisa dipalsukan |
| robots.txt | bukan kontrol akses, justru daftar tempat menarik |
