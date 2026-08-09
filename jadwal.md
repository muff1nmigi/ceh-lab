# Jadwal kelas CEH

Lima pertemuan. Tiap pertemuan dua sesi.

| Blok | Jam |
|---|---|
| Sesi 1 | 09:00 sampai 12:00 |
| Istirahat | 12:00 sampai 13:00 |
| Sesi 2 | 13:00 sampai 17:00 |

Tanggal, jam, dan lokasi ditentukan lembaga penyelenggara, jadi yang halaman ini
tetapkan cuma **urutannya**. Kalau jam di kelas Anda berbeda, urutan materi dan
labnya tetap sama.

Ujian CEH resmi EC-Council menggantikan sesi 2 di pertemuan terakhir.

Kolom Lab di bawah mencantumkan lab yang dipakai di sesi itu. Semuanya sudah diuji jalan.
Lab lain ditambahkan menjelang dan selama rangkaian kelas. Yang selalu benar adalah
keluaran perintah berikut, bukan halaman ini:

```
./lab list
```

---

## Sebelum pertemuan pertama, kerjakan di rumah

Ini bukan saran, ini syarat. Peserta yang mengerjakannya di kelas akan tertinggal satu jam
pertama, dan menghabiskan jatah kuota unduhan untuk seluruh kelas.

Semua langkah dikerjakan **di dalam Kali VM Anda**, bukan di laptop langsung.

1. Siapkan Kali VM lalu pasang Docker di dalamnya. Panduannya ada di folder `docs/`.
2. Jalankan `./lab doctor` sampai baris terakhirnya `SEMUA HIJAU`.
3. Jalankan `./lab build` untuk membangun terminal penyerang. Sekali saja, sekitar
   **4 menit** dan **1,2 GB** disk. **Ini yang paling sering terlewat, dan tanpa ini
   tidak ada satu pun lab yang bisa dinyalakan.**
4. Jalankan `./lab pull core` supaya image target sudah ada sebelum berangkat.

Kalau ada baris kuning yang tidak hilang, kirim hasil `./lab doctor --report` ke instruktur
paling lambat malam sebelum pertemuan pertama. Masih ada waktu memperbaikinya besok pagi,
asal instruktur tahu.

---

## Pertemuan 1

| Sesi | Materi | Lab |
|---|---|---|
| 1 | Introduction to Cyber Security, plus bootstrap lab | `00a` |
| 2 | Network Scanning and Enumeration | `01` |

Sesi 1 dipakai untuk memastikan seluruh kelas berdiri di titik yang sama: Docker jalan,
launcher jalan, lab uji `00a` menampilkan halamannya. Peserta yang sudah mengerjakan
persiapan di rumah akan selesai dalam lima menit dan bisa langsung masuk ke materi.

Sesi 2 masuk ke pemindaian dan enumerasi. Di sinilah aturan pagar mulai berlaku keras:
container di VM Anda bisa menjangkau jaringan kelas, jadi pemindaian yang salah arah
bukan latihan lagi. Baca ulang bagian Aturan main di [README](README.md) sebelum sesi ini.

Yang perlu Anda siapkan: VM sudah lulus `./lab doctor`, dan catatan kosong untuk
menyalin keluaran perintah.

---

## Pertemuan 2

| Sesi | Materi | Lab |
|---|---|---|
| 1 | Hacking Web Server | `02` |
| 2 | System Hacking | `03` |

Sesi 1 masuk ke modul CEH 13. Fokusnya server web yang salah konfigurasi, kredensial
bawaan yang tidak diganti, dan panel administrasi yang terbuka ke jaringan.

Sesi 2 masuk ke pemecahan kata sandi dan peningkatan hak akses. Satu catatan yang perlu
Anda ingat untuk ujian: nama perkakas yang paling sering muncul di soal adalah **hashcat**
dan **John the Ripper**. Di praktik kelas ini yang dipakai adalah John the Ripper, karena
hashcat butuh akses ke perangkat komputasi GPU yang tidak tersedia di dalam container.
Hafalkan hashcat sebagai nama dan fungsinya untuk ujian, tapi latih tangan Anda dengan
John.

---

## Pertemuan 3

| Sesi | Materi | Lab |
|---|---|---|
| 1 | Social Engineering | `04` |
| 2 | Meretas Aplikasi Web | `05` |

Sesi 1 memakai lab `04`. Halaman phishing yang Anda bangun memakai merek fiktif dan
berjalan sepenuhnya di dalam lab. Tidak ada lab yang menyasar manusia sungguhan, dan itu
disengaja.

Sesi 2 memakai DVWA dan OWASP Juice Shop, dua aplikasi web yang sengaja dibuat rapuh dan
dipakai luas di industri. Nyalakan dengan `./lab up 05`, lalu ikuti README lab itu. Anda perlu
mendaftar akun sendiri lewat halaman Register di aplikasi itu.

Ini sesi terpanjang dan paling padat di rangkaian ini. Datang dengan baterai penuh dan lab
yang sudah ditarik.

---

## Pertemuan 4

| Sesi | Materi | Lab |
|---|---|---|
| 1 | Malware Analysis | `06` |
| 2 | Denial of Service | `07` |

Sesi 1 membahas analisis statis dan dinamis, indikator kompromi, serta cara kerja sandbox.
Semua contoh dijalankan di dalam container yang terisolasi. Jangan pernah membawa contoh
berbahaya keluar dari lab, dan jangan menjalankannya di sistem operasi VM Anda
langsung.

Sesi 2 membahas Denial of Service. Ini materi yang paling gampang disalahgunakan, jadi
pagarnya paling ketat: sasaran uji hanya container di dalam lab Anda sendiri. Mengarahkan
alat DoS ke jaringan kelas, ke jaringan kantor tempat kelas berlangsung, atau ke alamat
internet mana pun adalah tindakan yang bisa berujung pidana, bukan sekadar pelanggaran
aturan kelas.

---

## Pertemuan 5

| Sesi | Materi | Lab |
|---|---|---|
| 1 | Cloud and IoT Hacking, lalu review menjelang ujian | `08` |
| 2 | **Ujian CEH resmi EC-Council** | - |

Sesi 1 dibagi dua. Paruh pertama untuk materi Cloud dan IoT. Paruh kedua untuk review:
istilah yang sering tertukar, perkakas beserta fungsinya, urutan fase serangan, dan
soal-soal yang paling sering menjebak.

### Ujian

Ujian CEH (kode 312-50) berformat pilihan ganda, umumnya 125 soal dengan alokasi waktu 4
jam. Konfirmasikan ulang format, jam mulai, dan aturan tekniknya ke panitia pada hari H,
karena ketentuan EC-Council dapat berubah dan tiap penyelenggara punya pengaturan sendiri.

Yang perlu Anda siapkan sendiri:

1. Kartu identitas sesuai ketentuan panitia.
2. Datang sebelum jam mulai, jangan tepat waktu. Proses verifikasi peserta memakan
   waktu.
3. Tidur cukup malam sebelumnya. Empat jam ujian pilihan ganda lebih menguji ketahanan
   konsentrasi daripada hafalan.

### Sebelum pulang

Matikan semua lab yang masih menyala:

```
./lab nuke
```

Kalau Anda menambahkan pengecualian antivirus untuk folder lab selama kelas, hapus
pengecualian itu sekarang. Caranya ada di
[docs/03-kalau-macet.md](docs/03-kalau-macet.md) bagian 7.
