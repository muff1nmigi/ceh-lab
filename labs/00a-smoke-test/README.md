# Lab 00a - Smoke test dan orientasi

Modul CEH 00 - Persiapan | 15 menit | Level 1

## Tujuan

Membuktikan bahwa toolchain di laptop Anda benar-benar jalan, sebelum kelas
dimulai dan sebelum ada materi yang bergantung padanya. Sekaligus mengenalkan
pola perintah yang dipakai berulang lima hari ke depan, dan menanamkan batas
legalnya sejak hari pertama.

Nyambungnya ke exam: Modul 01 Introduction to Ethical Hacking, khususnya bagian
scope, rules of engagement, dan cyber law. Satu langkah menyerempet Modul 03
Scanning Networks lewat SYN scan.

## Waktu

15 menit, sudah termasuk membaca. Langkah 1 sampai 7 semuanya cepat: perintah
paling lama di lab ini selesai dalam 7 detik.

Yang lama bukan lab ini, tapi persiapan sebelumnya. `./lab build` memakan 5
sampai 10 menit dan cukup sekali seumur repo. Kerjakan di rumah, jangan di
kelas.

## Peringatan dan batas, baca ini dulu

**Yang boleh Anda pindai di lab ini cuma dua container: `web` dan `arsip`.**
Bukan alamat IP laptop teman sebelah, bukan gateway ruangan, bukan situs mana
pun di internet.

Kelas ini berjalan di jaringan kantor yang bukan milik kita. Memindai jaringan
milik orang lain tanpa izin tertulis bukan latihan, itu perbuatan yang diatur
pidana.

Dasar hukumnya baru saja berpindah, dan ini perlu Anda ketahui karena banyak
materi di internet masih memakai rujukan lama. Sejak **2 Januari 2026** KUHP
Nasional, yaitu Undang-Undang Nomor 1 Tahun 2023, berlaku. Lewat Pasal 622 ayat
(1) huruf r, KUHP itu mencabut sepuluh ketentuan UU ITE, termasuk Pasal 30
tentang akses ilegal beserta ancamannya di Pasal 46. Materinya pindah ke
**Pasal 332 KUHP**.

| Perbuatan | Ancaman di Pasal 332 KUHP |
|---|---|
| Sengaja dan tanpa hak mengakses komputer atau sistem elektronik milik orang lain dengan cara apa pun | Penjara paling lama 6 tahun atau denda paling banyak kategori V |
| Mengakses dengan tujuan memperoleh informasi elektronik atau dokumen elektronik | Penjara paling lama 7 tahun atau denda paling banyak kategori V |
| Mengakses dengan melanggar, menerobos, melampaui, atau menjebol sistem pengamanan | Penjara paling lama 8 tahun atau denda paling banyak kategori VI |

Denda kategori V setara Rp500.000.000 dan kategori VI setara Rp2.000.000.000.

Dua catatan yang gampang bikin salah sebut. Pertama, **KUHP lama juga punya
Pasal 332** dengan isi yang sama sekali berbeda, jadi sebutkan selalu "Pasal 332
KUHP baru" atau "Pasal 332 UU 1 Tahun 2023". Kedua, tidak semua pasal siber UU
ITE ikut dicabut. **Pasal 33 tentang gangguan terhadap sistem elektronik masih
berlaku**, beserta ancamannya di Pasal 49, dan itu yang relevan untuk materi
Denial of Service hari Kamis.

Perhatikan ayat pertama. Yang dilarang di situ cuma "mengakses". Tidak ada
syarat harus ada kerusakan, tidak ada syarat harus ada data yang dicuri, dan
tidak ada syarat harus ada niat jahat. Port scan yang berhasil sudah cukup
untuk memenuhi unsur "mengakses" itu.

Yang membedakan Anda dari terdakwa bukan perkakasnya, bukan niat baiknya, dan
bukan seberapa dalam Anda masuk. Yang membedakan cuma satu: izin tertulis dari
pemilik sistem, dengan cakupan yang jelas. Itulah kenapa langkah 7 di lab ini
sama wajibnya dengan langkah nmap.

Lab ini juga sudah dipagari secara teknis, bukan cuma lewat imbauan. Jaringan
lab dibuat internal, jadi dari dalam toolbox memang tidak ada jalan keluar sama
sekali. Anda akan membuktikannya sendiri di langkah 6.

## Cara menyalakan

```
./lab up 00a          # macOS dan Linux
.\lab.cmd up 00a      # Windows
```

