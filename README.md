# Lab CEH

Lab praktik Certified Ethical Hacker yang jalan penuh di dalam Kali VM Anda sendiri. Nol server, nol VPS, nol tunnel. Satu perintah untuk menyalakan, satu perintah untuk mematikan.

Repo ini materi ajar yang dikembangkan sendiri oleh **Evan Hendra**, dipakai untuk kelas CEH. Isinya lab tambahan yang menemani kelas, bukan slide resmi kelasnya.

Repo ini publik dan boleh dipakai ulang oleh pengajar lain. Lihat bagian Lisensi.

---

## Empat langkah

Kerjakan berurutan, **semuanya di dalam Kali VM Anda**, bukan di laptop langsung. Empat langkah ini cukup untuk membuat VM Anda siap dipakai di kelas. Perkiraan waktu 30 sampai 45 menit, sebagian besarnya menunggu unduhan.

### Langkah 1. Siapkan VM dan pasang Docker di dalamnya

Jangan lompat, tiap panduan sudah dipangkas sependek mungkin.

| Panduan | Isinya |
|---|---|
| Menyiapkan Kali VM | [docs/01-siapkan-kali-vm.md](docs/01-siapkan-kali-vm.md) |
| Memasang Docker di dalam Kali | [docs/02-pasang-docker-di-kali.md](docs/02-pasang-docker-di-kali.md) |
| Kalau ada yang macet | [docs/03-kalau-macet.md](docs/03-kalau-macet.md) |

### Langkah 2. Ambil repo ini, lalu cek kesiapan VM

Ambil repo dengan git supaya akhiran baris skripnya benar:

```
git clone https://github.com/muff1nmigi/ceh-lab.git
cd ceh-lab
```

Kalau Anda mengunduh ZIP dari tombol Code di GitHub, buka folder hasil ekstraknya lalu jalankan `chmod +x lab` satu kali.

Sekarang jalankan pemeriksa kesiapan:

```
./lab doctor
```

Perintah ini memeriksa Docker, arsitektur, RAM, sisa disk, dan koneksi ke registry. Yang Anda kejar adalah baris terakhir `SEMUA HIJAU`. Kalau ada baris merah, betulkan dulu sesuai sarannya.

Kalau ada baris kuning yang tidak hilang, kirim laporannya ke instruktur:

```
./lab doctor --report
```

Perintah itu menulis satu berkas di folder repo. Kirim berkas itu, bukan tangkapan layar.

### Langkah 3. Bangun terminal penyerang, sekali saja

Terminal penyerang tidak ditarik dari internet, tetapi dibangun di dalam VM Anda sendiri. Ini yang membuat lab tetap jalan walau jaringan kelas sedang padat.

```
./lab build
```

Jalankan ini **di rumah, bukan di kelas**. Terukur di Kali VM: sekitar **4 menit** dan **1,2 GB** ruang disk.

Selama prosesnya Anda akan melihat banyak baris pemasangan paket. Itu wajar. Yang Anda tunggu satu baris di akhir:

```
OK   Toolbox siap. Tag: ceh-toolbox:1.0
```

### Langkah 4. Nyalakan lab uji

```
./lab up 00a
```

Buka <http://localhost:8000> di browser **di dalam Kali**. Kalau halamannya menampilkan tulisan `LAB CEH SIAP`, VM Anda beres. Matikan lagi:

```
./lab down 00a
```

Kalau langkah ini berhenti dengan pesan `toomanyrequests`, itu batas penarikan Docker Hub dan obatnya ada di [docs/03-kalau-macet.md](docs/03-kalau-macet.md).

---

## Sebelum hari Senin, kerjakan di rumah

Di kelas, semua VM keluar lewat satu alamat IP publik yang sama. Docker Hub membatasi penarikan image ke 100 per jam per alamat IP untuk pengguna yang tidak login. Sepuluh laptop yang menarik image barengan menghabiskan jatah itu dalam hitungan menit, dan kelas berhenti.

Jadi tarik image di rumah, dengan internet Anda sendiri:

```
./lab pull core
```

Setelah itu image sudah ada di dalam VM Anda dan lab bisa dinyalakan tanpa menarik apa pun.

---

## Perintah yang sering dipakai

Semua dijalankan di Terminal, di dalam Kali VM.

| Perintah | Gunanya |
|---|---|
| `./lab doctor` | Cek VM siap atau belum. Jalankan ini duluan |
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

Container lab **sudah dikurung** dan tidak bisa keluar, dan itu diuji bukan diasumsikan. Tapi **Kali VM Anda sendiri tidak dikurung**: perintah yang Anda ketik di Terminal Kali, di luar toolbox lab, bisa menjangkau jaringan kelas dan laptop peserta lain. Itu bukan latihan lagi.

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
| `00a` | Pertemuan 1 sesi 1 | Smoke test dan orientasi |
| `01` | Pertemuan 1 sesi 2 | Network scanning dan enumeration |
| `02` | Pertemuan 2 sesi 1 | Hacking web server |
| `03` | Pertemuan 2 sesi 2 | System hacking dan Active Directory |
| `04` | Pertemuan 3 sesi 1 | Social engineering |
| `05` | Pertemuan 3 sesi 2 | Meretas aplikasi web |
| `06` | Pertemuan 4 sesi 1 | Malware analysis, statik saja |
| `07` | Pertemuan 4 sesi 2 | Denial of service, terkurung di dalam lab |
| `08` | Pertemuan 5 sesi 1 | Cloud dan IoT |

Lihat daftarnya kapan saja dengan `./lab list`, dan rincian satu lab dengan
`./lab info 03`.

Jadwal lima harinya ada di [jadwal.md](jadwal.md).

---

## Yang dibutuhkan Kali VM Anda

| Hal | Minimal | Enaknya |
|---|---|---|
| RAM untuk VM | 6 GB | 8 GB |
| CPU | 2 vCPU | 4 vCPU |
| Sisa disk DI DALAM VM | 30 GB | 40 GB |
| Arsitektur | Intel atau AMD | - |

Jangan memberikan lebih dari setengah RAM laptop ke VM. Cara menaikkannya ada di [docs/01-siapkan-kali-vm.md](docs/01-siapkan-kali-vm.md).

---

## Lisensi

Repo ini memakai lisensi MIT. Teks lengkapnya di [LICENSE](LICENSE).

Alasan memilih MIT, bukan lisensi dokumen: isi repo ini sebagian besar berupa skrip
launcher dan berkas compose, jadi lisensi perangkat lunak yang cocok. MIT juga paling
pendek dan paling dikenal, sehingga pengajar lain yang ingin memakai ulang lab ini tidak
perlu meminta izin, cukup mencantumkan atribusinya.

Yang tidak tercakup lisensi ini: image pihak ketiga yang ditarik oleh lab ini, misalnya
OWASP Juice Shop, tetap memakai lisensi masing-masing pemiliknya.
