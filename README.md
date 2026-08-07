# Lab CEH

Lab praktik Certified Ethical Hacker yang jalan penuh di laptop Anda sendiri. Nol server, nol VPS, nol tunnel. Satu perintah untuk menyalakan, satu perintah untuk mematikan.

Repo ini materi ajar yang dikembangkan sendiri oleh **Evan Hendra**, dipakai untuk kelas CEH. Isinya lab tambahan yang menemani kelas, bukan slide resmi kelasnya. Slide dan judul materi milik Course-Net dan tidak ada di repo ini.

Repo ini publik dan boleh dipakai ulang oleh pengajar lain. Lihat bagian Lisensi.

---

## Tiga langkah

Kerjakan berurutan. Kalau Anda buka halaman untuk persiapan kelas, tiga langkah ini cukup untuk membuat laptop Anda siap dipakai di kelas pada pagi hari. Perkiraan waktu 30 sampai 45 menit, sebagian besarnya menunggu unduhan.

### Langkah 1. Pasang Docker

Pilih panduan sesuai sistem operasi Anda. Jangan lompat, tiap panduan sudah dipangkas sependek mungkin.

| Sistem operasi | Panduan |
|---|---|
| Windows 10 atau 11 | [docs/01-pasang-docker-windows.md](docs/01-pasang-docker-windows.md) |
| macOS, Apple Silicon maupun Intel | [docs/02-pasang-docker-macos.md](docs/02-pasang-docker-macos.md) |
| Linux | [docs/03-pasang-docker-linux.md](docs/03-pasang-docker-linux.md) |

### Langkah 2. Ambil repo ini, lalu cek kesiapan laptop

Ambil repo dengan git supaya akhiran baris skripnya benar:

```
git clone https://github.com/muff1nmigi/ceh-lab.git
cd ceh-lab
```

Kalau Anda mengunduh ZIP dari tombol Code di GitHub, buka folder hasil ekstraknya, lalu di macOS atau Linux jalankan `chmod +x lab` satu kali.

Sekarang jalankan pemeriksa kesiapan:

```
./lab doctor          # macOS dan Linux
.\lab.cmd doctor      # Windows
```

Perintah ini memeriksa Docker, arsitektur laptop, RAM, sisa disk, kemampuan menjalankan container Intel, dan koneksi ke registry. Yang Anda kejar adalah baris terakhir `SEMUA HIJAU`. Kalau ada baris merah, betulkan dulu sesuai sarannya.

Kalau ada baris kuning yang tidak hilang, kirim laporannya ke instruktur:

```
./lab doctor --report          # macOS dan Linux
.\lab.cmd doctor --report      # Windows
```

Perintah itu menulis berkas `laporan-siap-<nama-laptop>.txt` di folder repo. Kirim berkas itu, bukan tangkapan layar.

### Langkah 3. Bangun terminal penyerang, sekali saja

Terminal penyerang tidak ditarik dari internet, tetapi dibangun di laptop Anda sendiri. Ini yang membuat lab tetap jalan walau jaringan kelas sedang padat.

```
./lab build           # macOS dan Linux
.\lab.cmd build       # Windows
```

Jalankan ini **di rumah, bukan di kelas**. Terukur di laptop Apple Silicon: sekitar **225 detik** dan **1,16 GB** ruang disk. Di laptop Intel atau AMD kira-kira sama.

Selama prosesnya Anda akan melihat banyak baris pemasangan paket. Itu wajar. Yang Anda tunggu satu baris di akhir:

```
OK   Toolbox siap. Tag: ceh-toolbox:1.0
```

### Langkah 4. Nyalakan lab uji

```
./lab up 00a          # macOS dan Linux
.\lab.cmd up 00a      # Windows
```

Buka <http://localhost:8000> di browser. Kalau halamannya menampilkan tulisan
`LAB CEH SIAP`, laptop Anda beres. Matikan lagi:

```
./lab down 00a
```

Kalau langkah ini berhenti dengan pesan `toomanyrequests`, itu batas penarikan Docker Hub dan obatnya ada di [docs/04-kalau-macet.md](docs/04-kalau-macet.md).

---

## Sebelum hari Senin, kerjakan di rumah

Di kelas, semua laptop keluar lewat satu alamat IP publik yang sama. Docker Hub membatasi penarikan image ke 100 per jam per alamat IP untuk pengguna yang tidak login. Sepuluh laptop yang menarik image barengan menghabiskan jatah itu dalam hitungan menit, dan kelas berhenti.

Jadi tarik image di rumah, dengan internet Anda sendiri:

```
./lab pull core          # macOS dan Linux
.\lab.cmd pull core      # Windows
```