Ganti `./lab` dengan `.\lab.cmd` untuk semua perintah `lab` di halaman ini
kalau Anda memakai Windows.

Yang mestinya terlihat di baris terakhir:

```
  OK   Lab 00a nyala.
       buka di browser  : http://localhost:8000
       terminal penyerang: ./lab sh 00a
```

Kalau yang muncul justru pesan bahwa image toolbox belum ada, jalankan
`./lab build` dulu. Itu bukan kerusakan, itu penjagaan supaya build 10 menit
tidak terjadi di tengah jam kelas.

## Peta lab

| Container | Perannya | Alamat dari dalam toolbox | Dari browser laptop |
|---|---|---|---|
| toolbox | tempat Anda mengetik | - | tidak ada |
| web | target latihan, punya halaman | `web` port 80 | http://localhost:8000 |
| arsip | target latihan, sengaja tersembunyi | `arsip` port 80 | tidak bisa, memang disengaja |

Dari dalam toolbox, panggil target memakai NAMANYA, bukan localhost.
`curl http://web/` jalan, `curl http://localhost:8000/` tidak jalan. Alasannya:
setiap container punya localhost sendiri, dan port 8000 itu milik laptop Anda,
bukan milik toolbox. Salah paham soal ini adalah penyebab macet nomor satu di
lab-lab berikutnya, jadi lebih baik kena sekarang.

## Langkah wajib

### 1. Halaman target terbuka di browser

Buka http://localhost:8000 di browser laptop Anda.

Yang dicari: halaman berjudul `LAB CEH SIAP` dengan tabel empat baris di
bawahnya.

Halaman itu terbuka berarti empat hal terbukti sekaligus: engine Docker hidup,
image multiarch jalan di arsitektur laptop Anda, publish port tembus ke host,
dan port itu terikat ke 127.0.0.1.

<details><summary>Kalau halamannya tidak terbuka, buka ini</summary>

Tunggu 20 detik lalu muat ulang. Container kadang butuh sedetik dua detik.

Masih gagal, jalankan `./lab reset 00a`.

Kalau yang muncul halaman aplikasi lain yang sama sekali tidak ada hubungannya,
berarti ada proses di laptop Anda yang sudah memakai port 8000 lebih dulu. Baca
`docs/04-kalau-macet.md` gejala nomor 1, kasusnya persis itu.
</details>

### 2. Masuk ke terminal penyerang dan kenali tempat kerjanya

```
./lab sh 00a
```

Prompt Anda berubah menjadi `root@penyerang:/lab#`. Mulai titik ini, semua
perintah diketik di dalam container, bukan di terminal laptop.

```
id
hostname
arch
ls -la /lab
ls -la /wordlists
```

Yang mestinya terlihat di tiga perintah pertama:

```
uid=0(root) gid=0(root) groups=0(root)
penyerang
aarch64
```

`arch` menjawab `aarch64` di Apple Silicon dan `x86_64` di laptop Intel atau
AMD. Dua-duanya benar, dan toolbox jalan native di keduanya.

Tiga folder yang perlu Anda hafal:

| Folder | Isinya | Nasibnya setelah `./lab down` |
|---|---|---|
| `/lab` | folder lab ini di laptop Anda, tersambung dua arah | tetap ada |
| `/wordlists` | wordlist bersama, read-only | tetap ada |
| `/root` | home di dalam container | ikut terhapus |

Simpan hasil kerja Anda di `/lab`, jangan di `/root`. Yang di `/root` hilang
begitu lab dimatikan, dan itu memang disengaja supaya lab selalu bisa diulang
dari nol.

### 3. Satu perintah nmap ke target di dalam lab

```
nmap -sS -sV -p 80 web arsip
```

Yang mestinya terlihat, kurang lebih persis seperti ini:

```
Nmap scan report for web (192.168.148.4)
Host is up (0.00014s latency).

PORT   STATE SERVICE VERSION
80/tcp open  http    Apache httpd 2.4.68 ((Unix))

Nmap scan report for arsip (192.168.148.3)
Host is up (0.000015s latency).

PORT   STATE SERVICE VERSION
80/tcp open  http    Apache httpd 2.4.68 ((Unix))

Nmap done: 2 IP addresses (2 hosts up) scanned in 6.72 seconds
```

Alamat IP dan angka detiknya di laptop Anda kemungkinan besar berbeda, dan itu
normal. Yang harus sama: dua host up, port 80 open di dua-duanya, dan nama
versi layanannya terbaca.

