# Pasang Docker di macOS

Perkiraan waktu 15 sampai 25 menit, sebagian besarnya menunggu unduhan. Kerjakan di rumah,
jangan di kelas.

Di macOS tidak ada urusan BIOS dan tidak ada WSL. Yang harus benar cuma satu: **memilih
unduhan yang cocok dengan chip laptop Anda**. Salah pilih, aplikasinya tidak mau jalan.

## Langkah 1. Cek chip laptop Anda

Ada dua cara, pilih salah satu.

### Cara grafis

Klik logo Apple di pojok kiri atas, pilih About This Mac.

| Yang tertulis di jendela itu | Berarti |
|---|---|
| `Chip: Apple M1`, `Apple M2`, `Apple M3`, `Apple M4`, dan seterusnya | Apple Silicon |
| `Processor: Intel Core ...` | Intel |

### Cara terminal

Buka Terminal, lalu jalankan:

```
uname -m
```

| Keluarannya | Berarti |
|---|---|
| `arm64` | Apple Silicon |
| `x86_64` | Intel |

Catat hasilnya. Anda butuh itu di langkah berikutnya.

---

## Langkah 2. Unduh Docker Desktop yang benar

Buka <https://www.docker.com/products/docker-desktop/>. Di halaman unduhan ada dua pilihan
untuk Mac:

| Chip Anda | Pilih unduhan |
|---|---|
| Apple Silicon | Mac with Apple chip |
| Intel | Mac with Intel chip |

Berkasnya sekitar 500 MB sampai 1 GB.

## Langkah 3. Pasang

1. Buka berkas `.dmg` hasil unduhan.
2. Seret ikon Docker ke folder Applications.
3. Buka Docker dari Launchpad atau folder Applications.
4. macOS akan bertanya apakah Anda yakin membuka aplikasi yang diunduh dari internet.
   Pilih Open.
5. Docker Desktop meminta kata sandi admin Mac Anda untuk memasang komponen sistemnya.
   Ini normal, masukkan kata sandi Anda.
6. Muncul kotak persetujuan **Docker Subscription Service Agreement**. Baca sekilas, lalu
   klik Accept. Docker Desktop gratis untuk pemakaian pribadi dan pendidikan.
7. Kalau diminta membuat akun atau mengisi survei, Anda boleh melewatinya. Akun Docker
   tidak wajib untuk kelas ini.
8. Tunggu sampai ikon paus di menu bar berhenti bergerak dan jendela Docker Desktop
   menunjukkan status berjalan. Penyalaan pertama bisa memakan waktu 1 sampai 3 menit.

---

## Langkah 4. Khusus Apple Silicon, pasang Rosetta

Lewati langkah ini kalau Mac Anda Intel.

Sebagian lab memakai image yang hanya tersedia untuk prosesor Intel. Di Mac Apple Silicon,
image itu tetap bisa dijalankan lewat penerjemahan, tapi butuh Rosetta terpasang.

Di Terminal, jalankan:

```
softwareupdate --install-rosetta --agree-to-license
```

Setelah itu buka Docker Desktop, masuk ke Settings, lalu General, dan cari opsi
**Use Rosetta for x86_64/amd64 emulation**. Pastikan opsi itu menyala. Kalau tidak ketemu
di General, cek juga bagian Features in development, karena letaknya pernah berpindah
antar versi Docker Desktop.

Kalau opsi ini tidak ada sama sekali di versi Docker Desktop Anda, jangan panik. Sebagian
besar lab tetap jalan tanpanya. Pemeriksa kesiapan di langkah berikutnya akan memberi tahu
kalau memang ada yang tidak beres, dan hasil itu yang dikirim ke instruktur.

### Kalau Mac Anda Intel

Tidak ada langkah tambahan. Semua image lab jalan langsung tanpa penerjemahan, bahkan
lebih cepat daripada di Apple Silicon untuk image yang hanya punya versi Intel.

---

## Langkah 5. Atur jatah RAM dan disk

Buka Docker Desktop, Settings, lalu Resources.

| Setelan | Minimal |
|---|---|
| Memory | 6 GB |
| Disk usage limit | sisakan setidaknya 25 GB |

Klik Apply and restart kalau Anda mengubah sesuatu.

---

## Langkah 6. Uji hasilnya

Buka Terminal, masuk ke folder repo lab, lalu jalankan:

```
docker version
docker compose version
```

Dua-duanya harus menampilkan nomor versi, bukan pesan error.

Setelah itu jalankan pemeriksa kesiapan bawaan repo ini:

```
./lab doctor
```

Yang Anda kejar adalah baris terakhir `SEMUA HIJAU`.

Kalau muncul `permission denied` saat menjalankan `./lab`, berarti berkas launcher-nya
belum bisa dieksekusi. Ini terjadi kalau Anda mengunduh repo sebagai ZIP, bukan lewat git.
Perbaiki sekali saja:

```
chmod +x lab
```

Kalau ada yang merah atau kuning, catat pesannya lalu buka
[04-kalau-macet.md](04-kalau-macet.md).

---

## Catatan: kalau Anda sudah memakai OrbStack

Launcher lab ini juga jalan di atas OrbStack, jadi Anda tidak perlu memasang Docker
Desktop kalau OrbStack sudah terpasang dan berjalan. Yang perlu Anda tahu: petunjuk di
kelas dan di panduan ini menyebut menu Docker Desktop, jadi Anda harus menerjemahkannya
sendiri ke antarmuka OrbStack. Kalau Anda tidak ingin repot, pakai Docker Desktop saja
seperti peserta lain.