Setelah itu image sudah ada di laptop Anda dan lab bisa dinyalakan tanpa menarik apa pun.

---

## Perintah yang sering dipakai

Di Windows, ganti `./lab` dengan `.\lab.cmd`. Sisa perintahnya sama persis.

| Perintah | Gunanya |
|---|---|
| `./lab doctor` | Cek laptop siap atau belum. Jalankan ini duluan |
| `./lab doctor --report` | Sama, tapi hasilnya ditulis ke berkas untuk dikirim ke instruktur |
| `./lab list` | Daftar semua lab, dikelompokkan per modul CEH |
| `./lab info 05` | Keterangan satu lab: URL, kredensial, durasi |
| `./lab up 05` | Nyalakan lab |
| `./lab sh 05` | Masuk ke terminal penyerang di dalam lab |
| `./lab logs 05` | Lihat log semua layanan lab |
| `./lab down 05` | Matikan lab, data labnya dibuang |
| `./lab reset 05` | Matikan lalu nyalakan lagi dari nol, kalau labnya kacau |
| `./lab pull core` | Tarik image duluan supaya hari-H tidak menunggu |
| `./lab nuke` | Matikan semua lab yang sedang menyala |
| `./lab offline load <folder>` | Muat image dari flashdisk, dipakai kalau internet mati |

Daftar lengkapnya keluar kalau Anda menjalankan `./lab` tanpa argumen.

---

## Aturan main, ini bukan basa-basi

Container lab di laptop Anda **bisa menjangkau jaringan kelas**. Itu sudah diuji, bukan dugaan. Artinya satu perintah pemindaian yang salah arah bukan latihan lagi, tapi pemindaian sungguhan terhadap jaringan kelas dan laptop peserta lain.

Tiga aturan, tidak ada pengecualian:

1. Sasaran Anda hanya container di dalam lab yang sedang Anda nyalakan. Panggil dengan nama layanannya, misalnya `juiceshop`, bukan dengan alamat IP hasil pemindaian.
2. Jangan pernah mengarahkan perintah apa pun ke `192.168.x.x`, ke gateway kelas, ke laptop teman, atau ke alamat internet mana pun.
3. Kalau Anda tidak yakin sebuah perintah menyasar ke mana, tanya instruktur sebelum menekan Enter, bukan sesudah.

Teknik di repo ini legal dipakai di lab ini dan ilegal dipakai di sistem yang bukan milik Anda dan tanpa izin tertulis. Bawa pulang tekniknya, bukan kebiasaannya.

---

## Isi repo

Repo ini lengkap. Sembilan lab sudah diuji jalan dari keadaan bersih pada 6 Agustus 2026.

| Lab | Sesi | Isi |
|---|---|---|
| `00a` | Senin sesi 1 | Smoke test dan orientasi |
| `01` | Senin sesi 2 | Network scanning dan enumeration |
| `02` | Selasa sesi 1 | Hacking web server |
| `03` | Selasa sesi 2 | System hacking dan Active Directory |
| `04` | Rabu sesi 1 | Social engineering |
| `05` | Rabu sesi 2 | Meretas aplikasi web |
| `06` | Kamis sesi 1 | Malware analysis, statik saja |
| `07` | Kamis sesi 2 | Denial of service, terkurung di dalam lab |
| `08` | Jumat sesi 1 | Cloud dan IoT |

Lihat daftarnya kapan saja dengan `./lab list`, dan rincian satu lab dengan
`./lab info 03`.

Jadwal lima harinya ada di [jadwal.md](jadwal.md).

---

## Yang dibutuhkan laptop Anda

| Hal | Minimal | Enaknya |
|---|---|---|
| RAM untuk Docker | 6 GB | 8 GB atau lebih |
| Sisa disk kosong | 25 GB | 40 GB |
| Hak admin di laptop | Wajib | - |
| Arsitektur | Intel, AMD, atau ARM, semuanya didukung | - |

Laptop kantor yang dikunci kebijakan perusahaan sering gagal memasang Docker Desktop. Kalau bisa memilih, pakai laptop pribadi.

---

## Lisensi

Repo ini memakai lisensi MIT. Teks lengkapnya di [LICENSE](LICENSE).

Alasan memilih MIT, bukan lisensi dokumen: isi repo ini sebagian besar berupa skrip
launcher dan berkas compose, jadi lisensi perangkat lunak yang cocok. MIT juga paling
pendek dan paling dikenal, sehingga pengajar lain yang ingin memakai ulang lab ini tidak
perlu meminta izin, cukup mencantumkan atribusinya.

Yang tidak tercakup lisensi ini: image pihak ketiga yang ditarik oleh lab ini, misalnya
OWASP Juice Shop, tetap memakai lisensi masing-masing pemiliknya.