Baca opsinya satu per satu, karena tiga-tiganya keluar di exam:

- `-sS` SYN scan, disebut juga half-open scan atau stealth scan. Handshake TCP
  tidak pernah diselesaikan.
- `-sV` service and version detection. Ini yang mengubah tebakan `http` menjadi
  fakta `Apache httpd 2.4.68`.
- `-p 80` batasi ke satu port. Tanpa ini nmap memindai 1000 port paling umum.

<details><summary>Kalau nmap menjawab 0 hosts up, buka ini</summary>

Container target belum siap. Tunggu 20 detik lalu ulangi.

Kalau nmap menjawab `Couldn't open a raw socket. Error: (1) Operation not
permitted`, berarti lab dijalankan tanpa hak raw socket. Keluar dari toolbox
lalu jalankan `./lab reset 00a`, jangan diakali dengan menghapus `-sS`.
</details>

### 4. Target yang tidak punya alamat di browser

Container `arsip` sengaja tidak mem-publish port. Dari browser laptop, dia
tidak ada. Dari dalam jaringan lab, dia terbuka lebar. Buktikan:

```
curl http://arsip/
```

Yang mestinya terlihat:

```
<h1>Index of /</h1>
<ul><li><a href="catatan-perawatan.txt"> catatan-perawatan.txt</a></li>
<li><a href="kode-verifikasi.txt"> kode-verifikasi.txt</a></li>
</ul>
```

Halaman itu bukan halaman yang sengaja dibuat siapa pun. Itu daftar isi folder
yang dibocorkan sendiri oleh web server, karena tidak ada `index.html` dan
indexing-nya tidak dimatikan. Namanya directory listing, atau directory
indexing, dan di exam dia muncul sebagai misconfiguration.

Ambil isinya:

```
curl http://arsip/kode-verifikasi.txt
curl http://arsip/catatan-perawatan.txt
```

Catat kode verifikasinya. Itu jawaban pertanyaan nomor 2 di bawah.

### 5. Simpan bukti ke folder yang tidak ikut terhapus

Masih dari dalam toolbox:

```
nmap -sS -p 80 web arsip > /lab/bukti-00a.txt
curl -s http://arsip/kode-verifikasi.txt | sed -n 4p >> /lab/bukti-00a.txt
wc -l /lab/bukti-00a.txt
```

Sekarang buka terminal kedua di laptop Anda, masuk ke folder repo, lalu lihat
berkas yang sama dari luar container:

```
cat labs/00a-smoke-test/bukti-00a.txt
```

Yang mestinya terlihat di dua baris terakhir:

```
Nmap done: 2 IP addresses (2 hosts up) scanned in 0.56 seconds
SMOKE-OK-8000
```

Angka detiknya boleh beda. Yang penting baris `SMOKE-OK-8000` ada di paling
bawah, karena baris itu tadi diambil dari container `arsip`, bukan diketik
tangan.

Berkas yang ditulis di dalam container muncul di laptop tanpa disalin. Itu
gunanya `/lab`, dan itu cara Anda menyimpan hasil sepanjang minggu ini.

### 6. Buktikan pagarnya benar-benar ada

Masih dari dalam toolbox, jalankan tiga perintah ini:

```
ping -c 2 -W 2 8.8.8.8
ping -c 2 -W 2 192.168.1.1
nmap -sn 192.168.1.0/24 2>&1 | tail -3
```

Yang dicari: ketiganya GAGAL. Jawaban yang benar terlihat seperti ini:

```
ping: connect: Network is unreachable
ping: connect: Network is unreachable
setup_target: failed to determine route to 192.168.1.255
WARNING: No targets were specified, so 0 hosts scanned.
Nmap done: 0 IP addresses (0 hosts up) scanned in 0.00 seconds
```

Perhatikan bentuk `2>&1` di perintah ketiga, itu bukan hiasan. Nmap mencetak
256 baris `failed to determine route` ke stderr, satu untuk tiap alamat, dan
stderr TIDAK ikut lewat pipa biasa. Jadi `nmap ... | tail -3` saja tetap
membanjiri layar Anda. `2>&1` menggabungkan stderr ke stdout dulu, baru
`tail -3` bisa memotongnya. Kebiasaan ini kepakai terus selama minggu ini,
karena banyak perkakas menaruh temuan pentingnya di stderr.

Kegagalan itu bukan kerusakan, itu hasil yang diinginkan. Lihat sendiri
alasannya:

```
ip route
```

Keluarannya cuma satu baris, rute ke subnet lab sendiri. Tidak ada default
route sama sekali, jadi paket ke alamat mana pun di luar subnet lab mati di
tabel rute, bahkan sebelum menyentuh firewall.

Ini penting untuk Anda pahami, bukan sekadar untuk diikuti. Sepanjang minggu
ini Anda akan mengetik perintah yang, kalau salah arah, jatuh ke Pasal 332 tadi.
Pagar teknis membuat kesalahan arah menjadi tidak mungkin, bukan cuma tidak
disarankan.

### 7. Rules of Engagement

Ini bagian yang tidak ada perintahnya, dan justru bagian yang paling sering
menentukan seseorang dibayar atau dituntut.

Rules of Engagement adalah dokumen yang menyebut, secara tertulis dan disetujui
kedua pihak, minimal enam hal:

| Isi | Pertanyaan yang dijawab |
|---|---|
| Scope | Alamat IP, domain, dan aplikasi mana persisnya yang boleh disentuh |
| Out of scope | Apa yang jelas dilarang, misalnya sistem produksi atau data nasabah |
| Jendela waktu | Tanggal dan jam berapa saja pengujian boleh berjalan |
| Teknik terlarang | Biasanya DoS, social engineering, dan physical access |
| Kontak darurat | Siapa yang ditelepon kalau ada yang tumbang jam 2 pagi |
| Penanganan data | Bukti disimpan di mana, dienkripsi apa tidak, dihapus kapan |

Sekarang latihannya. Untuk tiap baris, tentukan BOLEH atau TIDAK BOLEH, lalu
sebutkan alasannya dalam satu kalimat. Kerjakan dulu, kunci jawabannya ada di
bawah.

| No | Situasi |
|---|---|
| 1 | Scope menyebut `10.0.5.0/24`. Anda menemukan server menarik di `10.0.6.10` dan ingin memindainya sebentar saja |
| 2 | Klien bilang lewat pesan singkat, "silakan mulai duluan, kontraknya menyusul minggu depan" |
| 3 | Scope menyebut `app.klien.co.id`. Domain itu ternyata menunjuk ke alamat IP milik penyedia cloud pihak ketiga |
| 4 | Jendela waktu 22:00 sampai 05:00. Jam 06:30 Anda baru sadar ada satu host yang belum sempat dipindai |
| 5 | Anda menemukan kredensial admin yang valid. RoE tidak menyebut apa pun soal login |
| 6 | Teman sekelas memasang lab di laptopnya. Anda ingin mencoba memindainya, sekadar iseng |
| 7 | Anda menemukan celah kritis di sistem yang jelas out of scope, dan celah itu berbahaya sekali |
| 8 | Pengujian selesai. Anda menyimpan salinan dump database di laptop pribadi sebagai portofolio |

<details><summary>Kunci jawaban, buka setelah Anda mengisi sendiri</summary>

1. TIDAK BOLEH. Scope itu daftar, bukan saran. Satu alamat di luar daftar sudah
   memenuhi unsur ayat pertama Pasal 332 KUHP, sekalipun Anda tidak menemukan
   apa pun.
2. TIDAK BOLEH. Izin lisan atau lewat chat tidak melindungi Anda. Yang
   melindungi cuma dokumen tertulis yang ditandatangani orang yang berwenang
   memberikannya.
3. TIDAK BOLEH sebelum ada izin dari pemilik infrastruktur itu juga. Klien Anda
   tidak bisa memberikan izin atas sistem yang bukan miliknya.
4. TIDAK BOLEH. Jendela waktu ada alasannya, biasanya beban produksi. Minta
   perpanjangan tertulis, lalu lanjutkan.
5. TERGANTUNG, dan default-nya TIDAK BOLEH. Kalau RoE tidak menyebut
   eksploitasi atau login, tanyakan dulu. Menemukan kredensial itu temuan,
   memakainya itu perbuatan baru.
6. TIDAK BOLEH. Laptop teman sekelas bukan milik Anda dan bukan bagian dari
   scope. Ini justru contoh yang paling sering muncul di kelas, dan pagar
   jaringan di lab ini dipasang persis untuk mencegahnya.
7. TIDAK BOLEH diuji, TAPI WAJIB dilaporkan. Tulis di laporan sebagai temuan di
   luar scope beserta cara Anda menemukannya, lalu berhenti di situ.
8. TIDAK BOLEH. Penanganan data diatur di RoE, dan biasanya menyebut penghapusan
   setelah laporan diterima. Data klien tidak pernah jadi portofolio.
</details>

Satu kalimat yang layak dihafal untuk exam sekaligus untuk kerja: yang membuat
sebuah tindakan menjadi ethical hacking bukan perkakasnya dan bukan niatnya,
melainkan izin tertulis dengan cakupan yang jelas.

## Pertanyaan

Jawabannya cuma ketemu kalau Anda benar-benar mengerjakan langkah di atas.

1. Berapa versi persis Apache yang dilaporkan `-sV` di container `web`?
2. Apa kode verifikasi yang tersimpan di container `arsip`?
3. Berapa alamat IP toolbox Anda, dan berapa prefix subnetnya? Perintahnya
   `ip -4 addr show eth0`.
4. Berapa jumlah host yang dilaporkan `nmap -sn 192.168.1.0/24`, dan apa
   kalimat error persisnya?
5. Kenapa `curl http://web/` berhasil dari dalam toolbox, sementara
   `curl http://localhost:8000/` dari tempat yang sama justru gagal?
6. Container `arsip` tidak bisa dibuka dari browser laptop Anda. Baris apa yang
   ada di `compose.yaml` milik `web` tetapi tidak ada di `arsip`?
7. Dari tabel Pasal 332 KUHP di atas, baris mana yang paling pas menggambarkan
   port scan tanpa izin yang tidak menembus sistem pengamanan apa pun?

## Tantangan tambahan

Untuk yang sudah selesai lebih dulu. Semuanya dikerjakan di lab yang sama,
tidak perlu menyalakan apa pun yang baru.

### T1. Lihat sendiri bedanya SYN scan dan TCP connect scan

Ini bukan teori. Jalankan dua perintah ini di dalam toolbox, satu per satu, dan
hitung paketnya.

```
tcpdump -n -i eth0 -c 3 "host web and tcp port 80" & sleep 1; nmap -sS -p 80 web >/dev/null; wait
tcpdump -n -i eth0 -c 4 "host web and tcp port 80" & sleep 1; nmap -sT -p 80 web >/dev/null; wait
```

SYN scan, tiga paket, handshake tidak pernah selesai:

```
Flags [S],  seq 3436940687
Flags [S.], seq 486817321, ack 3436940688
Flags [R],  seq 3436940688, win 0
```

TCP connect scan, empat paket, handshake selesai penuh dulu baru diputus:

```
Flags [S]
Flags [S.]
Flags [.], ack 1          <- paket ini tidak ada di SYN scan
Flags [R.], seq 1, ack 1
```

Paket ketiga itulah alasan `-sT` jauh lebih mudah tercatat di log aplikasi
target: koneksinya benar-benar terbentuk, jadi aplikasi di atasnya ikut tahu.
`-sS` berhenti sebelum itu, jadi yang melihatnya cuma perangkat yang memantau
lapisan jaringan.

### T2. Full port scan

```
nmap -p- web
```

Berapa lama selesainya, dan berapa port yang dilaporkan closed? Bandingkan
dengan angka di kepala Anda soal berapa lama scan 65535 port biasanya makan
waktu. Kenapa di sini secepat itu? Petunjuk: lihat angka latensi ke target.

### T3. Banner grab manual, tanpa nmap

```
printf "HEAD / HTTP/1.0\r\n\r\n" | ncat web 80
```

Perhatikan baris `Server:` di jawabannya. Anda baru saja mendapatkan informasi
yang sama dengan `-sV`, tanpa perkakas scanning sama sekali. Ini yang di exam
disebut banner grabbing, dan ini juga alasan kenapa menyembunyikan banner
adalah mitigasi yang sering disarankan.

### T4. Tulis RoE Anda sendiri

Satu halaman, untuk lab minggu ini, memakai enam baris tabel di langkah 7
sebagai kerangka. Scope-nya: container di dalam compose tiap lab. Out of scope:
semua alamat lain, termasuk laptop peserta lain dan jaringan ruangan.

Latihan ini terlihat sepele sampai Anda menyadari bahwa dokumen inilah yang
Anda tanda tangani di pekerjaan pertama Anda nanti.

## Yang tidak bisa dikerjakan di lab ini, dan kenapa

| Tidak bisa | Kenapa | Bedanya di dunia nyata |
|---|---|---|
| Host discovery ke jaringan nyata | Jaringan lab internal, nol default route | Justru langkah pertama internal pentest, dan yang membuatnya sah cuma RoE tertulis |
| OSINT, unduh exploit, update template scanner | Nol akses internet dari dalam lab | Recon nyata hampir selalu dimulai dari internet, jauh sebelum satu paket pun dikirim ke target |
| Menyadap trafik peserta lain | Tiap lab punya jaringan sendiri, dan tidak ada trafik peserta lain yang lewat situ | Butuh posisi di jalur trafik, misalnya port mirroring di switch atau ARP spoofing di segmen yang sama |
| Serangan lapisan kernel dan rootkit | Container berbagi kernel dengan laptop Anda, jadi eksperimen kernel akan menjatuhkan laptopnya sendiri | Dikerjakan di virtual machine atau perangkat terpisah, bukan di container |
| Wireless, dari WEP sampai Evil Twin | Radio Wi-Fi laptop tidak bisa diteruskan ke dalam container | Butuh adapter Wi-Fi yang mendukung monitor mode dan packet injection |
| Cracking dengan GPU | hashcat tidak punya driver OpenCL di image ini, sudah diuji dan hasilnya nol device | Cracking serius memakai GPU. Minggu ini kita pakai john dengan CPU, konsepnya sama, kecepatannya beda jauh |

Yang tidak bisa didemokan tetap keluar di exam. Untuk enam baris di atas, materi
kelasnya berupa teori dan demo instruktur, bukan lab tangan sendiri. Jangan
sampai Anda melewatkannya hanya karena tidak ada perintah yang perlu diketik.

## Nyambung ke exam

- SYN scan ditulis `nmap -sS`, dan di soal namanya bisa muncul sebagai
  half-open scan atau stealth scan. Tiga paket, handshake tidak diselesaikan.
- TCP connect scan ditulis `nmap -sT`, empat paket, handshake selesai, jauh
  lebih mudah tercatat di log aplikasi target.
- Service version detection ditulis `nmap -sV`. Hasilnya nama produk dan versi,
  bukan sekadar tebakan berdasarkan nomor port.
- Banner grabbing bisa dilakukan tanpa scanner, cukup dengan netcat atau ncat
  ditambah satu permintaan protokol.
- Directory listing, disebut juga directory indexing, yang menyala adalah
  misconfiguration, bukan kerentanan aplikasi, dan mitigasinya mematikan
  indexing di konfigurasi web server.
- Rules of Engagement dan izin tertulis adalah yang memisahkan penetration
  testing dari akses ilegal. Ingat urutannya: scope, out of scope, jendela
  waktu, teknik terlarang, kontak darurat, penanganan data.
- Untuk konteks Indonesia, hafalkan Pasal 332 KUHP baru untuk akses ilegal, dan
  Pasal 33 UU ITE yang masih berlaku untuk gangguan sistem. Exam EC-Council
  tidak menanyakan hukum Indonesia, tetapi klien Anda pasti menanyakannya.

## Ceklis, diisi sendiri

- [ ] Halaman http://localhost:8000 terbuka dan isinya LAB CEH SIAP
- [ ] `nmap -sS -sV -p 80 web arsip` menunjukkan dua host up dan versi Apache
- [ ] Saya menemukan kode verifikasi di container `arsip`
- [ ] Berkas `bukti-00a.txt` yang saya tulis di dalam container terlihat dari laptop
- [ ] Ping ke luar gagal, dan saya bisa menjelaskan kenapa itu justru benar
- [ ] Saya mengisi delapan baris latihan Rules of Engagement sebelum membuka kuncinya
- [ ] Saya bisa menyebutkan apa yang membedakan ethical hacking dari akses ilegal

## Membereskan

Keluar dari toolbox dulu:

```
exit
```

Lalu matikan labnya:

```
./lab down 00a
```

Yang mestinya terlihat: `OK   Lab 00a dimatiin.`

Perintah itu menghapus container beserta volume lab, termasuk isi `/root`.
Berkas `bukti-00a.txt` yang Anda tulis di `/lab` tetap ada di
`labs/00a-smoke-test/`, karena folder itu ada di laptop Anda, bukan di dalam
container. Hapus sendiri kalau sudah tidak diperlukan.

Untuk memastikan tidak ada sisa yang menyala:

```
docker ps
```

Kalau ternyata masih ada lab lain yang menyala dari sesi sebelumnya, matikan
semuanya sekaligus dengan `./lab nuke`.
